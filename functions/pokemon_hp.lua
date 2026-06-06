local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local function hp_state(card)
    local extra = ElementalEditions.ensure_extra(card)
    if not extra then
        return nil
    end

    return ElementalEditions.ensure_table(extra, "elem_hp")
end

local function sync_debuff(card)
    if card and SMODS and SMODS.recalc_debuff and card.area == G.jokers then
        pcall(SMODS.recalc_debuff, card)
    end
end

function ElementalEditions.get_pokemon_hp_max(card)
    if not ElementalEditions.is_pokermon_joker(card) then
        return nil
    end

    local hp_config = ElementalEditions.get_section("hp")
    local center = card.config and card.config.center or nil
    local stage = center and center.stage or nil
    local rarity = center and center.rarity or nil
    local rarity_number = tonumber(rarity)

    if stage == "Legendary" or stage == "Mega" or rarity == "poke_mega" or rarity == "poke_safari" or (rarity_number and rarity_number >= 4) then
        return hp_config.legendary or 80
    end
    if stage == "Two" or (rarity_number and rarity_number >= 3) then
        return hp_config.rare or 60
    end
    if stage == "One" or (rarity_number and rarity_number >= 2) then
        return hp_config.evolved or 45
    end

    return hp_config.basic or 30
end

function ElementalEditions.init_pokemon_hp(card)
    if not ElementalEditions.get_section("gameplay").enable_pokemon_hp then
        return nil
    end
    if not ElementalEditions.is_pokermon_joker(card) then
        return nil
    end

    local state = hp_state(card)
    local max_hp = ElementalEditions.get_pokemon_hp_max(card)
    if not max_hp then
        return nil
    end

    if type(state.max) ~= "number" or type(state.current) ~= "number" then
        state.max = max_hp
        state.current = max_hp
        state.knocked_out = false
        state.initialized_from = card.config and card.config.center and card.config.center.key or "unknown"
        ElementalEditions.debug.log("initialized HP", "hp", {
            card = card,
            current = state.current,
            max = state.max,
        })
        return state
    end

    if state.max ~= max_hp and state.max and state.max > 0 then
        local ratio = math.max(0, math.min(1, state.current / state.max))
        state.max = max_hp
        state.current = math.max(1, math.floor((state.max * ratio) + 0.5))
    else
        state.max = max_hp
        state.current = math.max(0, math.min(state.current, state.max))
    end

    state.knocked_out = state.current <= 0
    return state
end

function ElementalEditions.get_pokemon_hp(card)
    local state = ElementalEditions.init_pokemon_hp(card)
    return state and state.current or nil
end

function ElementalEditions.set_pokemon_hp(card, value)
    local state = ElementalEditions.init_pokemon_hp(card)
    if not state then
        return nil
    end

    local was_knocked_out = state.knocked_out == true
    state.current = math.max(0, math.min(state.max or value or 0, math.floor((value or 0) + 0.5)))
    state.knocked_out = state.current <= 0

    if was_knocked_out ~= state.knocked_out then
        sync_debuff(card)
    end

    return state.current
end

function ElementalEditions.is_pokemon_knocked_out(card)
    local state = ElementalEditions.init_pokemon_hp(card)
    return state and state.knocked_out == true or false
end

function ElementalEditions.knock_out_pokemon(card, source_element, context)
    local state = ElementalEditions.init_pokemon_hp(card)
    if not state then
        return false
    end

    state.current = 0
    state.knocked_out = true
    sync_debuff(card)
    ElementalEditions.show_status(card, "elem_knocked_out", G.C.RED, "Knocked Out", {
        delay = ElementalEditions.get_message_delay and ElementalEditions.get_message_delay("status") or nil,
        context = context and context.context or context,
    })
    ElementalEditions.debug.warn("pokemon knocked out", "hp", {
        card = card,
        source_element = source_element,
    }, context and context.context or context)
    return true
end

function ElementalEditions.damage_pokemon(card, amount, source_element, context)
    local state = ElementalEditions.init_pokemon_hp(card)
    if not state or state.knocked_out then
        return 0
    end

    local final_amount = math.max(0, math.floor((ElementalEditions.modify_elemental_damage_by_status and ElementalEditions.modify_elemental_damage_by_status(card, amount, context)) or amount))
    if final_amount <= 0 then
        return 0
    end

    local before = state.current
    local remaining = ElementalEditions.set_pokemon_hp(card, state.current - final_amount)
    if not (context and context.suppress_damage_popup) then
        if ElementalEditions.show_damage_message then
            ElementalEditions.show_damage_message(card, final_amount, source_element, context, context and context.type_multiplier)
        else
            ElementalEditions.show_status_text(card, "-" .. tostring(final_amount) .. " HP", G.C.RED, {
                delay = ElementalEditions.get_message_delay and ElementalEditions.get_message_delay("damage") or nil,
                context = context and context.context or context,
            })
        end
    end
    ElementalEditions.debug.log("damage applied", "damage", {
        card = card,
        source_element = source_element,
        amount = final_amount,
        before = before,
        remaining = remaining,
        multiplier = context and context.type_multiplier or nil,
    }, context and context.context or context)

    if ElementalEditions.on_elemental_damage_taken then
        ElementalEditions.on_elemental_damage_taken(card, final_amount, source_element, context)
    end

    if remaining <= 0 then
        ElementalEditions.knock_out_pokemon(card, source_element, context)
    end

    return final_amount
end

function ElementalEditions.heal_pokemon(card, amount, context)
    local state = ElementalEditions.init_pokemon_hp(card)
    if not state or (amount or 0) <= 0 then
        return 0
    end

    local healed = math.max(0, math.min(state.max - state.current, math.floor((amount or 0) + 0.5)))
    if healed <= 0 then
        return 0
    end

    local before = state.current
    ElementalEditions.set_pokemon_hp(card, state.current + healed)
    ElementalEditions.show_status_text(card, "+" .. tostring(healed) .. " HP", G.C.GREEN, {
        delay = ElementalEditions.get_message_delay and ElementalEditions.get_message_delay("status") or nil,
        context = context,
    })
    ElementalEditions.debug.log("healed pokemon", "hp", {
        card = card,
        amount = healed,
        before = before,
        after = ElementalEditions.get_pokemon_hp(card),
    }, context)
    return healed
end

function ElementalEditions.revive_pokemon(card, amount_or_percent, context)
    local state = ElementalEditions.init_pokemon_hp(card)
    if not state then
        return false
    end

    local amount = amount_or_percent or 0
    if amount > 0 and amount <= 1 then
        amount = math.max(1, math.floor((state.max or 1) * amount + 0.5))
    end

    if amount <= 0 then
        amount = 1
    end

    local was_knocked_out = state.knocked_out == true
    ElementalEditions.set_pokemon_hp(card, amount)
    state.knocked_out = false
    sync_debuff(card)

    if was_knocked_out then
        ElementalEditions.show_status(card, "elem_revived", G.C.GREEN, "Revived", {
            delay = ElementalEditions.get_message_delay and ElementalEditions.get_message_delay("status") or nil,
            context = context,
        })
    end

    return true
end

function ElementalEditions.refresh_pokemon_team()
    for _, card in ipairs(ElementalEditions.get_pokemon_jokers(true)) do
        ElementalEditions.init_pokemon_hp(card)
    end
end

return ElementalEditions
