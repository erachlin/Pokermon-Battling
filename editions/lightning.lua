local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

if not ElementalEditions.is_enabled("lightning") then
    return
end

SMODS.Shader({
    key = "lightning",
    path = "lightning.fs",
})

SMODS.Edition({
    key = "lightning",
    shader = "lightning",
    disable_shadow = true,
    disable_base_shader = true,
    discovered = ElementalEditions.get_dev_config().discovered ~= false,
    unlocked = ElementalEditions.get_dev_config().unlocked ~= false,
    in_shop = ElementalEditions.get_shop_config().in_shop ~= false,
    weight = ElementalEditions.get_shop_config().weight or 7,
    extra_cost = ElementalEditions.get_shop_config().extra_cost or 4,
    loc_vars = function(self, info_queue, card)
        return {
            vars = {
                ElementalEditions.get_section("pressure").lightning_chip_per_card or 10,
            },
        }
    end,
    calculate = function(self, card, context)
        return ElementalEditions.debug.safe_call("edition:lightning", function()
            ElementalEditions.debug.trace("edition calculate", {
                edition = "lightning",
                card = card,
            }, "editions", context)

            if not ElementalEditions.is_playing_card_edition_context(card, context) then
                return
            end

            local summary = ElementalEditions.get_scored_element_channels(context)
            local result = {
                chip_mod = (ElementalEditions.get_section("pressure").lightning_chip_per_card or 10) * math.max(1, summary.counts.lightning or 0),
            }
            ElementalEditions.debug.trace("edition result", {
                edition = "lightning",
                result = result,
                card = card,
            }, "editions", context)
            return result
        end, nil, context)
    end,
})
