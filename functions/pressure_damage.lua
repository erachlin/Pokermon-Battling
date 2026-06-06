local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local function damage_config()
    return ElementalEditions.get_section("damage")
end

local function status_config()
    return ElementalEditions.get_section("status")
end

local function scored_summary(context)
    return ElementalEditions.get_scored_element_channels(context)
end

local function safe_types(target)
    local ok, types = pcall(ElementalEditions.get_pokemon_types, target)
    if ok and type(types) == "table" then
        return table.concat(types, "/")
    end
    return "unknown"
end

local function discard_summary(context)
    local summary = {
        counts = {
            fire = 0,
            water = 0,
            earth = 0,
            lightning = 0,
            grass = 0,
        },
        cards = {
            fire = {},
            water = {},
            earth = {},
            lightning = {},
            grass = {},
        },
        total = 0,
    }

    local cards = context and context.other_card and { context.other_card } or {}

    for _, card in ipairs(cards) do
        local element_key = ElementalEditions.get_card_element(card)
        if element_key then
            summary.counts[element_key] = (summary.counts[element_key] or 0) + 1
            summary.cards[element_key][#summary.cards[element_key] + 1] = card
            summary.total = summary.total + 1
        end
    end

    return summary
end

local function base_damage_for(source_kind)
    local config = damage_config()
    if source_kind == "discard" then
        return config.discard_damage_base or 3
    end
    if source_kind == "held" then
        return config.held_damage_base or 1
    end
    return config.scored_damage_base or 6
end

local function status_chance_for(summary, element_key, source_kind, multiplier)
    local config = status_config()
    local count = summary and summary.counts and summary.counts[element_key] or 1
    local chance = source_kind == "discard" and (config.chance_per_discarded_card or 0.10) or (config.chance_per_scored_card or 0.20)
    chance = chance + math.max(0, count - 1) * (config.bonus_per_extra_channel or 0.05)

    if multiplier <= 0 then
        chance = 0
    elseif multiplier > 1 then
        chance = chance + (config.super_effective_bonus or 0.10)
    elseif multiplier < 1 then
        chance = chance - (config.resisted_penalty or 0.05)
    end

    if ElementalEditions.get_boss_status_bonus then
        chance = chance + (ElementalEditions.get_boss_status_bonus(element_key) or 0)
    end

    return math.max(0, math.min(chance, config.max_chance or 0.60))
end

local function maybe_apply_status(target, element_key, context, summary, source_card, source_kind, multiplier)
    local definition = ElementalEditions.constants.elements[element_key]
    if not (definition and definition.status and ElementalEditions.apply_joker_status) then
        return false
    end

    local seed = table.concat({
        "elem_status",
        source_kind or "scored",
        element_key,
        ElementalEditions.get_hand_stamp(context),
        tostring(source_card and source_card.sort_id or 0),
        tostring(target and target.sort_id or 0),
    }, ":")

    if ElementalEditions.roll(seed, status_chance_for(summary, element_key, source_kind, multiplier)) then
        return ElementalEditions.apply_joker_status(target, definition.status, nil, {
            element = element_key,
            source_card = source_card,
            source_kind = source_kind,
            context = context,
        })
    end

    return false
end

local function cleanse_status_by_element(element_key, context)
    if not ElementalEditions.clear_joker_status then
        return
    end

    local wanted = nil
    if element_key == "water" then
        wanted = { burned = true, confused = true }
    elseif element_key == "earth" then
        wanted = { paralyzed = true }
    elseif element_key == "fire" then
        wanted = { asleep = true }
    elseif element_key == "grass" then
        wanted = { dazed = true }
    end

    if not wanted then
        return
    end

    for _, card in ipairs(ElementalEditions.get_pokemon_jokers(true)) do
        local status = ElementalEditions.get_joker_status(card)
        if status and wanted[status.key] then
            ElementalEditions.clear_joker_status(card, status.key, status.key == "asleep" and "woke" or "cleansed", context)
            return
        end
    end
end

local function apply_singed_from_fire(source_card, context)
    if not ElementalEditions.apply_singed or not ElementalEditions.is_enabled("singed") then
        return false
    end

    if not ElementalEditions.roll(
        "elem_singed_" .. ElementalEditions.get_hand_stamp(context) .. "_" .. tostring(source_card.sort_id or 0),
        ElementalEditions.get_section("card_status").fire_singed_chance or 0.20
    ) then
        return false
    end

    local candidates = {}
    for _, card in ipairs(context.scoring_hand or {}) do
        if card ~= source_card and ElementalEditions.can_receive_singed(card) then
            candidates[#candidates + 1] = card
        end
    end

    local target = ElementalEditions.pick_random(candidates, "elem_singed_pick_" .. ElementalEditions.get_hand_stamp(context))
    return ElementalEditions.apply_singed(target, { element = "fire", source_card = source_card, context = context })
end

function ElementalEditions.get_eligible_pokemon_targets(context)
    local targets = {}
    local allow_knocked_out = damage_config().apply_to_knocked_out == true
    for _, joker in ipairs(ElementalEditions.get_pokemon_jokers(allow_knocked_out)) do
        if allow_knocked_out or not ElementalEditions.is_pokemon_knocked_out(joker) then
            targets[#targets + 1] = joker
        end
    end

    ElementalEditions.debug.trace("eligible pokemon targets", {
        count = #targets,
        stamp = ElementalEditions.get_hand_stamp(context),
    }, context and context.discard and "discard" or "scoring", context)

    return targets
end

function ElementalEditions.calculate_elemental_damage(target_card, element_key, source_kind, context)
    local base = base_damage_for(source_kind)
    if ElementalEditions.get_boss_damage_bonus then
        base = base + (ElementalEditions.get_boss_damage_bonus(element_key) or 0)
    end
    local multiplier = ElementalEditions.get_type_multiplier(element_key, target_card)
    local final = math.max(0, math.floor((base * multiplier) + 0.5))
    return {
        base = base,
        multiplier = multiplier,
        final = final,
    }
end

function ElementalEditions.apply_damage_to_pokemon(target_card, amount, source_element, context)
    return ElementalEditions.damage_pokemon(target_card, amount, source_element, context)
end

function ElementalEditions.apply_elemental_damage_to_targets(element_key, base_damage, targets, source_card, context, source_kind, summary, show_messages)
    local perf_token = ElementalEditions.perf and ElementalEditions.perf.start and ElementalEditions.perf.start("aoe:" .. tostring(element_key) .. ":" .. tostring(source_kind), context) or nil
    local totals = {
        element = element_key,
        base_damage = base_damage,
        source_kind = source_kind,
        target_count = type(targets) == "table" and #targets or 0,
        damage = 0,
        statuses = 0,
        knockouts = 0,
        super_effective = 0,
        resisted = 0,
        no_effect = 0,
        results = {},
    }

    if totals.target_count <= 0 then
        if perf_token and ElementalEditions.perf and ElementalEditions.perf.stop then
            ElementalEditions.perf.stop(perf_token, { targets = 0 }, context)
        end
        return totals
    end

    local suppress_damage_popup = not ElementalEditions.should_show_individual_damage(totals.target_count)

    if ElementalEditions.is_debug_enabled("damage") then
        ElementalEditions.debug.log("aoe damage start", source_kind == "discard" and "discard" or "scoring", {
            element = element_key,
            source_kind = source_kind,
            base = base_damage,
            targets = totals.target_count,
            source_card = source_card,
        }, context)
    end

    for _, target in ipairs(targets) do
        local before_hp = ElementalEditions.get_pokemon_hp(target)
        local damage_info = ElementalEditions.calculate_elemental_damage(target, element_key, source_kind, context)
        local hit_context = {
            context = context,
            source_card = source_card,
            source_kind = source_kind,
            hand_stamp = ElementalEditions.get_hand_stamp(context),
            attack_type = ElementalEditions.get_element_attack_type(element_key),
            base_damage = base_damage or damage_info.base,
            type_multiplier = damage_info.multiplier,
            suppress_damage_popup = suppress_damage_popup,
        }

        if damage_info.multiplier <= 0 then
            totals.no_effect = totals.no_effect + 1
        elseif damage_info.multiplier > 1 then
            totals.super_effective = totals.super_effective + 1
        elseif damage_info.multiplier < 1 then
            totals.resisted = totals.resisted + 1
        end

        local incoming = ElementalEditions.debug.safe_call("modify_incoming_elemental_damage", function()
            return ElementalEditions.modify_incoming_elemental_damage(target, damage_info.final, element_key, hit_context)
        end, {
            amount = damage_info.final,
            prevented = 0,
            heal = 0,
            reason = "safe_fallback",
        }, context)

        if incoming.prevented > 0 and ElementalEditions.on_elemental_damage_prevented then
            ElementalEditions.debug.safe_call("on_elemental_damage_prevented", function()
                ElementalEditions.on_elemental_damage_prevented(target, incoming.prevented, element_key, hit_context, incoming.reason)
            end, nil, context)
        end
        if incoming.heal > 0 then
            ElementalEditions.debug.safe_call("heal_from_incoming_redirect", function()
                ElementalEditions.heal_pokemon(target, incoming.heal, context)
            end, nil, context)
        end

        local applied = 0
        if incoming.amount > 0 then
            applied = ElementalEditions.debug.safe_call("apply_damage_to_pokemon", function()
                return ElementalEditions.apply_damage_to_pokemon(target, incoming.amount, element_key, hit_context)
            end, 0, context)
            if ElementalEditions.is_pokemon_knocked_out(target) then
                totals.knockouts = totals.knockouts + 1
            end
        end

        totals.damage = totals.damage + applied
        if ElementalEditions.debug.safe_call("maybe_apply_status", function()
            return maybe_apply_status(target, element_key, context, summary, source_card, source_kind, damage_info.multiplier)
        end, false, context) then
            totals.statuses = totals.statuses + 1
        end

        if source_kind == "discard" and ElementalEditions.on_elemental_card_discarded then
            ElementalEditions.debug.safe_call("on_elemental_card_discarded", function()
                ElementalEditions.on_elemental_card_discarded(target, element_key, source_card, context)
            end, nil, context)
        elseif ElementalEditions.on_elemental_card_scored then
            ElementalEditions.debug.safe_call("on_elemental_card_scored", function()
                ElementalEditions.on_elemental_card_scored(target, element_key, source_card, context)
            end, nil, context)
        end

        local after_hp = ElementalEditions.get_pokemon_hp(target)
        totals.results[#totals.results + 1] = {
            target = target,
            before_hp = before_hp,
            after_hp = after_hp,
            type_multiplier = damage_info.multiplier,
            applied = applied,
            prevented = incoming.prevented,
            healed = incoming.heal,
        }

        if ElementalEditions.is_debug_enabled("damage") then
            ElementalEditions.debug.log("aoe hit resolved", "damage", {
                element = element_key,
                target = target,
                types = safe_types(target),
                multiplier = damage_info.multiplier,
                incoming = incoming.amount,
                prevented = incoming.prevented,
                healed = incoming.heal,
                applied = applied,
                hp = tostring(before_hp) .. "->" .. tostring(after_hp),
            }, context)
        end
    end

    if show_messages ~= false then
        ElementalEditions.debug.safe_call("show_aoe_damage_summary", function()
            ElementalEditions.show_aoe_damage_summary(element_key, totals, source_card, targets, context, source_kind)
        end, nil, context)
        ElementalEditions.debug.safe_call("show_effectiveness_summary", function()
            ElementalEditions.show_effectiveness_summary(element_key, totals, source_card, targets, context)
        end, nil, context)
    end
    if perf_token and ElementalEditions.perf and ElementalEditions.perf.stop then
        ElementalEditions.perf.stop(perf_token, {
            targets = totals.target_count,
            damage = totals.damage,
            statuses = totals.statuses,
        }, context)
    end
    return totals
end

function ElementalEditions.apply_elemental_damage_from_scored_card(scoring_card, context, summary)
    local element_key = ElementalEditions.get_card_element(scoring_card)
    if not element_key then
        return nil
    end

    local targets = ElementalEditions.get_eligible_pokemon_targets(context)
    if #targets == 0 then
        return {
            element = element_key,
            target_count = 0,
            damage = 0,
            statuses = 0,
            knockouts = 0,
        }
    end

    return ElementalEditions.apply_elemental_damage_to_targets(
        element_key,
        base_damage_for("scored"),
        targets,
        scoring_card,
        context,
        "scored",
        summary,
        false
    )
end

function ElementalEditions.apply_elemental_damage_from_discarded_card(discarded_card, context, summary)
    local element_key = ElementalEditions.get_card_element(discarded_card)
    if not element_key then
        return nil
    end

    local targets = ElementalEditions.get_eligible_pokemon_targets(context)
    if #targets == 0 then
        return {
            element = element_key,
            target_count = 0,
            damage = 0,
            statuses = 0,
            knockouts = 0,
        }
    end

    return ElementalEditions.apply_elemental_damage_to_targets(
        element_key,
        base_damage_for("discard"),
        targets,
        discarded_card,
        context,
        "discard",
        summary,
        true
    )
end

function ElementalEditions.apply_elemental_damage_from_scored_cards(context)
    if not (context and context.after and type(context.scoring_hand) == "table") then
        return
    end

    local summary = scored_summary(context)
    if summary.total <= 0 then
        ElementalEditions.debug.trace("scored damage early exit", {
            reason = "no elemental scored cards",
            scoring_cards = #context.scoring_hand,
        }, "scoring", context)
        return
    end

    local totals = {
        damage = { fire = 0, water = 0, earth = 0, lightning = 0, grass = 0 },
        statuses = 0,
        knockouts = 0,
        targets = 0,
        per_element = {},
    }

    for _, source_card in ipairs(context.scoring_hand) do
        local result = ElementalEditions.debug.safe_call("apply_elemental_damage_from_scored_card", function()
            return ElementalEditions.apply_elemental_damage_from_scored_card(source_card, context, summary)
        end, nil, context)
        if result and result.element then
            totals.targets = math.max(totals.targets, result.target_count or 0)
            totals.damage[result.element] = (totals.damage[result.element] or 0) + (result.damage or 0)
            totals.statuses = totals.statuses + (result.statuses or 0)
            totals.knockouts = totals.knockouts + (result.knockouts or 0)
            totals.per_element[result.element] = totals.per_element[result.element] or {
                damage = 0,
                statuses = 0,
                knockouts = 0,
                target_count = 0,
                super_effective = 0,
                resisted = 0,
                no_effect = 0,
                source_card = source_card,
            }
            local entry = totals.per_element[result.element]
            entry.damage = entry.damage + (result.damage or 0)
            entry.statuses = entry.statuses + (result.statuses or 0)
            entry.knockouts = entry.knockouts + (result.knockouts or 0)
            entry.target_count = math.max(entry.target_count or 0, result.target_count or 0)
            entry.super_effective = (entry.super_effective or 0) + (result.super_effective or 0)
            entry.resisted = (entry.resisted or 0) + (result.resisted or 0)
            entry.no_effect = (entry.no_effect or 0) + (result.no_effect or 0)

            if result.element == "fire" then
                ElementalEditions.debug.safe_call("apply_singed_from_fire", function()
                    apply_singed_from_fire(source_card, context)
                end, nil, context)
            end
        end
    end

    for element_key, count in pairs(summary.counts) do
        if count > 0 then
            ElementalEditions.debug.safe_call("cleanse_status_by_element", function()
                cleanse_status_by_element(element_key, context)
            end, nil, context)
        end
    end

    for element_key, entry in pairs(totals.per_element) do
        ElementalEditions.debug.safe_call("show_aoe_damage_summary:aggregate", function()
            ElementalEditions.show_aoe_damage_summary(element_key, entry, entry.source_card, entry.target_count, context, "scored")
        end, nil, context)
        ElementalEditions.debug.safe_call("show_effectiveness_summary:aggregate", function()
            ElementalEditions.show_effectiveness_summary(element_key, entry, entry.source_card, { entry.source_card }, context)
        end, nil, context)
    end

    if ElementalEditions.is_debug_enabled("scoring") then
        ElementalEditions.debug.log("scored elemental summary", "scoring", totals, context)
    end
end

function ElementalEditions.apply_elemental_damage_from_discard_context(context)
    if not (context and context.discard and context.other_card and not context.blueprint) then
        return
    end

    local summary = discard_summary(context)
    local totals = ElementalEditions.apply_elemental_damage_from_discarded_card(context.other_card, context, summary)
    if not totals then
        ElementalEditions.debug.trace("discard damage early exit", {
            reason = "discarded card not elemental",
            other_card = context.other_card,
        }, "discard", context)
        return
    end

    if ElementalEditions.is_debug_enabled("discard") then
        ElementalEditions.debug.log("discard elemental summary", "discard", totals, context)
    end
end

function ElementalEditions.apply_elemental_pressure_from_held_cards(context)
    if not ElementalEditions.get_section("gameplay").enable_held_card_pressure then
        return
    end

    local summary = ElementalEditions.get_held_element_channels(context)
    if summary.total <= 0 then
        return
    end

    local targets = ElementalEditions.get_eligible_pokemon_targets(context)
    if #targets == 0 then
        return
    end

    for element_key, cards in pairs(summary.cards) do
        for _, source_card in ipairs(cards) do
            ElementalEditions.debug.safe_call("apply_elemental_damage_to_targets:held", function()
                ElementalEditions.apply_elemental_damage_to_targets(
                    element_key,
                    base_damage_for("held"),
                    targets,
                    source_card,
                    context,
                    "held",
                    summary,
                    true
                )
            end, nil, context)
        end
    end
end

return ElementalEditions
