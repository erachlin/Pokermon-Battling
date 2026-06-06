local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local trainer = {
    key = "youngster_first_battle",
    name = "Youngster",
    starter_distribution = {
        fire = 2,
        water = 2,
        earth = 1,
        lightning = 1,
        grass = 2,
    },
    growth_distribution = {
        fire = 1,
        water = 1,
        earth = 0,
        lightning = 0,
        grass = 1,
    },
    boss_sequence = {
        { ante = 1, pokemon = "Caterpie", element = "grass", blind_name = "Youngster's Caterpie", intro = "Youngster sends out Caterpie!" },
        { ante = 2, pokemon = "Pikachu", element = "lightning", blind_name = "Youngster's Pikachu", intro = "Youngster sends out Pikachu!" },
        { ante = 3, pokemon = "Geodude", element = "earth", blind_name = "Youngster's Geodude", intro = "Youngster sends out Geodude!", status_target = "leftmost" },
        { ante = 4, pokemon = "Charmeleon", element = "fire", blind_name = "Youngster's Charmeleon", intro = "Youngster's ace steps in!" },
    },
}

ElementalEditions.register_trainer_definition(trainer.key, trainer)

return {
    key = trainer.key,
    enabled_key = trainer.key,
    name = "Youngster's First Battle",
    loc_txt = {
        name = "Youngster's First Battle",
        text = {
            "A mixed starter lesson",
            "with {C:red}Fire{}, {C:blue}Water{},",
            "{C:green}Flower{}, {C:attention}Earth{}, and",
            "{C:yellow}Lightning{} battle pressure",
        },
    },
    rules = {
        modifiers = {
            { id = "joker_slots", value = 5 },
        },
    },
    jokers = {
        { id = "j_poke_bulbasaur" },
        { id = "j_poke_charmander" },
        { id = "j_poke_squirtle" },
    },
    consumeables = {
        { id = "c_poke_pokeball" },
    },
    restrictions = {
        banned_other = {
            { id = "bl_poke_mirror", type = "blind" },
        },
    },
    deck = ElementalEditions.build_elemental_challenge_deck(trainer.starter_distribution, "Challenge Deck"),
    button_colour = HEX("C78038"),
    text_colour = HEX("FFF5D6"),
    apply = function(self)
        ElementalEditions.activate_trainer_battle(trainer.key, { starter_seeded = true })
    end,
}
