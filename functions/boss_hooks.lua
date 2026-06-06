local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local function current_blind()
    return G and G.GAME and G.GAME.blind or nil
end

local function blind_key(blind)
    local config = blind and blind.config and blind.config.blind
    return config and config.key or blind and blind.name or "unknown"
end

local function choose_boss_element(blind)
    local trainer_boss = ElementalEditions.get_active_trainer_boss and ElementalEditions.get_active_trainer_boss() or nil
    if trainer_boss and trainer_boss.element then
        return trainer_boss.element
    end

    local key = string.lower(blind_key(blind))
    if key:find("magma", 1, true) then
        return "fire"
    end
    if key:find("aqua", 1, true) then
        return "water"
    end

    local options = { "fire", "water", "earth", "lightning", "grass" }
    local chosen = ElementalEditions.pick_random(options, "elem_boss_" .. key .. "_" .. tostring(G.GAME.round_resets.ante or 0))
    return chosen or "fire"
end

local function select_boss_target(element_key)
    local trainer_boss = ElementalEditions.get_active_trainer_boss and ElementalEditions.get_active_trainer_boss() or nil
    local targets = ElementalEditions.get_pokemon_jokers(false)
    if #targets == 0 then
        return nil
    end

    local target_rule = trainer_boss and trainer_boss.status_target or nil
    if target_rule == "leftmost" then
        return targets[1]
    end
    if target_rule == "highest_value" then
        table.sort(targets, function(a, b)
            return (a.sell_cost or 0) > (b.sell_cost or 0)
        end)
        return targets[1]
    end

    if element_key == "earth" then
        table.sort(targets, function(a, b)
            return (a.sell_cost or 0) > (b.sell_cost or 0)
        end)
        return targets[1]
    end

    if element_key == "lightning" then
        return targets[1]
    end

    return ElementalEditions.pick_random(targets, "elem_boss_target_" .. element_key .. "_" .. tostring(G.GAME.round_resets.ante or 0))
end

function ElementalEditions.apply_boss_status_pressure(context)
    if not ElementalEditions.get_section("gameplay").enable_boss_status_attacks then
        return
    end

    local blind = current_blind()
    if not (context and context.setting_blind and blind and blind.boss) then
        return
    end

    local element_key = choose_boss_element(blind)
    local target = select_boss_target(element_key)
    local status_key = ElementalEditions.constants.elements[element_key] and ElementalEditions.constants.elements[element_key].status

    if target and status_key then
        ElementalEditions.apply_joker_status(target, status_key, nil, {
            kind = "boss",
            blind = blind_key(blind),
            element = element_key,
        })
        ElementalEditions.show_status_text(target, ElementalEditions.element_label(element_key), G.C.RED)
    end
end

return ElementalEditions
