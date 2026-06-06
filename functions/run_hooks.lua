local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local function run_state()
    if not (G and G.GAME) then
        return nil
    end

    if type(G.GAME.elem_state) ~= "table" then
        G.GAME.elem_state = {}
    end
    return G.GAME.elem_state
end

local function seed_existing_cards()
    local state = run_state()
    local starter_config = ElementalEditions.get_section("starter")
    if not state or state.starter_seeded or not ElementalEditions.get_section("gameplay").enable_run_start_elemental_cards then
        return
    end
    if ElementalEditions.battle_mode_is_active and ElementalEditions.battle_mode_is_active() then
        return
    end
    if not starter_config.infuse_existing_cards or not (G and type(G.playing_cards) == "table") then
        return
    end

    local cards = {}
    for _, card in ipairs(G.playing_cards) do
        if card and not card.edition then
            cards[#cards + 1] = card
        end
    end

    for _, edition_key in ipairs({ "fire", "water", "earth", "lightning" }) do
        local picked, picked_index = ElementalEditions.pick_random(cards, "elem_starter_" .. edition_key .. "_" .. tostring(G.GAME.round_resets.ante or 0))
        if picked and picked.set_edition then
            local center_key = ElementalEditions.get_edition_center_key(edition_key)
            pcall(function()
                picked:set_edition(center_key, true, true)
            end)
            picked:juice_up()
            ElementalEditions.remove_at(cards, picked_index)
        end
    end

    state.starter_seeded = true
end

local function trace_context_data(context)
    return {
        scoring_name = context and context.scoring_name or nil,
        flags = {
            setting_blind = context and context.setting_blind or false,
            discard = context and context.discard or false,
            after = context and context.after or false,
            end_of_round = context and context.end_of_round or false,
            edition = context and context.edition or false,
            joker_main = context and context.joker_main or false,
        },
        scoring_cards = context and context.scoring_hand and #context.scoring_hand or nil,
        has_other_card = context and context.other_card ~= nil or nil,
    }
end

local function run_phase(label, category, context, fn, fallback)
    return ElementalEditions.debug.safe_call(label, function()
        ElementalEditions.debug.trace(label .. ":begin", trace_context_data(context), category, context)
        local result = fn()
        ElementalEditions.debug.trace(label .. ":end", result, category, context)
        return result
    end, fallback, context)
end

local function revive_knocked_out_team()
    if not ElementalEditions.get_section("gameplay").enable_auto_revive_end_of_blind then
        return
    end

    local hp_config = ElementalEditions.get_section("hp")
    for _, card in ipairs(ElementalEditions.get_pokemon_jokers(true)) do
        if ElementalEditions.is_pokemon_knocked_out(card) then
            local max_hp = ElementalEditions.get_pokemon_hp_max(card) or 1
            local revive_amount = math.max(hp_config.auto_revive_min or 1, math.floor((max_hp * (hp_config.auto_revive_percent or 0.25)) + 0.5))
            ElementalEditions.revive_pokemon(card, revive_amount)
        end
    end
end

function ElementalEditions.handle_set_debuff(card)
    if not ElementalEditions.is_pokermon_joker(card) then
        return false
    end

    return ElementalEditions.debug.safe_call("set_debuff", function()
        ElementalEditions.init_pokemon_hp(card)
        return ElementalEditions.is_pokemon_knocked_out(card) or false
    end, false, { other_card = card })
end

function ElementalEditions.handle_calculate(context)
    if not ElementalEditions.available or type(context) ~= "table" then
        return
    end

    ElementalEditions.get_debug_trace_id(context, true)
    ElementalEditions.debug.log("calculate hook entered", context.discard and "discard" or context.setting_blind and "challenges" or "scoring", trace_context_data(context), context)

    if ElementalEditions.register_pokemon_overrides and not ElementalEditions._pokemon_overrides_registered then
        run_phase("register_pokemon_overrides", "challenges", context, function()
            ElementalEditions.register_pokemon_overrides()
        end)
    end

    if ElementalEditions.recover_optional_cardareas then
        run_phase("recover_optional_cardareas", "challenges", context, function()
            ElementalEditions.recover_optional_cardareas()
        end)
    end

    run_phase("repair_playing_card_editions", "editions", context, function()
        local repaired = ElementalEditions.repair_playing_card_editions()
        if repaired and repaired > 0 then
            ElementalEditions.debug.log("repaired legacy editions", "editions", { repaired = repaired }, context)
        end
        return repaired
    end, 0)

    run_phase("refresh_pokemon_team", "status", context, function()
        ElementalEditions.refresh_pokemon_team()
    end)

    if ElementalEditions.refresh_status_visuals and not ElementalEditions.is_scoring_action_context(context) and not context.discard then
        run_phase("refresh_status_visuals", "status", context, function()
            ElementalEditions.refresh_status_visuals(context)
        end)
    end

    if context.setting_blind then
        if ElementalEditions.handle_battle_mode_setting_blind then
            run_phase("handle_battle_mode_setting_blind", "challenges", context, function()
                ElementalEditions.handle_battle_mode_setting_blind(context)
            end)
        end
        if ElementalEditions.handle_trainer_battle_setting_blind then
            run_phase("handle_trainer_battle_setting_blind", "challenges", context, function()
                ElementalEditions.handle_trainer_battle_setting_blind(context)
            end)
        end
        run_phase("seed_existing_cards", "challenges", context, seed_existing_cards)
        run_phase("apply_boss_status_pressure", "challenges", context, function()
            ElementalEditions.apply_boss_status_pressure(context)
        end)
    end

    if context.discard and not context.blueprint and ElementalEditions.get_section("gameplay").enable_discard_damage then
        run_phase("apply_elemental_damage_from_discard_context", "discard", context, function()
            ElementalEditions.apply_elemental_damage_from_discard_context(context)
        end)
        if ElementalEditions.handle_trainer_battle_context then
            run_phase("handle_trainer_battle_context:discard", "challenges", context, function()
                ElementalEditions.handle_trainer_battle_context(context)
            end)
        end
    end

    if context.after and not context.blueprint then
        if ElementalEditions.get_section("gameplay").enable_elemental_damage then
            run_phase("apply_elemental_damage_from_scored_cards", "scoring", context, function()
                ElementalEditions.apply_elemental_damage_from_scored_cards(context)
            end)
        end
        run_phase("apply_elemental_pressure_from_held_cards", "scoring", context, function()
            ElementalEditions.apply_elemental_pressure_from_held_cards(context)
        end)
        run_phase("tick_joker_statuses", "status", context, function()
            ElementalEditions.tick_joker_statuses(context)
        end)
        if ElementalEditions.handle_trainer_battle_context then
            run_phase("handle_trainer_battle_context:after", "challenges", context, function()
                ElementalEditions.handle_trainer_battle_context(context)
            end)
        end
    end

    if context.end_of_round and context.main_eval and context.game_over == false then
        run_phase("revive_knocked_out_team", "status", context, revive_knocked_out_team)
    end

    ElementalEditions.debug.trace("calculate hook exited", trace_context_data(context), context.discard and "discard" or "scoring", context)
end

return ElementalEditions
