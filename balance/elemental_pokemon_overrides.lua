local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local function scored_count(context, element_key)
    return ElementalEditions.get_scored_element_count(context, element_key)
end

local function held_count(context, element_key)
    return ElementalEditions.get_held_element_count(context, element_key)
end

local function scored_summary(context)
    return ElementalEditions.get_scored_element_channels(context)
end

local function distinct_scored_elements(context)
    local summary = scored_summary(context)
    local count = 0
    for _, element_key in ipairs(ElementalEditions.constants.element_keys) do
        if (summary.counts[element_key] or 0) > 0 then
            count = count + 1
        end
    end
    return count
end

local function most_common_scored_element(context)
    local summary = scored_summary(context)
    local chosen = nil
    local chosen_count = 0
    for _, element_key in ipairs(ElementalEditions.constants.element_keys) do
        local count = summary.counts[element_key] or 0
        if count > chosen_count then
            chosen = element_key
            chosen_count = count
        end
    end
    return chosen, chosen_count
end

local function has_status(card, status_key)
    local status = ElementalEditions.get_joker_status(card)
    return status and status.key == status_key
end

local function heal_lowest(amount)
    local target = ElementalEditions.get_lowest_hp_pokemon(false)
    if target then
        ElementalEditions.heal_pokemon(target, amount)
    end
end

local function clear_team_status(status_keys)
    local target, status = ElementalEditions.find_first_pokemon_with_status(status_keys)
    if target and status then
        ElementalEditions.clear_joker_status(target, status.key, "cleansed")
    end
end

local function infuse_element_once(card, token, element_key, context, message)
    if not ElementalEditions.once_per_hand(card, token, context) then
        return nil
    end

    local changed = ElementalEditions.transform_random_card_to_element(element_key, nil, { context = context })
    if changed and message then
        ElementalEditions.show_ability_trigger_message(card, message, nil, context)
    end
    return changed
end

local function add_result(result, field, amount)
    if type(amount) ~= "number" or amount == 0 then
        return result
    end
    result = result or {}
    result[field] = (result[field] or 0) + amount
    return result
end

return {
    metadata = {
        created_by = "Elemental Editions runtime override layer",
        direct_pokermon_edits = false,
        wrapped_function = "calculate",
    },
    overrides = {
        j_poke_bulbasaur = {
            enabled_key = "bulbasaur",
            display_name = "Bulbasaur",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Flower cards heal the weakest teammate and build Growth.",
            mechanics = { "Seed Recovery", "Growth" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "grass")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "bulbasaur_seed_recovery", context) then
                    heal_lowest(2)
                    ElementalEditions.add_elemental_counter(card, "growth", count)
                    if count >= 2 then
                        infuse_element_once(card, "bulbasaur_flower_seed", "grass", context, "Seeded!")
                    end
                end
                return {
                    chip_mod = (count * 8) + (ElementalEditions.get_elemental_counter(card, "growth") * 2),
                }
            end,
        },
        j_poke_ivysaur = {
            enabled_key = "ivysaur",
            display_name = "Ivysaur",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Flower cards build larger Growth stores and convert them into chips.",
            mechanics = { "Overgrow", "Growth" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "grass")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "ivysaur_overgrow", context) then
                    ElementalEditions.add_elemental_counter(card, "growth", count * 2)
                end
                return {
                    chip_mod = (count * 10) + (ElementalEditions.get_elemental_counter(card, "growth") * 3),
                }
            end,
        },
        j_poke_venusaur = {
            enabled_key = "venusaur",
            display_name = "Venusaur",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Flower cards grow Venusaur quickly and cleanse Dazed or Asleep allies.",
            mechanics = { "Solar Bloom", "Growth" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "grass")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "venusaur_solar_bloom", context) then
                    ElementalEditions.add_elemental_counter(card, "growth", count * 2)
                    clear_team_status({ "dazed", "asleep" })
                end
                return {
                    chip_mod = (count * 12) + (ElementalEditions.get_elemental_counter(card, "growth") * 2),
                    mult_mod = count,
                }
            end,
        },
        j_poke_charmander = {
            enabled_key = "charmander",
            display_name = "Charmander",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Fire pressure hurts Charmander less and builds Blaze for extra Mult.",
            mechanics = { "Kindling", "Blaze" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "fire")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                local blaze = math.min(ElementalEditions.get_elemental_counter(card, "blaze"), 2)
                return {
                    mult_mod = count + blaze,
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "fire" then
                    local reduced = math.max(0, math.floor((info.amount * 0.5) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                elseif element_key == "water" then
                    info.amount = math.max(0, math.floor((info.amount * 1.5) + 0.5))
                end
                return info
            end,
            on_damage_prevented = function(card, amount, element_key)
                if element_key == "fire" then
                    ElementalEditions.add_elemental_counter(card, "blaze", math.max(1, math.floor(amount / 2)))
                    infuse_element_once(card, "charmander_kindling", "fire", nil, nil)
                end
            end,
        },
        j_poke_charmeleon = {
            enabled_key = "charmeleon",
            display_name = "Charmeleon",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Charmeleon turns Fire pressure and Burn into a bigger Blaze payoff.",
            mechanics = { "Flare Temper", "Blaze" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "fire")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                local blaze = math.min(ElementalEditions.get_elemental_counter(card, "blaze"), 3)
                local burned_bonus = has_status(card, "burned") and count or 0
                return {
                    mult_mod = (count * 2) + blaze + burned_bonus,
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "fire" then
                    local reduced = math.max(0, math.floor((info.amount * 0.4) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                elseif element_key == "water" then
                    info.amount = math.max(0, math.floor((info.amount * 1.5) + 0.5))
                end
                return info
            end,
            on_damage_prevented = function(card, amount, element_key)
                if element_key == "fire" then
                    ElementalEditions.add_elemental_counter(card, "blaze", math.max(1, math.floor(amount / 2)))
                    infuse_element_once(card, "charmeleon_kindling", "fire", nil, nil)
                end
            end,
        },
        j_poke_charizard = {
            enabled_key = "charizard",
            display_name = "Charizard",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Prevented Fire damage becomes xMult fuel, but Water remains a threat.",
            mechanics = { "Inferno Engine", "Blaze" },
            extra_types = { "Bird" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "fire")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                local blaze = math.min(ElementalEditions.get_elemental_counter(card, "blaze"), 4)
                local result = {
                    x_mult_mod = (count * 0.15) + (blaze * 0.05),
                }
                if has_status(card, "burned") then
                    result.mult_mod = count
                end
                return result
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "fire" then
                    local reduced = math.max(0, math.floor((info.amount * 0.25) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                elseif element_key == "water" then
                    info.amount = math.max(0, math.floor((info.amount * 1.5) + 0.5))
                end
                return info
            end,
            on_damage_prevented = function(card, amount, element_key)
                if element_key == "fire" then
                    ElementalEditions.add_elemental_counter(card, "blaze", 1)
                    ElementalEditions.queue_pending_bonus(card, "x_mult_mod", amount * 0.03)
                end
            end,
        },
        j_poke_squirtle = {
            enabled_key = "squirtle",
            display_name = "Squirtle",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Squirtle shrugs off Water pressure and turns it into steady chips.",
            mechanics = { "Shell Guard" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "water")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "squirtle_shell_guard", context) and has_status(card, "burned") then
                    ElementalEditions.clear_joker_status(card, "burned", "cleansed")
                end
                if count >= 2 then
                    infuse_element_once(card, "squirtle_tide", "water", context, "Washed in!")
                end
                return {
                    chip_mod = count * 12,
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "water" then
                    local reduced = math.max(0, math.floor((info.amount * 0.25) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                elseif element_key == "fire" then
                    local reduced = math.max(0, math.floor((info.amount * 0.75) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                end
                return info
            end,
        },
        j_poke_wartortle = {
            enabled_key = "wartortle",
            display_name = "Wartortle",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Held Water cards harden Wartortle against Fire, and Water discards patch up allies.",
            mechanics = { "Tidal Guard" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "water")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                return {
                    chip_mod = (count * 15) + (held_count(context, "water") * 5),
                }
            end,
            modify_incoming_damage = function(card, info, element_key, hit_context)
                if element_key == "fire" then
                    local mult = held_count(hit_context and hit_context.context or nil, "water") > 0 and 0.5 or 0.75
                    local reduced = math.max(0, math.floor((info.amount * mult) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                end
                return info
            end,
            on_element_card_discarded = function(card, element_key, discarded_card, context)
                if element_key == "water" and ElementalEditions.once_per_hand(card, "wartortle_discard_heal", context) then
                    heal_lowest(2)
                    infuse_element_once(card, "wartortle_tide_trail", "water", context, "Tidal guard!")
                end
            end,
        },
        j_poke_blastoise = {
            enabled_key = "blastoise",
            display_name = "Blastoise",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Blastoise scales Water cards from its HP and rinses team ailments.",
            mechanics = { "Hydro Cannon" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "water")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "blastoise_cleanse", context) then
                    clear_team_status({ "burned", "confused" })
                end
                local hp = ElementalEditions.get_pokemon_hp(card) or 0
                return {
                    chip_mod = count * math.max(10, math.floor(hp / 4)),
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "fire" then
                    local reduced = math.max(0, math.floor((info.amount * 0.5) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                end
                return info
            end,
        },
        j_poke_pikachu = {
            enabled_key = "pikachu",
            display_name = "Pikachu",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Lightning cards build Static quickly, but Earth pressure punishes Pikachu hard.",
            mechanics = { "Static Spark", "Static" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "lightning")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "pikachu_static_spark", context) then
                    ElementalEditions.add_elemental_counter(card, "static", count)
                    if count >= 2 then
                        infuse_element_once(card, "pikachu_charge_lane", "lightning", context, "Sparked!")
                    end
                end
                return {
                    chip_mod = (count * 8) + (ElementalEditions.get_elemental_counter(card, "static") * 2),
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "earth" then
                    info.amount = math.max(0, math.floor((info.amount * 1.5) + 0.5))
                end
                return info
            end,
        },
        j_poke_raichu = {
            enabled_key = "raichu",
            display_name = "Raichu",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Raichu cashes in Static for bigger mult bursts but still fears Earth pressure.",
            mechanics = { "Overcharge", "Static" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "lightning")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "raichu_overcharge", context) then
                    ElementalEditions.add_elemental_counter(card, "static", count * 2)
                end
                return {
                    mult_mod = (count * 2) + math.min(ElementalEditions.get_elemental_counter(card, "static"), 4),
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "earth" then
                    info.amount = math.max(0, math.floor((info.amount * 1.5) + 0.5))
                end
                return info
            end,
        },
        j_poke_geodude = {
            enabled_key = "geodude",
            display_name = "Geodude",
            source_file = "pokemon/pokejokers_03.lua",
            summary = "Held Earth cards toughen Geodude, and missing HP turns Earth cards into chips.",
            mechanics = { "Rock Body" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "earth")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                local hp = ElementalEditions.get_pokemon_hp(card) or 0
                local max_hp = ElementalEditions.get_pokemon_hp_max(card) or hp
                if count >= 2 then
                    infuse_element_once(card, "geodude_harden", "earth", context, "Hardened!")
                end
                return {
                    chip_mod = (count * 10) + math.max(0, math.floor((max_hp - hp) / 2)),
                }
            end,
            modify_incoming_damage = function(card, info, element_key, hit_context)
                local reduction = held_count(hit_context and hit_context.context or nil, "earth")
                if reduction > 0 then
                    info.amount = math.max(0, info.amount - reduction)
                    info.prevented = info.prevented + reduction
                end
                return info
            end,
        },
        j_poke_onix = {
            enabled_key = "onix",
            display_name = "Onix",
            source_file = "pokemon/pokejokers_04.lua",
            summary = "Earth cards stock armor on Onix and help it blunt Lightning pressure.",
            mechanics = { "Burrow", "Armor" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "earth")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "onix_burrow", context) then
                    ElementalEditions.add_elemental_counter(card, "armor", count)
                end
                return {
                    chip_mod = (count * 16) + (ElementalEditions.get_elemental_counter(card, "armor") * 5),
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "lightning" then
                    local reduced = math.max(0, math.floor((info.amount * 0.25) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                end
                local armor = ElementalEditions.spend_elemental_counter(card, "armor", 1)
                if armor > 0 and info.amount > 0 then
                    info.amount = math.max(0, info.amount - 2)
                    info.prevented = info.prevented + 2
                end
                return info
            end,
        },
        j_poke_steelix = {
            enabled_key = "steelix",
            display_name = "Steelix",
            source_file = "pokemon/pokejokers_07.lua",
            summary = "Steelix banks more armor from Earth cards and shields itself from status chains.",
            mechanics = { "Iron Faultline", "Armor" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "earth")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "steelix_faultline", context) then
                    ElementalEditions.add_elemental_counter(card, "armor", count * 2)
                    clear_team_status({ "paralyzed" })
                end
                return {
                    chip_mod = (count * 20) + (ElementalEditions.get_elemental_counter(card, "armor") * 6),
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "fire" then
                    info.amount = math.max(0, math.floor((info.amount * 1.25) + 0.5))
                end
                local armor = ElementalEditions.spend_elemental_counter(card, "armor", 1)
                if armor > 0 and info.amount > 0 then
                    info.amount = math.max(0, info.amount - 3)
                    info.prevented = info.prevented + 3
                end
                return info
            end,
        },
        j_poke_gyarados = {
            enabled_key = "gyarados",
            display_name = "Gyarados",
            source_file = "pokemon/pokejokers_05.lua",
            summary = "Water pressure and Confusion build Rage, which Gyarados cashes in on Water hands.",
            mechanics = { "Rage Current", "Rage" },
            extra_types = { "Bird" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "water")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                local rage = ElementalEditions.spend_elemental_counter(card, "rage", math.min(ElementalEditions.get_elemental_counter(card, "rage"), count))
                return {
                    mult_mod = count + (rage * 2),
                }
            end,
            on_damage_taken = function(card, amount, element_key)
                if element_key == "water" then
                    ElementalEditions.add_elemental_counter(card, "rage", 1)
                end
            end,
            on_status_applied = function(card, status_key)
                if status_key == "confused" then
                    ElementalEditions.add_elemental_counter(card, "rage", 2)
                end
            end,
        },
        j_poke_jolteon = {
            enabled_key = "jolteon",
            display_name = "Jolteon",
            source_file = "pokemon/pokejokers_05.lua",
            summary = "Lightning damage charges Jolteon instead of hurting it, and Lightning hands pay it out.",
            mechanics = { "Volt Absorb", "Static" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "lightning")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                return {
                    chip_mod = count * (10 + (held_count(context, "lightning") * 3)),
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "lightning" and info.amount > 0 then
                    info.heal = info.heal + info.amount
                    info.prevented = info.prevented + info.amount
                    info.amount = 0
                    ElementalEditions.add_elemental_counter(card, "static", 1)
                end
                return info
            end,
        },
        j_poke_zapdos = {
            enabled_key = "zapdos",
            display_name = "Zapdos",
            source_file = "pokemon/pokejokers_05.lua",
            summary = "Zapdos amplifies Lightning hands into big chips and mult while Ground fights back.",
            mechanics = { "Thunderstorm", "Static" },
            extra_types = { "Bird" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "lightning")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "zapdos_thunderstorm", context) then
                    ElementalEditions.add_elemental_counter(card, "static", count)
                end
                return {
                    chip_mod = count * 15,
                    mult_mod = math.min(ElementalEditions.get_elemental_counter(card, "static"), 3),
                }
            end,
        },
        j_poke_oddish = {
            enabled_key = "oddish",
            display_name = "Oddish",
            source_file = "pokemon/pokejokers_02.lua",
            summary = "Flower cards help Asleep allies recover and give Oddish a modest Grass payoff.",
            mechanics = { "Sleep Powder" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "grass")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "oddish_sleep_powder", context) then
                    for _, teammate in ipairs(ElementalEditions.get_pokemon_jokers(false)) do
                        if has_status(teammate, "asleep") then
                            ElementalEditions.heal_pokemon(teammate, 2, context)
                        end
                    end
                end
                return {
                    mult_mod = count,
                    chip_mod = count * 6,
                }
            end,
        },
        j_poke_snorlax = {
            enabled_key = "snorlax",
            display_name = "Snorlax",
            source_file = "pokemon/pokejokers_05.lua",
            summary = "Snorlax treats Sleep as rest instead of shutdown and wakes with extra chips queued.",
            mechanics = { "Rest" },
            calculate_bonus = function(card, context)
                if not (context and context.joker_main) then
                    return
                end
                if has_status(card, "asleep") then
                    return {
                        chip_mod = 20,
                    }
                end
            end,
            allow_status_action = function(card, status_key)
                return status_key == "asleep"
            end,
            on_status_cleared = function(card, status_key)
                if status_key == "asleep" then
                    ElementalEditions.queue_pending_bonus(card, "chip_mod", 15)
                end
            end,
        },
        j_poke_magikarp = {
            enabled_key = "magikarp",
            display_name = "Magikarp",
            source_file = "pokemon/pokejokers_05.lua",
            summary = "Every elemental hit builds Splash; once it fills, Magikarp bursts for chips.",
            mechanics = { "Splash Charge", "Splash" },
            calculate_bonus = function(card, context)
                if not (context and context.joker_main) then
                    return
                end
                local splash = ElementalEditions.get_elemental_counter(card, "splash")
                if splash >= 5 then
                    local spent = ElementalEditions.spend_elemental_counter(card, "splash", 5)
                    return {
                        chip_mod = spent * 7,
                        mult_mod = 2,
                    }
                end
                local count = scored_count(context, "water")
                if count > 0 then
                    return {
                        chip_mod = count * 3,
                    }
                end
            end,
            on_damage_taken = function(card)
                ElementalEditions.add_elemental_counter(card, "splash", 1)
            end,
        },
        j_poke_caterpie = {
            enabled_key = "caterpie",
            display_name = "Caterpie",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Flower cards help Caterpie grow and occasionally seed more Flower pressure.",
            mechanics = { "Leaf Weave", "Growth" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "grass")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "caterpie_leaf_weave", context) then
                    ElementalEditions.add_elemental_counter(card, "growth", count)
                    if count >= 2 then
                        infuse_element_once(card, "caterpie_flower_trail", "grass", context, "Spores!")
                    end
                end
                return {
                    chip_mod = count * 5,
                    mult_mod = math.min(ElementalEditions.get_elemental_counter(card, "growth"), 2),
                }
            end,
        },
        j_poke_pidgey = {
            enabled_key = "pidgey",
            display_name = "Pidgey",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Pidgey stays nimble around Grass pressure but hates Lightning shocks.",
            mechanics = { "Gust Step" },
            extra_types = { "Bird" },
            calculate_bonus = function(card, context)
                local grass = scored_count(context, "grass")
                local fire = scored_count(context, "fire")
                if not (context and context.joker_main and (grass > 0 or fire > 0)) then
                    return
                end
                return {
                    chip_mod = (grass * 6) + (fire * 4),
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "grass" then
                    local reduced = math.max(0, math.floor((info.amount * 0.5) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                elseif element_key == "lightning" then
                    info.amount = math.max(0, math.floor((info.amount * 1.5) + 0.5))
                end
                return info
            end,
        },
        j_poke_sandshrew = {
            enabled_key = "sandshrew",
            display_name = "Sandshrew",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Sandshrew turns Earth cards into armor and grounds some Lightning pressure.",
            mechanics = { "Sand Hide", "Armor" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "earth")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "sandshrew_hide", context) then
                    ElementalEditions.add_elemental_counter(card, "armor", count)
                end
                return {
                    chip_mod = (count * 9) + (ElementalEditions.get_elemental_counter(card, "armor") * 3),
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "lightning" then
                    local reduced = math.max(0, math.floor((info.amount * 0.25) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                end
                return info
            end,
        },
        j_poke_psyduck = {
            enabled_key = "psyduck",
            display_name = "Psyduck",
            source_file = "pokemon/pokejokers_02.lua",
            summary = "Psyduck likes Water pressure but converts Confusion into healing.",
            mechanics = { "Headache Drift" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "water")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                return {
                    chip_mod = count * 9,
                }
            end,
            on_status_applied = function(card, status_key)
                if status_key == "confused" then
                    ElementalEditions.heal_pokemon(card, 3)
                end
            end,
        },
        j_poke_golduck = {
            enabled_key = "golduck",
            display_name = "Golduck",
            source_file = "pokemon/pokejokers_02.lua",
            summary = "Golduck turns Water hands into steadier mult and shrugs off Confusion.",
            mechanics = { "Calm Current" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "water")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if has_status(card, "confused") then
                    ElementalEditions.clear_joker_status(card, "confused", "cleansed")
                end
                return {
                    chip_mod = count * 10,
                    mult_mod = math.min(count, 2),
                }
            end,
        },
        j_poke_staryu = {
            enabled_key = "staryu",
            display_name = "Staryu",
            source_file = "pokemon/pokejokers_04.lua",
            summary = "Staryu channels Water pressure into chips and quick team patch-ups.",
            mechanics = { "Star Current" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "water")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "staryu_patch", context) then
                    heal_lowest(2)
                end
                return {
                    chip_mod = count * 11,
                }
            end,
        },
        j_poke_starmie = {
            enabled_key = "starmie",
            display_name = "Starmie",
            source_file = "pokemon/pokejokers_05.lua",
            summary = "Starmie rewards Water pressure with chips and a sharper mult edge.",
            mechanics = { "Prism Current" },
            extra_types = { "Psychic" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "water")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                return {
                    chip_mod = count * 12,
                    mult_mod = math.min(2, count),
                }
            end,
        },
        j_poke_voltorb = {
            enabled_key = "voltorb",
            display_name = "Voltorb",
            source_file = "pokemon/pokejokers_04.lua",
            summary = "Discarded Lightning cards wind Voltorb up into quick chip bursts.",
            mechanics = { "Stored Charge", "Static" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "lightning")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                return {
                    chip_mod = count * 7 + (ElementalEditions.get_elemental_counter(card, "static") * 2),
                }
            end,
            on_element_card_discarded = function(card, element_key, discarded_card, context)
                if element_key == "lightning" and ElementalEditions.once_per_hand(card, "voltorb_discard_charge", context) then
                    ElementalEditions.add_elemental_counter(card, "static", 2)
                    infuse_element_once(card, "voltorb_spark_lane", "lightning", context, "Charged!")
                end
            end,
        },
        j_poke_electrode = {
            enabled_key = "electrode",
            display_name = "Electrode",
            source_file = "pokemon/pokejokers_04.lua",
            summary = "Electrode cashes in bigger Lightning bursts, but Earth still keeps it honest.",
            mechanics = { "Overvoltage", "Static" },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "lightning")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                return {
                    chip_mod = count * 9,
                    mult_mod = math.min(ElementalEditions.get_elemental_counter(card, "static"), 3),
                }
            end,
            on_element_card_discarded = function(card, element_key, discarded_card, context)
                if element_key == "lightning" and ElementalEditions.once_per_hand(card, "electrode_discard_charge", context) then
                    ElementalEditions.add_elemental_counter(card, "static", 3)
                end
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "earth" then
                    info.amount = math.max(0, math.floor((info.amount * 1.5) + 0.5))
                end
                return info
            end,
        },
        j_poke_eevee = {
            enabled_key = "eevee",
            display_name = "Eevee",
            source_file = "pokemon/pokejokers_05.lua",
            summary = "Eevee adapts to mixed elemental hands and rewards variety.",
            mechanics = { "Adapt" },
            tooltip_lines = {
                "When different elements score together, Eevee gains chips and Mult.",
                "Big mixed hands can infuse another card with the dominant element.",
            },
            calculate_bonus = function(card, context)
                if not (context and context.joker_main) then
                    return
                end
                local distinct = distinct_scored_elements(context)
                if distinct <= 0 then
                    return
                end
                local common_element, common_count = most_common_scored_element(context)
                if distinct >= 3 and common_element and common_count >= 2 then
                    infuse_element_once(card, "eevee_adapt", common_element, context, "Adapted!")
                end
                return {
                    chip_mod = distinct * 7,
                    mult_mod = math.max(0, distinct - 1),
                }
            end,
        },
        j_poke_vaporeon = {
            enabled_key = "vaporeon",
            display_name = "Vaporeon",
            source_file = "pokemon/pokejokers_05.lua",
            summary = "Vaporeon absorbs Water pressure and turns it into healing and chips.",
            mechanics = { "Tide Absorb" },
            tooltip_lines = {
                "Water damage heals or is prevented instead of hurting Vaporeon.",
                "Scored Water cards add chips and can rinse away Burned.",
            },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "water")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if has_status(card, "burned") then
                    ElementalEditions.clear_joker_status(card, "burned", "cleansed")
                end
                return {
                    chip_mod = count * 14,
                    mult_mod = math.min(2, count - 1),
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "water" and info.amount > 0 then
                    info.heal = info.heal + info.amount
                    info.prevented = info.prevented + info.amount
                    info.amount = 0
                end
                return info
            end,
        },
        j_poke_flareon = {
            enabled_key = "flareon",
            display_name = "Flareon",
            source_file = "pokemon/pokejokers_05.lua",
            summary = "Flareon thrives under Fire pressure and cashes Burn into stronger offense.",
            mechanics = { "Ember Pelt", "Blaze" },
            tooltip_lines = {
                "Fire damage is heavily reduced and prevented Fire builds Blaze.",
                "Burned Flareon turns scored Fire cards into bigger Mult and xMult.",
            },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "fire")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                local blaze = math.min(ElementalEditions.get_elemental_counter(card, "blaze"), 5)
                local result = {
                    mult_mod = count + blaze,
                }
                if has_status(card, "burned") then
                    result.x_mult_mod = count * 0.10
                end
                return result
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "fire" then
                    local reduced = math.max(0, math.floor((info.amount * 0.35) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                elseif element_key == "water" then
                    info.amount = math.max(0, math.floor((info.amount * 1.25) + 0.5))
                end
                return info
            end,
            on_damage_prevented = function(card, amount, element_key)
                if element_key == "fire" then
                    ElementalEditions.add_elemental_counter(card, "blaze", math.max(1, math.floor(amount / 2)))
                end
            end,
        },
        j_poke_butterfree = {
            enabled_key = "butterfree",
            display_name = "Butterfree",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Butterfree turns Flower cards into sleep support, healing, and Growth.",
            mechanics = { "Sleep Dust", "Growth" },
            extra_types = { "Bird" },
            tooltip_lines = {
                "Flower cards add chips and help Asleep allies recover.",
                "Large Flower hands can seed more Grass pressure.",
            },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "grass")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "butterfree_sleep_dust", context) then
                    ElementalEditions.add_elemental_counter(card, "growth", count)
                    for _, teammate in ipairs(ElementalEditions.get_pokemon_jokers(false)) do
                        if has_status(teammate, "asleep") then
                            ElementalEditions.heal_pokemon(teammate, 2, context)
                        end
                    end
                    if count >= 2 then
                        infuse_element_once(card, "butterfree_spores", "grass", context, "Spored!")
                    end
                end
                return {
                    chip_mod = count * 7,
                    mult_mod = math.min(3, ElementalEditions.get_elemental_counter(card, "growth")),
                }
            end,
        },
        j_poke_sandslash = {
            enabled_key = "sandslash",
            display_name = "Sandslash",
            source_file = "pokemon/pokejokers_01.lua",
            summary = "Sandslash stores sturdier Earth armor and nearly grounds Lightning outright.",
            mechanics = { "Deep Burrow", "Armor" },
            tooltip_lines = {
                "Scored Earth cards add armor and chips.",
                "Lightning pressure is sharply reduced before armor is spent.",
            },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "earth")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "sandslash_burrow", context) then
                    ElementalEditions.add_elemental_counter(card, "armor", count * 2)
                end
                return {
                    chip_mod = (count * 12) + (ElementalEditions.get_elemental_counter(card, "armor") * 4),
                    mult_mod = math.min(2, held_count(context, "earth")),
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "lightning" then
                    local reduced = math.max(0, math.floor((info.amount * 0.10) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                end
                local armor = ElementalEditions.spend_elemental_counter(card, "armor", 1)
                if armor > 0 and info.amount > 0 then
                    info.amount = math.max(0, info.amount - 3)
                    info.prevented = info.prevented + 3
                end
                return info
            end,
        },
        j_poke_vileplume = {
            enabled_key = "vileplume",
            display_name = "Vileplume",
            source_file = "pokemon/pokejokers_02.lua",
            summary = "Vileplume converts Flower pressure into Growth, healing, and stronger Grass payoffs.",
            mechanics = { "Bloom Cycle", "Growth" },
            tooltip_lines = {
                "Flower cards add Growth and stronger chips.",
                "Asleep allies heal, and larger Flower hands push bigger Mult.",
            },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "grass")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "vileplume_bloom_cycle", context) then
                    ElementalEditions.add_elemental_counter(card, "growth", count * 2)
                    for _, teammate in ipairs(ElementalEditions.get_pokemon_jokers(false)) do
                        if has_status(teammate, "asleep") then
                            ElementalEditions.heal_pokemon(teammate, 3, context)
                        end
                    end
                end
                return {
                    chip_mod = (count * 11) + (ElementalEditions.get_elemental_counter(card, "growth") * 2),
                    mult_mod = math.min(3, count),
                }
            end,
        },
        j_poke_bellossom = {
            enabled_key = "bellossom",
            display_name = "Bellossom",
            source_file = "pokemon/pokejokers_07.lua",
            summary = "Bellossom turns Flower hands into team healing and graceful Growth payoff.",
            mechanics = { "Petal Rest", "Growth" },
            tooltip_lines = {
                "Flower cards heal the weakest ally and build Growth.",
                "Dazed or Asleep allies recover more cleanly around Bellossom.",
            },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "grass")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if ElementalEditions.once_per_hand(card, "bellossom_petal_rest", context) then
                    heal_lowest(3)
                    clear_team_status({ "dazed", "asleep" })
                    ElementalEditions.add_elemental_counter(card, "growth", count)
                end
                return {
                    chip_mod = count * 9,
                    mult_mod = math.min(4, ElementalEditions.get_elemental_counter(card, "growth")),
                }
            end,
        },
        j_poke_growlithe = {
            enabled_key = "growlithe",
            display_name = "Growlithe",
            source_file = "pokemon/pokejokers_02.lua",
            summary = "Growlithe is a steady Fire bruiser that turns reduced Fire damage into Blaze.",
            mechanics = { "Guard Flame", "Blaze" },
            tooltip_lines = {
                "Fire damage is reduced and builds Blaze when prevented.",
                "Scored Fire cards grant Mult and can kindle more Fire pressure.",
            },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "fire")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                if count >= 2 then
                    infuse_element_once(card, "growlithe_guard_flame", "fire", context, "Kindled!")
                end
                return {
                    mult_mod = count + math.min(3, ElementalEditions.get_elemental_counter(card, "blaze")),
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "fire" then
                    local reduced = math.max(0, math.floor((info.amount * 0.45) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                elseif element_key == "water" then
                    info.amount = math.max(0, math.floor((info.amount * 1.25) + 0.5))
                end
                return info
            end,
            on_damage_prevented = function(card, amount, element_key)
                if element_key == "fire" then
                    ElementalEditions.add_elemental_counter(card, "blaze", math.max(1, math.floor(amount / 2)))
                end
            end,
        },
        j_poke_arcanine = {
            enabled_key = "arcanine",
            display_name = "Arcanine",
            source_file = "pokemon/pokejokers_02.lua",
            summary = "Arcanine turns big Fire hands into heavy Mult bursts and shrugs off heat.",
            mechanics = { "Inferno Rush", "Blaze" },
            tooltip_lines = {
                "Fire damage is strongly reduced and feeds Blaze.",
                "Large Fire hands pay out Mult and a little xMult, especially while Burned.",
            },
            calculate_bonus = function(card, context)
                local count = scored_count(context, "fire")
                if not (context and context.joker_main and count > 0) then
                    return
                end
                local blaze = math.min(ElementalEditions.get_elemental_counter(card, "blaze"), 5)
                local result = {
                    mult_mod = (count * 2) + blaze,
                }
                if count >= 2 then
                    result.x_mult_mod = count * 0.08
                end
                if has_status(card, "burned") then
                    result.mult_mod = result.mult_mod + count
                end
                return result
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "fire" then
                    local reduced = math.max(0, math.floor((info.amount * 0.30) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                elseif element_key == "water" then
                    info.amount = math.max(0, math.floor((info.amount * 1.35) + 0.5))
                end
                return info
            end,
            on_damage_prevented = function(card, amount, element_key)
                if element_key == "fire" then
                    ElementalEditions.add_elemental_counter(card, "blaze", math.max(1, math.floor(amount / 2)))
                end
            end,
        },
        j_poke_dragonite = {
            enabled_key = "dragonite",
            display_name = "Dragonite",
            source_file = "pokemon/pokejokers_05.lua",
            summary = "Dragonite rewards mixed elemental hands and can spread the dominant element further.",
            mechanics = { "Storm Shift" },
            extra_types = { "Bird" },
            tooltip_lines = {
                "Different scored elements grant chips and Mult together.",
                "Very mixed hands can spread the dominant element to another card.",
            },
            calculate_bonus = function(card, context)
                if not (context and context.joker_main) then
                    return
                end
                local distinct = distinct_scored_elements(context)
                if distinct <= 0 then
                    return
                end
                local common_element, common_count = most_common_scored_element(context)
                if distinct >= 4 and common_element and common_count >= 2 then
                    infuse_element_once(card, "dragonite_storm_shift", common_element, context, "Storm shift!")
                end
                return {
                    chip_mod = distinct * 10,
                    mult_mod = math.max(0, distinct - 1),
                    x_mult_mod = distinct >= 4 and 0.12 or 0,
                }
            end,
            modify_incoming_damage = function(card, info, element_key)
                if element_key == "grass" or element_key == "water" or element_key == "fire" then
                    local reduced = math.max(0, math.floor((info.amount * 0.85) + 0.5))
                    info.prevented = info.prevented + math.max(0, info.amount - reduced)
                    info.amount = reduced
                end
                return info
            end,
        },
    },
}
