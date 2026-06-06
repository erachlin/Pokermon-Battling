local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local trainer = {
    key = "mistys_tidal_trial",
    name = "Misty",
    starter_distribution = {
        fire = 0,
        water = 7,
        earth = 0,
        lightning = 0,
        grass = 0,
    },
    growth_distribution = {
        fire = 0,
        water = 1,
        earth = 0,
        lightning = 1,
        grass = 1,
    },
    boss_sequence = {
        { ante = 1, pokemon = "Psyduck", element = "water", blind_name = "Misty's Psyduck", intro = "Misty opens with Psyduck!" },
        { ante = 2, pokemon = "Staryu", element = "water", blind_name = "Misty's Staryu", intro = "Misty's Staryu rides the current!" },
        { ante = 4, pokemon = "Starmie", element = "water", blind_name = "Misty's Starmie", intro = "Misty's Starmie floods the arena!", damage_bonus = 3, status_bonus = 0.15 },
    },
}

ElementalEditions.register_trainer_definition(trainer.key, trainer)

return {
    key = trainer.key,
    enabled_key = trainer.key,
    name = "Misty's Tidal Trial",
    loc_txt = {
        name = "Misty's Tidal Trial",
        text = {
            "Starts with only {C:blue}Water{} pressure cards",
            "Ride Misty's currents without drowning",
            "and keep your team steady",
        },
    },
    rules = {
        modifiers = {
            { id = "joker_slots", value = 5 },
        },
    },
    jokers = {
        { id = "j_poke_bulbasaur" },
        { id = "j_poke_oddish" },
        { id = "j_poke_pikachu" },
    },
    restrictions = {
        banned_other = {
            { id = "bl_poke_mirror", type = "blind" },
        },
    },
    deck = ElementalEditions.build_elemental_challenge_deck(trainer.starter_distribution, "Challenge Deck"),
    button_colour = HEX("459FE2"),
    text_colour = HEX("F0FBFF"),
    apply = function(self)
        ElementalEditions.activate_trainer_battle(trainer.key, { starter_seeded = true })
    end,
}
