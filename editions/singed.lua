local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

if not ElementalEditions.is_enabled("singed") then
    return
end

local tuning = ElementalEditions.get_tuning()
local shop = ElementalEditions.get_shop_config()
local dev = ElementalEditions.get_dev_config()

SMODS.Shader({
    key = "singed",
    path = "singed.fs",
})

SMODS.Edition({
    key = "singed",
    shader = "singed",
    disable_shadow = false,
    disable_base_shader = true,
    discovered = dev.discovered ~= false,
    unlocked = dev.unlocked ~= false,
    in_shop = true,
    weight = shop.weight or 7,
    extra_cost = shop.extra_cost or 4,
    config = {
        chip_loss = tuning.singed_chip_loss or 5,
    },
    loc_vars = function(self, info_queue, card)
        local penalty = 0
        if card and card.ability then
            penalty = card.ability.ee_singed_penalty or 0
        end

        return {
            vars = {
                self.config.chip_loss or 5,
                penalty,
            },
        }
    end,
    calculate = function(self, card, context)
        if not card or not context then
            return
        end

        local is_scoring_card = G and context.cardarea == G.play
        local is_scoring_joker = G and context.cardarea == G.jokers and context.edition

        if not (is_scoring_card or is_scoring_joker) then
            return
        end

        local chip_loss = ElementalEditions.get_tuning().singed_chip_loss or self.config.chip_loss or 5
        local penalty = ElementalEditions.add_number(card, "ee_singed_penalty", chip_loss, 0)

        -- Current local scoring code cleanly accepts negative chip_mod values, so Singed
        -- can drive contribution below zero unless a future SMODS update changes that path.
        return {
            chip_mod = -penalty,
        }
    end,
})
