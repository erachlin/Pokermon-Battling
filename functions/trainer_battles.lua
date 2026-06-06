local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

ElementalEditions.trainer_defs = ElementalEditions.trainer_defs or {}

local function trainer_config()
    return ElementalEditions.get_section("trainer_challenges")
end

local function boss_config()
    return ElementalEditions.get_section("boss")
end

local function state()
    if not (G and G.GAME) then
        return nil
    end

    if type(G.GAME.elem_trainer_battle) ~= "table" then
        G.GAME.elem_trainer_battle = {}
    end
    return G.GAME.elem_trainer_battle
end

local function current_ante()
    return G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or 1
end

local function status_colour(element_key)
    if element_key == "fire" then
        return G.C.RED
    elseif element_key == "water" then
        return G.C.BLUE
    elseif element_key == "lightning" then
        return G.C.YELLOW
    elseif element_key == "earth" then
        return G.C.ORANGE
    end
    return G.C.GREEN
end

local function announce(text, colour)
    if not text then
        return
    end

    local hold = (ElementalEditions.get_message_delay and ElementalEditions.get_message_delay("summary") or 1.35)

    if attention_text and G and G.play then
        ElementalEditions.debug.safe_call("trainer_announce_attention_text", function()
            attention_text({
                text = text,
                scale = 0.75,
                hold = hold,
                major = G.play,
                backdrop_colour = colour or G.C.ORANGE,
                align = "cm",
                offset = { x = 0, y = -1.0 },
                silent = true,
            })
        end)
        return
    end

    local anchor = ElementalEditions.get_pokemon_jokers(true)[1]
    if anchor then
        ElementalEditions.show_status_text(anchor, text, colour or G.C.ORANGE, {
            delay = hold,
        })
    end
end

local function get_definition(trainer_key)
    return trainer_key and ElementalEditions.trainer_defs and ElementalEditions.trainer_defs[trainer_key] or nil
end

local function get_active_definition()
    local battle_state = state()
    return battle_state and get_definition(battle_state.trainer_key) or nil
end

local function get_boss_for_ante(definition, ante)
    if not (definition and type(definition.boss_sequence) == "table") then
        return nil
    end

    local chosen = nil
    for _, boss in ipairs(definition.boss_sequence) do
        if (boss.ante or 1) <= ante then
            chosen = boss
        end
    end

    return chosen or definition.boss_sequence[1]
end

local function maybe_transform_for_boss(element_key, context, chance)
    if not element_key or not chance or chance <= 0 then
        return
    end

    local seed = table.concat({
        "elem_trainer_boss_transform",
        tostring(element_key),
        tostring(current_ante()),
        tostring(context and context.scoring_name or context and context.other_card and context.other_card.sort_id or "none"),
    }, ":")

    if ElementalEditions.roll(seed, chance) then
        local changed = ElementalEditions.transform_random_card_to_element(element_key, nil, { context = context })
        if changed then
            announce((ElementalEditions.element_label(element_key) or element_key) .. " pressure spreads!", status_colour(element_key))
        end
    end
end

function ElementalEditions.register_trainer_definition(trainer_key, definition)
    if type(trainer_key) ~= "string" or type(definition) ~= "table" then
        return
    end
    ElementalEditions.trainer_defs[trainer_key] = definition
end

function ElementalEditions.activate_trainer_battle(trainer_key, options)
    local definition = get_definition(trainer_key)
    if not definition then
        return nil
    end

    local battle_state = state()
    if not battle_state then
        return nil
    end

    battle_state.active = true
    battle_state.trainer_key = trainer_key
    battle_state.current_boss_name = nil
    battle_state.current_boss_element = nil

    options = type(options) == "table" and options or {}
    local starter_seeded = options.starter_seeded == true
    local ante = current_ante()

    ElementalEditions.activate_battle_mode("trainer_challenge", {
        trainer_key = trainer_key,
        starter_distribution = starter_seeded and nil or definition.starter_distribution,
        growth_distribution = definition.growth_distribution,
        starter_per_element = 0,
        growth_per_ante = 0,
        seeded = starter_seeded,
        last_growth_ante = starter_seeded and ante or 0,
    })

    return battle_state
end

function ElementalEditions.get_active_trainer_battle()
    local battle_state = state()
    if not (battle_state and battle_state.active) then
        return nil, nil
    end
    return battle_state, get_active_definition()
end

function ElementalEditions.get_active_trainer_boss()
    local battle_state, definition = ElementalEditions.get_active_trainer_battle()
    if not (battle_state and definition) then
        return nil, nil, nil
    end

    local boss = get_boss_for_ante(definition, current_ante())
    return boss, definition, battle_state
end

function ElementalEditions.get_boss_damage_bonus(element_key)
    if ElementalEditions.get_section("gameplay").enable_boss_pokemon_effects == false then
        return 0
    end

    local boss = ElementalEditions.get_active_trainer_boss()
    if boss and boss.element == element_key then
        return boss.damage_bonus or boss_config().element_damage_bonus or 0
    end

    return 0
end

function ElementalEditions.get_boss_status_bonus(element_key)
    if ElementalEditions.get_section("gameplay").enable_boss_pokemon_effects == false then
        return 0
    end

    local boss = ElementalEditions.get_active_trainer_boss()
    if boss and boss.element == element_key then
        return boss.status_bonus or boss_config().status_bonus or 0
    end

    return 0
end

function ElementalEditions.handle_trainer_battle_setting_blind(context)
    local boss, definition, battle_state = ElementalEditions.get_active_trainer_boss()
    if not (context and context.setting_blind and boss and definition and battle_state) then
        return
    end

    battle_state.current_boss_name = boss.pokemon
    battle_state.current_boss_element = boss.element
    battle_state.current_boss_display = boss.blind_name or ((definition.name or "Trainer") .. "'s " .. tostring(boss.pokemon))

    if G and G.GAME and G.GAME.blind and G.GAME.blind.boss then
        G.GAME.blind.loc_name = battle_state.current_boss_display
        ElementalEditions.debug.safe_call("refresh_trainer_blind_name", function()
            if G.HUD_blind then
                local blind_name = G.HUD_blind:get_UIE_by_ID("HUD_blind_name")
                if blind_name and blind_name.config and blind_name.config.object and blind_name.config.object.pop_in then
                    blind_name.config.object:pop_in(0)
                end
            end
        end, nil, context)
    end

    ElementalEditions.debug.log("trainer blind set", "challenges", {
        trainer = definition.name,
        boss = boss.pokemon,
        display = battle_state.current_boss_display,
        element = boss.element,
    }, context)

    if battle_state.current_intro_ante ~= current_ante() then
        battle_state.current_intro_ante = current_ante()
        local intro = boss.intro or ((definition.name or "Trainer") .. " sends out " .. tostring(boss.pokemon) .. "!")
        announce(intro, status_colour(boss.element))
    end
end

function ElementalEditions.handle_trainer_battle_context(context)
    local boss = ElementalEditions.get_active_trainer_boss()
    if not (boss and ElementalEditions.get_section("gameplay").enable_boss_pokemon_effects ~= false) then
        return
    end

    if context and context.after and not context.blueprint then
        maybe_transform_for_boss(
            boss.transform_element or boss.element,
            context,
            boss.after_hand_transform_chance or boss_config().after_hand_transform_chance or 0
        )
    elseif context and context.discard and not context.blueprint then
        maybe_transform_for_boss(
            boss.discard_transform_element or boss.element,
            context,
            boss.after_discard_transform_chance or boss_config().after_discard_transform_chance or 0
        )
    end
end

return ElementalEditions
