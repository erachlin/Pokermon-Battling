local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local trainer = {
    key = "erikas_bloom_garden",
    name = "Erika",
    starter_distribution = {
        fire = 0,
        water = 0,
        earth = 0,
        lightning = 0,
        grass = 8,
    },
    growth_distribution = {
        fire = 1,
        water = 0,
        earth = 0,
        lightning = 0,
        grass = 1,
    },
    boss_sequence = {
        { ante = 1, pokemon = "Oddish", element = "grass", blind_name = "Erika's Oddish", intro = "Erika lets Oddish scatter spores!" },
        { ante = 2, pokemon = "Ivysaur", element = "grass", blind_name = "Erika's Ivysaur", intro = "Erika's Ivysaur vines through the field!" },
        { ante = 4, pokemon = "Venusaur", element = "grass", blind_name = "Erika's Venusaur", intro = "Erika's Venusaur blooms over the blind!", status_bonus = 0.15, after_hand_transform_chance = 0.70 },
    },
}

ElementalEditions.register_trainer_definition(trainer.key, trainer)

return {
    key = trainer.key,
    enabled_key = trainer.key,
    name = "Erika's Bloom Garden",
    loc_txt = {
        name = "Erika's Bloom Garden",
        text = {
            "Starts with only {C:green}Flower{} pressure cards",
            "Manage Erika's sleep and healing loop",
            "while the whole deck keeps blooming",
        },
    },
    rules = {
        modifiers = {
            { id = "joker_slots", value = 5 },
        },
    },
    jokers = {
        { id = "j_poke_charmander" },
        { id = "j_poke_pidgey" },
        { id = "j_poke_caterpie" },
    },
    restrictions = {
        banned_other = {
            { id = "bl_poke_mirror", type = "blind" },
        },
    },
    deck = ElementalEditions.build_elemental_challenge_deck(trainer.starter_distribution, "Challenge Deck"),
    button_colour = HEX("5F9E4E"),
    text_colour = HEX("F6FFF0"),
    apply = function(self)
        ElementalEditions.activate_trainer_battle(trainer.key, { starter_seeded = true })
    end,
}
