local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local trainer = {
    key = "brocks_rock_wall",
    name = "Brock",
    starter_distribution = {
        fire = 0,
        water = 0,
        earth = 8,
        lightning = 0,
        grass = 0,
    },
    growth_distribution = {
        fire = 0,
        water = 1,
        earth = 1,
        lightning = 0,
        grass = 1,
    },
    boss_sequence = {
        { ante = 1, pokemon = "Geodude", element = "earth", blind_name = "Brock's Geodude", intro = "Brock sends out Geodude!", status_target = "highest_value" },
        { ante = 2, pokemon = "Onix", element = "earth", blind_name = "Brock's Onix", intro = "Brock's Onix towers over the blind!", status_target = "highest_value", damage_bonus = 3 },
        { ante = 4, pokemon = "Steelix", element = "earth", blind_name = "Brock's Steelix", intro = "Brock's Steelix slams the field!", status_target = "highest_value", damage_bonus = 3, after_hand_transform_chance = 0.65 },
    },
}

ElementalEditions.register_trainer_definition(trainer.key, trainer)

return {
    key = trainer.key,
    enabled_key = trainer.key,
    name = "Brock's Rock Wall",
    loc_txt = {
        name = "Brock's Rock Wall",
        text = {
            "Starts with only {C:attention}Earth{} pressure cards",
            "Survive Brock's heavy ground game",
            "and turn the field against him",
        },
    },
    rules = {
        modifiers = {
            { id = "joker_slots", value = 5 },
        },
    },
    jokers = {
        { id = "j_poke_bulbasaur" },
        { id = "j_poke_squirtle" },
        { id = "j_poke_oddish" },
    },
    restrictions = {
        banned_other = {
            { id = "bl_poke_mirror", type = "blind" },
        },
    },
    deck = ElementalEditions.build_elemental_challenge_deck(trainer.starter_distribution, "Challenge Deck"),
    button_colour = HEX("8B6A3A"),
    text_colour = HEX("F3E9D2"),
    apply = function(self)
        ElementalEditions.activate_trainer_battle(trainer.key, { starter_seeded = true })
    end,
}
