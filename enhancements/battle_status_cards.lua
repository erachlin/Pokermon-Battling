local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

if not ElementalEditions.is_enabled("singed") then
    return
end

local function singed_config()
    return ElementalEditions.get_section("card_status")
end

SMODS.Shader({
    key = "singed",
    path = "singed.fs",
})

SMODS.Edition({
    key = "singed",
    shader = "singed",
    disable_shadow = false,
    disable_base_shader = true,
    discovered = ElementalEditions.get_dev_config().discovered ~= false,
    unlocked = true,
    in_shop = false,
    weight = 0,
    extra_cost = 0,
    config = {
        chip_loss = singed_config().singed_chip_loss or 5,
    },
    loc_vars = function(self, info_queue, card)
        return {
            vars = {
                self.config.chip_loss or 5,
                card and card.ability and card.ability.elem_singed_penalty or 0,
            },
        }
    end,
    calculate = function(self, card, context)
        return ElementalEditions.debug.safe_call("edition:singed", function()
            if not ElementalEditions.is_playing_card_edition_context(card, context) then
                return
            end

            local penalty = ElementalEditions.add_number(card, "elem_singed_penalty", self.config.chip_loss or 5, 0)
            return {
                chip_mod = -penalty,
            }
        end, nil, context)
    end,
})

function ElementalEditions.can_receive_singed(card)
    if not card then
        return false
    end

    if ElementalEditions.card_has_edition(card, "singed") then
        return false
    end

    return card.edition == nil
end

function ElementalEditions.apply_singed(card, source)
    if not (card and card.set_edition and ElementalEditions.can_receive_singed(card)) then
        return false
    end

    local edition_key = ElementalEditions.get_edition_center_key("singed")
    local ok = pcall(function()
        card:set_edition(edition_key, true, true)
    end)

    if ok then
        ElementalEditions.show_status_text(card, ElementalEditions.safe_localize("elem_singed", "Singed"), G.C.RED, {
            delay = ElementalEditions.get_message_delay and ElementalEditions.get_message_delay("status") or nil,
            context = source and source.context or nil,
        })
    end

    return ok
end

return ElementalEditions
