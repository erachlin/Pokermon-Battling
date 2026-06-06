local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

if not ElementalEditions.is_enabled("water") then
    return
end

SMODS.Shader({
    key = "water",
    path = "water.fs",
})

SMODS.Edition({
    key = "water",
    shader = "water",
    disable_shadow = false,
    disable_base_shader = true,
    discovered = ElementalEditions.get_dev_config().discovered ~= false,
    unlocked = ElementalEditions.get_dev_config().unlocked ~= false,
    in_shop = ElementalEditions.get_shop_config().in_shop ~= false,
    weight = ElementalEditions.get_shop_config().weight or 7,
    extra_cost = ElementalEditions.get_shop_config().extra_cost or 4,
    loc_vars = function(self, info_queue, card)
        local pressure = ElementalEditions.get_section("pressure")
        local current = pressure.water_starting_chips or 40
        if card and card.ability and type(card.ability.elem_water_value) == "number" then
            current = card.ability.elem_water_value
        end

        return {
            vars = {
                pressure.water_starting_chips or 40,
                pressure.water_chip_loss or 5,
                current,
            },
        }
    end,
    calculate = function(self, card, context)
        return ElementalEditions.debug.safe_call("edition:water", function()
            ElementalEditions.debug.trace("edition calculate", {
                edition = "water",
                card = card,
            }, "editions", context)

            if not ElementalEditions.is_playing_card_edition_context(card, context) then
                return
            end

            local pressure = ElementalEditions.get_section("pressure")
            local current_value = ElementalEditions.ensure_number(card, "elem_water_value", pressure.water_starting_chips or 40)
            local next_value = math.max(pressure.water_minimum_chips or 10, current_value - (pressure.water_chip_loss or 5))
            card.ability.elem_water_value = next_value

            local result = {
                chip_mod = current_value,
            }
            ElementalEditions.debug.trace("edition result", {
                edition = "water",
                result = result,
                card = card,
            }, "editions", context)
            return result
        end, nil, context)
    end,
})
