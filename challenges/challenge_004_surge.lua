local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local trainer = {
    key = "surge_voltage_test",
    name = "Lt. Surge",
    starter_distribution = {
        fire = 0,
        water = 0,
        earth = 0,
        lightning = 7,
        grass = 0,
    },
    growth_distribution = {
        fire = 0,
        water = 0,
        earth = 1,
        lightning = 1,
        grass = 0,
    },
    boss_sequence = {
        { ante = 1, pokemon = "Voltorb", element = "lightning", blind_name = "Surge's Voltorb", intro = "Lt. Surge rolls out Voltorb!" },
        { ante = 2, pokemon = "Pikachu", element = "lightning", blind_name = "Surge's Pikachu", intro = "Lt. Surge powers up Pikachu!" },
        { ante = 4, pokemon = "Raichu", element = "lightning", blind_name = "Surge's Raichu", intro = "Lt. Surge's Raichu lights up the blind!", damage_bonus = 3, status_bonus = 0.15 },
    },
}

ElementalEditions.register_trainer_definition(trainer.key, trainer)

return {
    key = trainer.key,
    enabled_key = trainer.key,
    name = "Lt. Surge's Voltage Test",
    loc_txt = {
        name = "Lt. Surge's Voltage Test",
        text = {
            "Starts with only {C:yellow}Lightning{} pressure cards",
            "Channel Lt. Surge's voltage safely",
            "through repeated shock pressure",
        },
    },
    rules = {
        modifiers = {
            { id = "joker_slots", value = 5 },
        },
    },
    jokers = {
        { id = "j_poke_geodude" },
        { id = "j_poke_onix" },
        { id = "j_poke_sandshrew" },
    },
    restrictions = {
        banned_other = {
            { id = "bl_poke_mirror", type = "blind" },
        },
    },
    deck = ElementalEditions.build_elemental_challenge_deck(trainer.starter_distribution, "Challenge Deck"),
    button_colour = HEX("D7B127"),
    text_colour = HEX("FFFBE6"),
    apply = function(self)
        ElementalEditions.activate_trainer_battle(trainer.key, { starter_seeded = true })
    end,
}
