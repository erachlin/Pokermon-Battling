local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

if not ElementalEditions.is_enabled("earth") then
    return
end

SMODS.Shader({
    key = "earth",
    path = "earth.fs",
})

SMODS.Edition({
    key = "earth",
    shader = "earth",
    disable_shadow = false,
    disable_base_shader = true,
    discovered = ElementalEditions.get_dev_config().discovered ~= false,
    unlocked = ElementalEditions.get_dev_config().unlocked ~= false,
    in_shop = ElementalEditions.get_shop_config().in_shop ~= false,
    weight = ElementalEditions.get_shop_config().weight or 7,
    extra_cost = ElementalEditions.get_shop_config().extra_cost or 4,
    loc_vars = function(self, info_queue, card)
        local pressure = ElementalEditions.get_section("pressure")
        return {
            vars = {
                pressure.earth_base_chips or 20,
                pressure.earth_repeat_bonus or 5,
                pressure.earth_durable_bonus or 5,
            },
        }
    end,
    calculate = function(self, card, context)
        return ElementalEditions.debug.safe_call("edition:earth", function()
            ElementalEditions.debug.trace("edition calculate", {
                edition = "earth",
                card = card,
            }, "editions", context)

            if not ElementalEditions.is_playing_card_edition_context(card, context) then
                return
            end

            local pressure = ElementalEditions.get_section("pressure")
            local repeated = ElementalEditions.count_repeated_ranks(context.scoring_hand or {})
            local durable = ElementalEditions.count_durable_cards(context.scoring_hand or {})

            local result = {
                chip_mod = (pressure.earth_base_chips or 20)
                    + (repeated * (pressure.earth_repeat_bonus or 5))
                    + (durable * (pressure.earth_durable_bonus or 5)),
            }
            ElementalEditions.debug.trace("edition result", {
                edition = "earth",
                result = result,
                card = card,
            }, "editions", context)
            return result
        end, nil, context)
    end,
})
