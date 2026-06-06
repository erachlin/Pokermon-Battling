local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local function creation_config()
    return ElementalEditions.get_section("card_creation")
end

local function state_for_creation()
    if not (G and G.GAME) then
        return nil
    end

    if type(G.GAME.elem_card_creation) ~= "table" then
        G.GAME.elem_card_creation = {}
    end
    return G.GAME.elem_card_creation
end

local function current_blind_stamp()
    local ante = G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or 0
    local blind = G and G.GAME and G.GAME.blind and G.GAME.blind.config and G.GAME.blind.config.blind and G.GAME.blind.config.blind.key or "none"
    return tostring(ante) .. ":" .. tostring(blind)
end

local function can_create(context, ignore_limits)
    local config = creation_config()
    if ElementalEditions.get_section("gameplay").enable_card_creation_effects == false or config.enabled == false then
        return false
    end

    if ignore_limits then
        return true
    end

    local state = state_for_creation()
    if not state then
        return false
    end

    local blind_stamp = current_blind_stamp()
    if state.blind_stamp ~= blind_stamp then
        state.blind_stamp = blind_stamp
        state.created_this_blind = 0
    end

    local hand_stamp = ElementalEditions.get_hand_stamp(context)
    if state.hand_stamp ~= hand_stamp then
        state.hand_stamp = hand_stamp
        state.created_this_hand = 0
    end

    if (state.created_this_hand or 0) >= (config.max_created_per_hand or 1) then
        return false
    end
    if (state.created_this_blind or 0) >= (config.max_created_per_blind or 3) then
        return false
    end

    return true
end

local function register_creation(context)
    local state = state_for_creation()
    if not state then
        return
    end

    state.created_this_hand = (state.created_this_hand or 0) + 1
    state.created_this_blind = (state.created_this_blind or 0) + 1
end

local function candidate_from_pool(pool, filter)
    local cards = {}
    for _, card in ipairs(pool or {}) do
        if card and (not filter or filter(card)) then
            cards[#cards + 1] = card
        end
    end
    return cards
end

local function default_transform_filter(element_key)
    return function(card)
        if not card then
            return false
        end

        if element_key == "grass" then
            return not ElementalEditions.has_flower_channel(card) and card.edition == nil
        end

        return not ElementalEditions.card_has_edition(card, element_key) and card.edition == nil
    end
end

local function with_area(args, area)
    local merged = ElementalEditions.copy_value(args or {})
    merged.area = area
    return merged
end

function ElementalEditions.apply_element_to_card(card, element_key)
    return ElementalEditions.debug.safe_call("apply_element_to_card", function()
        if not card then
            return false
        end

        if element_key == "grass" then
            if card.set_ability and G and G.P_CENTERS and G.P_CENTERS.m_poke_flower then
                return pcall(function()
                    card:set_ability(G.P_CENTERS.m_poke_flower, nil, true)
                end)
            end
            return false
        end

        local edition_key = ElementalEditions.get_edition_center_key(element_key)
        if not (edition_key and card.set_edition) then
            return false
        end

        return pcall(function()
            card:set_edition(edition_key, true, true)
        end)
    end, false)
end

function ElementalEditions.create_elemental_playing_card(element_key, area, args)
    local config = creation_config()
    if config.transform_instead_of_create == true then
        return nil
    end
    if not can_create(args and args.context, args and args.ignore_limits == true) then
        return nil
    end

    local created = SMODS.add_card({
        set = "Base",
        area = area or G.deck,
        no_edition = true,
    })
    if not created then
        return nil
    end

    ElementalEditions.apply_element_to_card(created, element_key)
    if not (args and args.ignore_limits == true) then
        register_creation(args and args.context)
    end
    if created.juice_up then
        created:juice_up()
    end
    return created
end

function ElementalEditions.create_flower_card(area, args)
    return ElementalEditions.create_elemental_playing_card("grass", area, args)
end

function ElementalEditions.transform_random_card_to_element(element_key, filter, args)
    local context = args and args.context or nil
    if not can_create(context, args and args.ignore_limits == true) then
        return nil
    end

    local area = args and args.area or nil
    local pool = area and area.cards or G and G.playing_cards or {}
    local candidates = candidate_from_pool(pool, filter or default_transform_filter(element_key))
    local picked = ElementalEditions.pick_random(candidates, "elem_transform:" .. tostring(element_key) .. ":" .. current_blind_stamp())
    if not picked then
        return nil
    end

    ElementalEditions.debug.log("transforming card to element", "challenges", {
        element = element_key,
        picked = picked,
        candidate_count = #candidates,
    }, context)

    local ok = ElementalEditions.apply_element_to_card(picked, element_key)
    if ok then
        if not (args and args.ignore_limits == true) then
            register_creation(context)
        end
        if picked.juice_up then
            picked:juice_up()
        end
    end

    return ok and picked or nil
end

function ElementalEditions.add_elemental_card_to_deck(element_key, args)
    if creation_config().transform_instead_of_create == true then
        return ElementalEditions.transform_random_card_to_element(element_key, nil, args)
    end
    return ElementalEditions.create_elemental_playing_card(element_key, G.deck, args)
end

function ElementalEditions.add_elemental_card_to_hand(element_key, args)
    if creation_config().transform_instead_of_create == true then
        return ElementalEditions.transform_random_card_to_element(element_key, nil, with_area(args, G.hand))
    end
    return ElementalEditions.create_elemental_playing_card(element_key, G.hand, args)
end

function ElementalEditions.add_elemental_card_to_discard(element_key, args)
    if creation_config().transform_instead_of_create == true then
        return ElementalEditions.transform_random_card_to_element(element_key, nil, with_area(args, G.discard))
    end
    return ElementalEditions.create_elemental_playing_card(element_key, G.discard, args)
end

return ElementalEditions
