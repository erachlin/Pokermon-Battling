local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local override_package = assert(SMODS.load_file("balance/elemental_pokemon_overrides.lua"))()
local override_defs = override_package.overrides or {}

ElementalEditions.override_package = override_package
ElementalEditions.override_defs = override_defs
ElementalEditions.override_metadata = override_package.metadata or {}

local function override_config()
    return ElementalEditions.get_section("overrides")
end

local function is_override_logging_enabled()
    local config = override_config()
    return config.debug_logging == true or ElementalEditions.is_debug_enabled("overrides")
end

local function override_log(...)
    if not is_override_logging_enabled() then
        return
    end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    ElementalEditions.debug.log(table.concat(parts, " "), "overrides")
end

local function counter_state(card)
    local extra = ElementalEditions.ensure_extra(card)
    if not extra then
        return nil
    end
    return ElementalEditions.ensure_table(extra, "elem_counters")
end

local function pending_state(card)
    local extra = ElementalEditions.ensure_extra(card)
    if not extra then
        return nil
    end
    return ElementalEditions.ensure_table(extra, "elem_pending")
end

local function hand_guard(card, key, context)
    local runtime = ElementalEditions.get_runtime(card)
    if not runtime then
        return true
    end

    runtime.override_hand = runtime.override_hand or {}
    local stamp = ElementalEditions.get_hand_stamp(context)
    local token = tostring(key)

    if runtime.override_hand[token] == stamp then
        return false
    end

    runtime.override_hand[token] = stamp
    return true
end

local function status_lookup(list)
    local found = {}
    for _, value in ipairs(list or {}) do
        found[value] = true
    end
    return found
end

function ElementalEditions.is_pokemon_override_enabled(definition)
    local gameplay = ElementalEditions.get_section("gameplay")
    local config = override_config()
    if gameplay.enable_pokemon_overrides == false or config.enabled == false then
        return false
    end

    local pokemon = config.pokemon or {}
    local toggle_key = definition and definition.enabled_key or nil
    if toggle_key and pokemon[toggle_key] == false then
        return false
    end

    return definition ~= nil
end

function ElementalEditions.get_pokemon_override(card_or_key)
    local center_key = type(card_or_key) == "string" and card_or_key or ElementalEditions.get_center_key(card_or_key)
    local definition = center_key and override_defs[center_key] or nil
    if definition and ElementalEditions.is_pokemon_override_enabled(definition) then
        return definition
    end
    return nil
end

function ElementalEditions.get_override_extra_types(card)
    local definition = ElementalEditions.get_pokemon_override(card)
    return definition and definition.extra_types or nil
end

function ElementalEditions.get_elemental_counter(card, counter_key)
    local counters = counter_state(card)
    if not counters then
        return 0
    end
    return tonumber(counters[counter_key]) or 0
end

function ElementalEditions.add_elemental_counter(card, counter_key, amount)
    if not ElementalEditions.constants.tracked_counters[counter_key] then
        return 0
    end

    local counters = counter_state(card)
    if not counters then
        return 0
    end

    local updated = math.max(0, (tonumber(counters[counter_key]) or 0) + (tonumber(amount) or 0))
    counters[counter_key] = updated
    return updated
end

function ElementalEditions.spend_elemental_counter(card, counter_key, amount)
    local current = ElementalEditions.get_elemental_counter(card, counter_key)
    local spend = math.max(0, math.min(current, tonumber(amount) or 0))
    if spend <= 0 then
        return 0
    end

    local counters = counter_state(card)
    counters[counter_key] = current - spend
    return spend
end

function ElementalEditions.queue_pending_bonus(card, field, amount)
    if type(amount) ~= "number" or amount == 0 then
        return 0
    end

    local pending = pending_state(card)
    if not pending then
        return 0
    end

    pending[field] = (tonumber(pending[field]) or 0) + amount
    return pending[field]
end

function ElementalEditions.apply_pending_bonuses(card, context, result)
    if not (context and context.joker_main and not context.blueprint) then
        return result
    end

    local pending = pending_state(card)
    if not pending then
        return result
    end

    local bonus = nil
    for _, field in ipairs(ElementalEditions.constants.scalable_result_fields) do
        if type(pending[field]) == "number" and pending[field] ~= 0 then
            bonus = bonus or {}
            bonus[field] = pending[field]
            pending[field] = 0
        end
    end

    return ElementalEditions.merge_calculate_results(result, bonus)
end

function ElementalEditions.once_per_hand(card, token, context)
    return hand_guard(card, token, context)
end

function ElementalEditions.get_scored_element_count(context, element_key)
    local summary = ElementalEditions.get_scored_element_channels(context)
    return summary and summary.counts and summary.counts[element_key] or 0
end

function ElementalEditions.get_held_element_count(context, element_key)
    local summary = ElementalEditions.get_held_element_channels(context)
    return summary and summary.counts and summary.counts[element_key] or 0
end

function ElementalEditions.get_lowest_hp_pokemon(include_knocked_out)
    local chosen = nil
    local chosen_hp = nil
    for _, card in ipairs(ElementalEditions.get_pokemon_jokers(include_knocked_out)) do
        local hp = ElementalEditions.get_pokemon_hp(card)
        if hp and (chosen_hp == nil or hp < chosen_hp) then
            chosen = card
            chosen_hp = hp
        end
    end
    return chosen
end

function ElementalEditions.find_first_pokemon_with_status(status_keys)
    local wanted = status_lookup(status_keys)
    for _, card in ipairs(ElementalEditions.get_pokemon_jokers(true)) do
        local status = ElementalEditions.get_joker_status(card)
        if status and wanted[status.key] then
            return card, status
        end
    end
    return nil, nil
end

function ElementalEditions.modify_incoming_elemental_damage(card, amount, element_key, hit_context)
    local info = {
        amount = math.max(0, math.floor((amount or 0) + 0.5)),
        prevented = 0,
        heal = 0,
        element_key = element_key,
        hit_context = hit_context,
        reason = nil,
    }

    local status = ElementalEditions.get_joker_status and ElementalEditions.get_joker_status(card) or nil
    local runtime = ElementalEditions.get_runtime(card)

    if status and status.key == "burned" and element_key == "fire" then
        local mult = (ElementalEditions.get_section("status").burned or {}).fire_resist_mult or 0.5
        local reduced = math.max(0, math.floor((info.amount * mult) + 0.5))
        info.prevented = info.prevented + math.max(0, info.amount - reduced)
        info.amount = reduced
        info.reason = "burned_fire_resist"
    end

    if status and status.key == "dazed" and runtime then
        runtime.dazed_guard = runtime.dazed_guard or {}
        if not runtime.dazed_guard.used then
            local mult = (ElementalEditions.get_section("status").dazed or {}).incoming_mult or 0.5
            local reduced = math.max(0, math.floor((info.amount * mult) + 0.5))
            info.prevented = info.prevented + math.max(0, info.amount - reduced)
            info.amount = reduced
            runtime.dazed_guard.used = true
            info.reason = "dazed_guard"
        end
    end

    if status and status.key == "confused" and info.amount > 0 then
        local confused = ElementalEditions.get_section("status").confused or {}
        local seed = table.concat({
            "elem_confused_redirect",
            tostring(card.sort_id or ElementalEditions.get_center_key(card) or "unknown"),
            tostring(hit_context and hit_context.source_kind or "hit"),
            tostring(hit_context and hit_context.hand_stamp or ""),
            tostring(element_key or "none"),
        }, ":")

        if ElementalEditions.roll(seed, confused.redirect_heal_chance or 0) then
            info.heal = info.heal + info.amount
            info.prevented = info.prevented + info.amount
            info.amount = 0
            info.reason = "confused_redirect"
        end
    end

    local definition = ElementalEditions.get_pokemon_override(card)
    if definition and definition.modify_incoming_damage then
        local updated = ElementalEditions.debug.safe_call("override:modify_incoming_damage", function()
            return definition.modify_incoming_damage(card, info, element_key, hit_context)
        end, info, hit_context and hit_context.context or nil)
        if type(updated) == "table" then
            info = updated
        end
    end

    info.amount = math.max(0, math.floor((info.amount or 0) + 0.5))
    info.prevented = math.max(0, math.floor((info.prevented or 0) + 0.5))
    info.heal = math.max(0, math.floor((info.heal or 0) + 0.5))
    return info
end

function ElementalEditions.prevent_elemental_damage(card, amount, element_key, hit_context, reason)
    local prevented = math.max(0, math.floor((amount or 0) + 0.5))
    if prevented > 0 then
        ElementalEditions.on_elemental_damage_prevented(card, prevented, element_key, hit_context, reason)
    end
    return 0
end

function ElementalEditions.on_elemental_damage_taken(card, amount, element_key, hit_context)
    if amount <= 0 then
        return
    end

    local status = ElementalEditions.get_joker_status and ElementalEditions.get_joker_status(card) or nil
    if status and status.key == "asleep" and element_key == "fire" then
        ElementalEditions.clear_joker_status(card, "asleep", "woke")
    end

    local definition = ElementalEditions.get_pokemon_override(card)
    if definition and definition.on_damage_taken then
        ElementalEditions.debug.safe_call("override:on_damage_taken", function()
            definition.on_damage_taken(card, amount, element_key, hit_context)
        end, nil, hit_context and hit_context.context or nil)
    end
end

function ElementalEditions.on_elemental_damage_prevented(card, amount, element_key, hit_context, reason)
    if amount <= 0 then
        return
    end

    local definition = ElementalEditions.get_pokemon_override(card)
    if definition and definition.on_damage_prevented then
        ElementalEditions.debug.safe_call("override:on_damage_prevented", function()
            definition.on_damage_prevented(card, amount, element_key, hit_context, reason)
        end, nil, hit_context and hit_context.context or nil)
    end
end

function ElementalEditions.on_elemental_card_scored(card, element_key, scoring_card, context)
    local status = ElementalEditions.get_joker_status and ElementalEditions.get_joker_status(card) or nil
    local status_config = ElementalEditions.get_section("status")

    if status and status.key == "burned" and element_key == "fire" then
        ElementalEditions.add_elemental_counter(card, "blaze", 1)
        ElementalEditions.queue_pending_bonus(card, "mult_mod", (status_config.burned or {}).blaze_mult_per_fire or 1)
    elseif status and status.key == "paralyzed" and element_key == "lightning" then
        ElementalEditions.add_elemental_counter(card, "static", (status_config.paralyzed or {}).static_per_lightning or 1)
    elseif status and status.key == "confused" and element_key == "water" then
        ElementalEditions.heal_pokemon(card, (status_config.confused or {}).water_heal or 2, context)
    end

    local definition = ElementalEditions.get_pokemon_override(card)
    if definition and definition.on_element_card_scored then
        ElementalEditions.debug.safe_call("override:on_element_card_scored", function()
            definition.on_element_card_scored(card, element_key, scoring_card, context)
        end, nil, context)
    end

    if definition and definition.on_matching_element_scored then
        local count = ElementalEditions.get_scored_element_count(context, element_key)
        local type_list = ElementalEditions.get_pokemon_types(card)
        for _, type_name in ipairs(type_list) do
            if ElementalEditions.element_matches_type(element_key, type_name) then
                ElementalEditions.debug.safe_call("override:on_matching_element_scored", function()
                    definition.on_matching_element_scored(card, element_key, count, context)
                end, nil, context)
                break
            end
        end
    end
end

function ElementalEditions.on_elemental_card_discarded(card, element_key, discarded_card, context)
    local definition = ElementalEditions.get_pokemon_override(card)
    if definition and definition.on_element_card_discarded then
        ElementalEditions.debug.safe_call("override:on_element_card_discarded", function()
            definition.on_element_card_discarded(card, element_key, discarded_card, context)
        end, nil, context)
    end
end

function ElementalEditions.on_status_applied(card, status_key, source)
    local runtime = ElementalEditions.get_runtime(card)
    if runtime then
        runtime.dazed_guard = nil
    end

    local definition = ElementalEditions.get_pokemon_override(card)
    if definition and definition.on_status_applied then
        ElementalEditions.debug.safe_call("override:on_status_applied", function()
            definition.on_status_applied(card, status_key, source)
        end, nil, source and source.context or nil)
    end
end

function ElementalEditions.on_status_cleared(card, status_key, reason, previous_state)
    if status_key == "paralyzed" then
        local per_counter = (ElementalEditions.get_section("status").paralyzed or {}).static_chip_per_counter or 5
        local stored = ElementalEditions.spend_elemental_counter(card, "static", ElementalEditions.get_elemental_counter(card, "static"))
        if stored > 0 then
            ElementalEditions.queue_pending_bonus(card, "chip_mod", stored * per_counter)
        end
    elseif status_key == "asleep" then
        ElementalEditions.add_elemental_counter(card, "growth", (ElementalEditions.get_section("status").asleep or {}).growth_on_wake or 1)
    end

    local runtime = ElementalEditions.get_runtime(card)
    if runtime then
        runtime.dazed_guard = nil
    end

    local definition = ElementalEditions.get_pokemon_override(card)
    if definition and definition.on_status_cleared then
        ElementalEditions.debug.safe_call("override:on_status_cleared", function()
            definition.on_status_cleared(card, status_key, reason, previous_state)
        end, nil, nil)
    end
end

function ElementalEditions.override_allows_status_action(card, status_key, context)
    local definition = ElementalEditions.get_pokemon_override(card)
    if definition and definition.allow_status_action then
        return definition.allow_status_action(card, status_key, context) == true
    end
    return false
end

function ElementalEditions.describe_pokemon_override(card)
    local definition = ElementalEditions.get_pokemon_override(card)
    return definition and definition.summary or nil
end

function ElementalEditions.get_pokemon_override_tooltip_lines(card)
    local definition = ElementalEditions.get_pokemon_override(card)
    if not definition then
        return nil
    end

    local lines = {}
    if definition.summary then
        lines[#lines + 1] = definition.summary
    end
    if type(definition.tooltip_lines) == "table" then
        for _, line in ipairs(definition.tooltip_lines) do
            if type(line) == "string" and line ~= "" then
                lines[#lines + 1] = line
            end
        end
    elseif type(definition.mechanics) == "table" and #definition.mechanics > 0 then
        lines[#lines + 1] = string.format(
            "%s: %s",
            ElementalEditions.safe_localize("elem_override_mechanics", "Mechanics"),
            table.concat(definition.mechanics, ", ")
        )
    end

    return #lines > 0 and lines or nil
end

function ElementalEditions.get_override_metadata()
    return ElementalEditions.override_metadata
end

function ElementalEditions.register_pokemon_overrides()
    if ElementalEditions._pokemon_overrides_registered or not (G and G.P_CENTERS) then
        return
    end

    local wrapped_any = false

    for center_key, definition in pairs(override_defs) do
        local center = G and G.P_CENTERS and G.P_CENTERS[center_key] or nil
        if center and not center._elemental_override_wrapped then
            wrapped_any = true
            center._elemental_override_wrapped = true
            center._elemental_original_calculate = center.calculate
            center._elemental_override_key = center_key
            center._elemental_override_summary = definition.summary
            center.elem_extra_types = definition.extra_types

            local original_calculate = center.calculate
            center.calculate = function(self, card, context)
                return ElementalEditions.debug.safe_call("override:center.calculate:" .. tostring(center_key), function()
                    local perf_token = ElementalEditions.perf and ElementalEditions.perf.start and ElementalEditions.perf.start("override:" .. tostring(center_key), context) or nil
                    local function finish(value)
                        if perf_token and ElementalEditions.perf and ElementalEditions.perf.stop then
                            ElementalEditions.perf.stop(perf_token, { center = center_key }, context)
                        end
                        return value
                    end

                    local result = nil
                    if original_calculate then
                        result = original_calculate(self, card, context)
                    end

                    if not (ElementalEditions.available and ElementalEditions.is_pokemon_override_enabled(definition) and card and not (context and context.blueprint)) then
                        return finish(result)
                    end

                    if definition.calculate_bonus then
                        local bonus = ElementalEditions.debug.safe_call("override:calculate_bonus:" .. tostring(center_key), function()
                            return definition.calculate_bonus(card, context, result)
                        end, nil, context)
                        result = ElementalEditions.merge_calculate_results(result, bonus)
                    end

                    return finish(result)
                end, nil, context)
            end

            override_log("Registered override for", center_key)
        end
    end

    ElementalEditions._pokemon_overrides_registered = wrapped_any
end

return ElementalEditions
