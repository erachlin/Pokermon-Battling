local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local battle_mode_config = ElementalEditions.get_section("battle_mode")

local battledeck = {
    name = "Elemental Battle Deck",
    key = "battledeck",
    unlocked = true,
    discovered = true,
    config = {},
    loc_vars = function(self, info_queue, center)
        return {
            vars = {
                localize({ type = "name_text", key = battle_mode_config.starter_deck_joker or "j_poke_bulbasaur", set = "Joker" }),
                localize({ type = "name_text", key = battle_mode_config.starter_deck_item or "c_poke_pokeball", set = "Item" }),
                battle_mode_config.growth_per_ante or 1,
            },
        }
    end,
    pos = { x = 0, y = 4 },
    apply = function(self)
        ElementalEditions.activate_battle_mode("deck", {
            starter_per_element = battle_mode_config.starter_per_element or 1,
            growth_per_ante = battle_mode_config.growth_per_ante or 1,
        })
        ElementalEditions.schedule_battle_mode_seed()

        G.E_MANAGER:add_event(Event({
            func = function()
                local joker_key = battle_mode_config.starter_deck_joker or "j_poke_bulbasaur"
                local item_key = battle_mode_config.starter_deck_item or "c_poke_pokeball"

                local joker = SMODS.add_card({
                    area = G.jokers,
                    set = "Joker",
                    key = joker_key,
                })

                SMODS.add_card({
                    set = "Item",
                    key = item_key,
                })

                return true
            end
        }))
    end,
}

return {
    name = "Back",
    list = { battledeck },
}
