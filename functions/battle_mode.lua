local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local function mode_defaults()
    local config = ElementalEditions.get_section("battle_mode")
    return {
        active = false,
        source = nil,
        starter_per_element = config.starter_per_element or 1,
        growth_per_ante = config.growth_per_ante or 1,
        starter_distribution = nil,
        growth_distribution = nil,
        seeded = false,
        last_growth_ante = 0,
        growths_applied = 0,
    }
end

local function merge_mode_state(base, overrides)
    local merged = {}
    for key, value in pairs(base or {}) do
        merged[key] = value
    end
    for key, value in pairs(overrides or {}) do
        merged[key] = value
    end
    return merged
end

local function ensure_game_state()
    if not (G and G.GAME) then
        return nil
    end

    if type(G.GAME.elem_battle_mode) ~= "table" then
        G.GAME.elem_battle_mode = mode_defaults()
    end

    local state = G.GAME.elem_battle_mode
    for key, value in pairs(mode_defaults()) do
        if state[key] == nil then
            state[key] = value
        end
    end

    G.GAME.modifiers = G.GAME.modifiers or {}
    return state
end

local function edition_candidates()
    local candidates = {}
    if not (G and type(G.playing_cards) == "table") then
        return candidates
    end

    for _, card in ipairs(G.playing_cards) do
        if card and not card.edition then
            candidates[#candidates + 1] = card
        end
    end

    return candidates
end

local function infuse_one(element_key, seed_key)
    local candidates = edition_candidates()
    if #candidates == 0 then
        return false
    end

    local picked, picked_index = ElementalEditions.pick_random(candidates, seed_key .. ":" .. element_key)
    if not (picked and picked.set_edition) then
        return false
    end

    local edition_key = ElementalEditions.get_edition_center_key(element_key)
    local ok = pcall(function()
        picked:set_edition(edition_key, true, true)
    end)

    if ok and picked.juice_up then
        picked:juice_up()
    end

    return ok
end

local function infuse_distribution(distribution, seed_key)
    local infused = 0
    for _, element_key in ipairs(ElementalEditions.constants.element_keys) do
        local count = math.max(0, math.floor(tonumber(distribution and distribution[element_key]) or 0))
        for copy_index = 1, count do
            local created = ElementalEditions.add_elemental_card_to_deck(
                element_key,
                {
                    context = {
                        scoring_name = "trainer_seed",
                    },
                    ignore_limits = true,
                    seed_key = table.concat({ seed_key or "elem_distribution", element_key, tostring(copy_index) }, ":"),
                }
            )
            if created then
                infused = infused + 1
            end
        end
    end
    return infused
end

function ElementalEditions.get_battle_mode_state()
    return ensure_game_state()
end

function ElementalEditions.battle_mode_is_active()
    local state = ensure_game_state()
    return state and state.active == true or false
end

function ElementalEditions.activate_battle_mode(source, overrides)
    local state = ensure_game_state()
    if not state then
        return nil
    end

    state = merge_mode_state(state, overrides or {})
    state.active = true
    state.source = source or state.source or "unknown"
    G.GAME.elem_battle_mode = state
    G.GAME.modifiers.elem_battle_training = true
    return state
end

function ElementalEditions.infuse_element_set(count_per_element, seed_key)
    local count = math.max(0, tonumber(count_per_element) or 0)
    if count <= 0 then
        return 0
    end

    local infused = 0
    for _, element_key in ipairs({ "fire", "water", "earth", "lightning" }) do
        for copy_index = 1, count do
            if infuse_one(element_key, table.concat({ seed_key or "elem_infuse", element_key, tostring(copy_index), tostring(G.GAME.round_resets and G.GAME.round_resets.ante or 1) }, ":")) then
                infused = infused + 1
            end
        end
    end

    return infused
end

function ElementalEditions.infuse_element_distribution(distribution, seed_key)
    if type(distribution) ~= "table" then
        return 0
    end
    return infuse_distribution(distribution, seed_key)
end

local function apply_starter_seed(state, current_ante)
    if state.starter_distribution then
        ElementalEditions.infuse_element_distribution(state.starter_distribution, "elem_battle_starter")
    else
        ElementalEditions.infuse_element_set(state.starter_per_element or 1, "elem_battle_starter")
    end
    state.seeded = true
    state.last_growth_ante = current_ante
end

local function apply_growth_seed(state, next_ante)
    if state.growth_distribution then
        ElementalEditions.infuse_element_distribution(state.growth_distribution, "elem_battle_growth_" .. tostring(next_ante))
    else
        ElementalEditions.infuse_element_set(state.growth_per_ante or 0, "elem_battle_growth_" .. tostring(next_ante))
    end
end

function ElementalEditions.handle_battle_mode_setting_blind(context)
    local state = ensure_game_state()
    if not (state and state.active and context and context.setting_blind) then
        return
    end

    local current_ante = G.GAME.round_resets and G.GAME.round_resets.ante or 1

    if not state.seeded then
        apply_starter_seed(state, current_ante)
        return
    end

    while (state.last_growth_ante or 0) < current_ante do
        apply_growth_seed(state, (state.last_growth_ante or 0) + 1)
        state.last_growth_ante = (state.last_growth_ante or 0) + 1
        state.growths_applied = (state.growths_applied or 0) + 1
    end
end

function ElementalEditions.seed_battle_mode_now()
    local state = ensure_game_state()
    if not (state and state.active) then
        return true
    end
    if state.seeded then
        return true
    end
    if not (G and type(G.playing_cards) == "table" and #G.playing_cards > 0) then
        return false
    end

    local current_ante = G.GAME.round_resets and G.GAME.round_resets.ante or 1
    apply_starter_seed(state, current_ante)
    return true
end

function ElementalEditions.schedule_battle_mode_seed()
    if not (G and G.E_MANAGER) then
        return
    end

    G.E_MANAGER:add_event(Event({
        func = function()
            return ElementalEditions.seed_battle_mode_now()
        end
    }))
end

return ElementalEditions
