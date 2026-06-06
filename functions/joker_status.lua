local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local function status_state(card)
    local extra = ElementalEditions.ensure_extra(card)
    if not extra then
        return nil
    end
    return extra.elem_status
end

local function visual_state(card)
    local extra = ElementalEditions.ensure_extra(card)
    if not extra then
        return nil
    end
    return extra.elem_status_visual
end

local function clears_on_next_scored_hand(context)
    return ElementalEditions.is_scoring_action_context(context) and not context.blueprint
end

local function status_config(status_key)
    return (ElementalEditions.get_section("status") or {})[status_key] or {}
end

local function scale_result(result, factor)
    if type(result) ~= "table" or factor == 1 then
        return result
    end

    for _, field in ipairs(ElementalEditions.constants.scalable_result_fields) do
        if type(result[field]) == "number" then
            result[field] = result[field] * factor
        end
    end

    return result
end

local function capture_edition_snapshot(card)
    if not (card and card.edition) then
        return nil
    end

    local edition = card.edition
    local key = edition.key or edition.type
    if key and G and G.P_CENTERS and G.P_CENTERS[key] then
        return { kind = "center", value = key }
    end

    if edition.foil then
        return { kind = "raw", value = { foil = true } }
    end
    if edition.holo then
        return { kind = "raw", value = { holo = true } }
    end
    if edition.polychrome then
        return { kind = "raw", value = { polychrome = true } }
    end
    if edition.negative then
        return { kind = "raw", value = { negative = true } }
    end

    return { kind = "raw", value = ElementalEditions.copy_value(edition) }
end

local function restore_edition_snapshot(card, snapshot)
    if not (card and card.set_edition) then
        return false
    end

    local ok = false
    if not snapshot then
        ok = pcall(function()
            card:set_edition(nil, true, true)
        end)
    elseif snapshot.kind == "center" then
        ok = pcall(function()
            card:set_edition(snapshot.value, true, true)
        end)
    elseif snapshot.kind == "raw" then
        ok = pcall(function()
            card:set_edition(ElementalEditions.copy_value(snapshot.value), true, true)
        end)
    end

    return ok
end

local function apply_status_visual(card, status_key, context)
    local gameplay = ElementalEditions.get_section("gameplay")
    if gameplay.enable_status_edition_transforms == false or gameplay.enable_status_edition_visuals == false then
        ElementalEditions.debug.trace("status visual skipped", {
            reason = "visuals_disabled",
            card = card,
            status = status_key,
        }, "status", context)
        return false
    end

    local visual = visual_state(card)
    if type(visual) ~= "table" then
        local extra = ElementalEditions.ensure_extra(card)
        extra.elem_status_visual = {}
        visual = extra.elem_status_visual
    end

    local element_key = ElementalEditions.constants.status_to_element[status_key]
    local element = ElementalEditions.constants.elements[element_key]
    local edition_key = element and element.edition_key or nil

    visual.status_key = status_key
    visual.element_key = element_key
    visual.visual_only = gameplay.status_editions_visual_only ~= false
    visual.original_snapshot = visual.original_snapshot or capture_edition_snapshot(card)
    visual.applied_center_key = edition_key and ElementalEditions.get_edition_center_key(edition_key) or nil
    visual.applied_live = false

    if not (card and card.set_edition and visual.applied_center_key) then
        ElementalEditions.debug.trace("status visual skipped", {
            reason = "no_supported_edition",
            card = card,
            status = status_key,
            center_key = visual.applied_center_key,
        }, "status", context)
        return false
    end

    if visual.status_key == status_key and visual.applied_live then
        ElementalEditions.debug.trace("status visual already active", {
            card = card,
            status = status_key,
            center_key = visual.applied_center_key,
        }, "status", context)
        return true
    end

    if gameplay.preserve_existing_joker_editions ~= false and gameplay.status_visuals_overwrite_existing_editions ~= true and card.edition then
        ElementalEditions.debug.trace("status visual skipped", {
            reason = "preserving_existing_edition",
            card = card,
            status = status_key,
            edition = card.edition and (card.edition.key or card.edition.type) or nil,
        }, "status", context)
        return false
    end

    local ok = pcall(function()
        card:set_edition(visual.applied_center_key, true, true)
    end)

    if ok then
        visual.applied_live = true
        ElementalEditions.debug.log("applied status visual", "status", {
            card = card,
            status = status_key,
            center_key = visual.applied_center_key,
        }, context)
    else
        ElementalEditions.debug.warn("failed to apply status visual", "status", {
            card = card,
            status = status_key,
            center_key = visual.applied_center_key,
        }, context)
    end

    return ok
end

local function clear_status_visual(card, context)
    local extra = ElementalEditions.ensure_extra(card)
    if not extra or type(extra.elem_status_visual) ~= "table" then
        return false
    end

    local visual = extra.elem_status_visual
    if visual.applied_live then
        local current_key = card and card.edition and (card.edition.key or card.edition.type) or nil
        if current_key == visual.applied_center_key or current_key == nil then
            ElementalEditions.debug.safe_call("restore_status_visual_snapshot", function()
                restore_edition_snapshot(card, visual.original_snapshot)
            end, false, context)
        else
            ElementalEditions.debug.trace("status visual restore skipped", {
                reason = "edition_changed_elsewhere",
                card = card,
                current_key = current_key,
                expected_key = visual.applied_center_key,
            }, "status", context)
        end
    end

    extra.elem_status_visual = nil
    ElementalEditions.debug.log("cleared status visual", "status", {
        card = card,
        previous = visual,
    }, context)
    return true
end

ElementalEditions.apply_status_visual = apply_status_visual
ElementalEditions.clear_status_visual = clear_status_visual

function ElementalEditions.get_joker_status(card)
    local state = status_state(card)
    if type(state) ~= "table" or not ElementalEditions.constants.status_keys[state.key] then
        return nil
    end
    return state
end

function ElementalEditions.apply_joker_status(card, status_key, duration, source)
    if not ElementalEditions.get_section("gameplay").enable_joker_statuses then
        return false
    end
    if not ElementalEditions.is_pokermon_joker(card) or ElementalEditions.is_pokemon_knocked_out(card) then
        return false
    end
    if not ElementalEditions.constants.status_keys[status_key] then
        return false
    end

    local status_context = type(source) == "table" and source.context or nil
    local extra = ElementalEditions.ensure_extra(card)
    local current = extra.elem_status
    local turns = duration or status_config(status_key).duration or 1

    if type(current) == "table" and current.key ~= status_key then
        ElementalEditions.clear_joker_status(card, "any", "replaced", status_context)
    end

    current = extra.elem_status
    if type(current) == "table" and current.key == status_key then
        current.turns = turns
        current.source = source
    else
        extra.elem_status = {
            key = status_key,
            turns = turns,
            source = source,
        }
    end

    ElementalEditions.debug.log("applying joker status", "status", {
        card = card,
        status = status_key,
        turns = turns,
        source = source,
    }, status_context)

    apply_status_visual(card, status_key, status_context)
    if ElementalEditions.on_status_applied then
        ElementalEditions.debug.safe_call("on_status_applied", function()
            ElementalEditions.on_status_applied(card, status_key, source)
        end, nil, status_context)
    end
    ElementalEditions.show_status_text(card, ElementalEditions.get_status_name(status_key), G.C.ORANGE, {
        delay = ElementalEditions.get_message_delay and ElementalEditions.get_message_delay("status") or nil,
        context = status_context,
    })
    return true
end

function ElementalEditions.clear_joker_status(card, status_key_or_any, reason, context)
    local extra = ElementalEditions.ensure_extra(card)
    if not extra or type(extra.elem_status) ~= "table" then
        return false
    end

    if status_key_or_any and status_key_or_any ~= "any" and extra.elem_status.key ~= status_key_or_any then
        return false
    end

    local previous = ElementalEditions.copy_value(extra.elem_status)
    extra.elem_status = nil
    clear_status_visual(card, context)

    if ElementalEditions.on_status_cleared then
        ElementalEditions.debug.safe_call("on_status_cleared", function()
            ElementalEditions.on_status_cleared(card, previous.key, reason, previous)
        end, nil, context)
    end

    if reason == "cleansed" then
        ElementalEditions.show_status(card, "elem_cleansed", G.C.GREEN, "Cleansed", {
            delay = ElementalEditions.get_message_delay and ElementalEditions.get_message_delay("status") or nil,
            context = context,
        })
    elseif reason == "expired" then
        ElementalEditions.show_status(card, "elem_recovered", G.C.GREEN, "Recovered", {
            delay = ElementalEditions.get_message_delay and ElementalEditions.get_message_delay("status") or nil,
            context = context,
        })
    elseif reason == "woke" then
        ElementalEditions.show_status(card, "elem_woke_up", G.C.GREEN, "Woke Up", {
            delay = ElementalEditions.get_message_delay and ElementalEditions.get_message_delay("status") or nil,
            context = context,
        })
    end

    ElementalEditions.debug.log("cleared joker status", "status", {
        card = card,
        previous = previous,
        reason = reason,
    }, context)
    return true
end

function ElementalEditions.status_prevents_trigger(card, context)
    if not clears_on_next_scored_hand(context) or not ElementalEditions.is_pokermon_joker(card) then
        return false
    end

    local status = ElementalEditions.get_joker_status(card)
    if not status then
        return false
    end

    if ElementalEditions.override_allows_status_action and ElementalEditions.override_allows_status_action(card, status.key, context) then
        return false
    end

    local runtime = ElementalEditions.get_runtime(card)
    local hand_stamp = ElementalEditions.get_hand_stamp(context)
    runtime.status_hand = runtime.status_hand or {}

    if status.key == "asleep" then
        if runtime.status_hand.asleep ~= hand_stamp then
            runtime.status_hand.asleep = hand_stamp
            ElementalEditions.show_status_text(card, ElementalEditions.get_status_name("asleep"), G.C.BLUE, {
                delay = ElementalEditions.get_message_delay and ElementalEditions.get_message_delay("status") or nil,
                context = context,
            })
        end
        return true
    end

    if status.key == "paralyzed" then
        if runtime.status_hand.paralyzed ~= hand_stamp then
            runtime.status_hand.paralyzed = hand_stamp
            runtime.paralyze_skip = ElementalEditions.roll(
                "elem_paralyze_" .. hand_stamp .. "_" .. tostring(card.sort_id or card.ability.name),
                status_config("paralyzed").skip_chance or 0.25
            )
            if runtime.paralyze_skip then
                ElementalEditions.show_status_text(card, ElementalEditions.get_status_name("paralyzed"), G.C.YELLOW, {
                    delay = ElementalEditions.get_message_delay and ElementalEditions.get_message_delay("status") or nil,
                    context = context,
                })
            end
        end
        return runtime.paralyze_skip == true
    end

    return false
end

function ElementalEditions.modify_pokemon_ability_by_status(card, context, result)
    if not (clears_on_next_scored_hand(context) and ElementalEditions.is_pokermon_joker(card)) then
        return result
    end

    if ElementalEditions.apply_pending_bonuses then
        result = ElementalEditions.apply_pending_bonuses(card, context, result)
    end

    local status = ElementalEditions.get_joker_status(card)
    if not status or type(result) ~= "table" then
        return result
    end

    local factor = 1
    if status.key == "burned" then
        factor = status_config("burned").contribution_mult or 0.75
    elseif status.key == "confused" then
        factor = status_config("confused").contribution_mult or 0.75
    elseif status.key == "dazed" then
        factor = status_config("dazed").contribution_mult or 0.5
    end

    if factor ~= 1 then
        local runtime = ElementalEditions.get_runtime(card)
        local hand_stamp = ElementalEditions.get_hand_stamp(context)
        runtime.status_hand = runtime.status_hand or {}
        if runtime.status_hand[status.key] ~= hand_stamp then
            runtime.status_hand[status.key] = hand_stamp
            ElementalEditions.show_status_text(card, ElementalEditions.get_status_name(status.key), G.C.ORANGE, {
                delay = ElementalEditions.get_message_delay and ElementalEditions.get_message_delay("status") or nil,
                context = context,
            })
        end
        return scale_result(result, factor)
    end

    return result
end

function ElementalEditions.modify_elemental_damage_by_status(card, damage, context)
    return damage
end

function ElementalEditions.tick_joker_statuses(context)
    if not (context and context.after and not context.blueprint) then
        return
    end

    local burned = status_config("burned")
    local asleep = status_config("asleep")

    for _, card in ipairs(ElementalEditions.get_pokemon_jokers(true)) do
        local status = ElementalEditions.get_joker_status(card)
        if status then
            if status.key == "burned" and not ElementalEditions.is_pokemon_knocked_out(card) then
                ElementalEditions.damage_pokemon(card, burned.dot_damage or 2, "fire", {
                    source_kind = "status_dot",
                    context = context,
                })
            elseif status.key == "asleep" and not ElementalEditions.is_pokemon_knocked_out(card) then
                ElementalEditions.heal_pokemon(card, asleep.end_hand_heal or 4, context)
            end

            status.turns = (status.turns or 1) - 1
            if status.turns <= 0 then
                ElementalEditions.clear_joker_status(card, "any", "expired", context)
            end
        end
    end
end

function ElementalEditions.refresh_status_visuals(context)
    for _, card in ipairs(ElementalEditions.get_pokemon_jokers(true)) do
        local status = ElementalEditions.get_joker_status(card)
        local visual = visual_state(card)

        if status then
            if not visual or visual.status_key ~= status.key or visual.applied_live ~= true then
                ElementalEditions.debug.safe_call("refresh_status_visual", function()
                    apply_status_visual(card, status.key, context)
                end, nil, context)
            end
        elseif visual then
            ElementalEditions.debug.safe_call("clear_stale_status_visual", function()
                clear_status_visual(card, context)
            end, nil, context)
        end
    end
end

function ElementalEditions.install_joker_wrapper()
    if ElementalEditions._joker_wrapper_installed then
        return
    end

    local original_calculate_joker = Card.calculate_joker
    ElementalEditions._joker_wrapper_installed = true
    ElementalEditions._original_calculate_joker = original_calculate_joker

    function Card:calculate_joker(context)
        return ElementalEditions.debug.safe_call("Card:calculate_joker wrapper", function()
            if ElementalEditions.available and ElementalEditions.is_pokermon_joker(self) and ElementalEditions.status_prevents_trigger(self, context) then
                ElementalEditions.debug.trace("status prevented joker trigger", {
                    card = self,
                }, "status", context)
                return nil
            end

            local result = original_calculate_joker(self, context)

            if ElementalEditions.available and ElementalEditions.is_pokermon_joker(self) then
                return ElementalEditions.modify_pokemon_ability_by_status(self, context, result)
            end

            return result
        end, nil, context)
    end
end

return ElementalEditions
