local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local function new_summary()
    return {
        counts = {
            fire = 0,
            water = 0,
            earth = 0,
            lightning = 0,
            grass = 0,
        },
        cards = {
            fire = {},
            water = {},
            earth = {},
            lightning = {},
            grass = {},
        },
        total = 0,
    }
end

local function cache_key_for_held(context)
    local stamp = ElementalEditions.get_hand_stamp(context)
    local hand_count = G and G.hand and type(G.hand.cards) == "table" and #G.hand.cards or 0
    return tostring(stamp) .. ":" .. tostring(hand_count)
end

function ElementalEditions.get_card_element(card)
    if not card then
        return nil
    end

    for _, key in ipairs({ "fire", "water", "earth", "lightning" }) do
        if ElementalEditions.card_has_edition(card, key) then
            return key
        end
    end

    if ElementalEditions.has_flower_channel(card) then
        return "grass"
    end

    return nil
end

local function add_card_to_summary(summary, card)
    local element_key = ElementalEditions.get_card_element(card)
    if not element_key then
        return
    end

    summary.counts[element_key] = (summary.counts[element_key] or 0) + 1
    summary.cards[element_key][#summary.cards[element_key] + 1] = card
    summary.total = summary.total + 1
end

function ElementalEditions.get_scored_element_channels(context)
    if type(context) == "table" and type(context.elem_scored_summary) == "table" then
        return context.elem_scored_summary
    end

    local summary = new_summary()
    if type(context) ~= "table" or type(context.scoring_hand) ~= "table" then
        return summary
    end

    for _, card in ipairs(context.scoring_hand) do
        add_card_to_summary(summary, card)
    end

    context.elem_scored_summary = summary
    return summary
end

function ElementalEditions.get_held_element_channels(context)
    local cache_key = cache_key_for_held(context)
    if type(context) == "table" and type(context.elem_held_summary) == "table" and context.elem_held_summary_key == cache_key then
        return context.elem_held_summary
    end

    local summary = new_summary()
    if not (G and G.hand and type(G.hand.cards) == "table") then
        return summary
    end

    for _, card in ipairs(G.hand.cards) do
        add_card_to_summary(summary, card)
    end

    if type(context) == "table" then
        context.elem_held_summary = summary
        context.elem_held_summary_key = cache_key
    end
    return summary
end

function ElementalEditions.get_hand_pressure_multiplier(context)
    local hand_scaling = ElementalEditions.get_section("hand_scaling")
    local hand_key = ElementalEditions.constants.hand_key_by_name[context and context.scoring_name or ""]
    return hand_scaling[hand_key or "high_card"] or 1
end

function ElementalEditions.count_repeated_ranks(cards)
    if type(cards) ~= "table" then
        return 0
    end

    local counts = {}
    local duplicates = 0
    for _, card in ipairs(cards) do
        local rank = card and card.base and card.base.id or card and card.get_id and card:get_id() or nil
        if rank then
            counts[rank] = (counts[rank] or 0) + 1
        end
    end

    for _, count in pairs(counts) do
        if count > 1 then
            duplicates = duplicates + (count - 1)
        end
    end

    return duplicates
end

function ElementalEditions.count_durable_cards(cards)
    if type(cards) ~= "table" then
        return 0
    end

    local durable = 0
    for _, card in ipairs(cards) do
        local effect = card and card.ability and card.ability.effect or ""
        if effect == "Stone Card" or effect == "Steel Card" or effect == "Gold Card" then
            durable = durable + 1
        end
    end
    return durable
end

return ElementalEditions
