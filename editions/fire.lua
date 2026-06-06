local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

if not ElementalEditions.is_enabled("fire") then
    return
end

SMODS.Shader({
    key = "fire",
    path = "fire.fs",
})

SMODS.Edition({
    key = "fire",
    shader = "fire",
    disable_shadow = false,
    disable_base_shader = true,
    discovered = ElementalEditions.get_dev_config().discovered ~= false,
    unlocked = ElementalEditions.get_dev_config().unlocked ~= false,
    in_shop = ElementalEditions.get_shop_config().in_shop ~= false,
    weight = ElementalEditions.get_shop_config().weight or 7,
    extra_cost = ElementalEditions.get_shop_config().extra_cost or 4,
    loc_vars = function(self, info_queue, card)
        local uses = card and card.ability and card.ability.elem_fire_score_count or 0
        return {
            vars = {
                ElementalEditions.get_section("pressure").fire_mult or 4,
                uses,
            },
        }
    end,
    calculate = function(self, card, context)
        return ElementalEditions.debug.safe_call("edition:fire", function()
            ElementalEditions.debug.trace("edition calculate", {
                edition = "fire",
                card = card,
            }, "editions", context)

            if not ElementalEditions.is_playing_card_edition_context(card, context) then
                return
            end

            local pressure = ElementalEditions.get_section("pressure")
            local uses = ElementalEditions.add_number(card, "elem_fire_score_count", 1, 0)
            local bonus = (pressure.fire_mult or 4) + math.floor(uses / math.max(1, pressure.fire_ramp_every or 3))
            local result = {
                mult_mod = bonus,
            }
            ElementalEditions.debug.trace("edition result", {
                edition = "fire",
                result = result,
                card = card,
            }, "editions", context)
            return result
        end, nil, context)
    end,
})
