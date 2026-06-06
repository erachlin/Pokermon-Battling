local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

ElementalEditions.challenge_defs = ElementalEditions.challenge_defs or {}

local deck_suits = { "D", "C", "H", "S" }
local deck_ranks = { "2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A" }

local function build_standard_deck_cards()
    local cards = {}
    local keyed_cards = {}
    for _, suit in ipairs(deck_suits) do
        for _, rank in ipairs(deck_ranks) do
            local proto = { s = suit, r = rank }
            cards[#cards + 1] = proto
            keyed_cards[suit .. ":" .. rank] = proto
        end
    end
    return cards, keyed_cards
end

local function apply_element_to_proto(proto, element_key)
    if type(proto) ~= "table" or type(element_key) ~= "string" then
        return proto
    end

    if element_key == "grass" then
        proto.e = ElementalEditions.constants.elements.grass.enhancement
        proto.d = nil
        return proto
    end

    proto.d = ElementalEditions.get_edition_center_key(element_key)
    return proto
end

function ElementalEditions.build_elemental_challenge_deck(distribution, deck_type)
    local cards, keyed_cards = build_standard_deck_cards()
    local starter_slots = {}

    for _, rank in ipairs(deck_ranks) do
        for _, suit in ipairs(deck_suits) do
            starter_slots[#starter_slots + 1] = keyed_cards[suit .. ":" .. rank]
        end
    end

    local slot_index = 1

    for _, element_key in ipairs(ElementalEditions.constants.element_keys) do
        local copies = math.max(0, math.floor(tonumber(distribution and distribution[element_key]) or 0))
        for _ = 1, copies do
            if not starter_slots[slot_index] then
                break
            end
            apply_element_to_proto(starter_slots[slot_index], element_key)
            slot_index = slot_index + 1
        end
    end

    return {
        type = deck_type or "Challenge Deck",
        cards = cards,
    }
end

function ElementalEditions.load_challenge_defs()
    if ElementalEditions.get_section("gameplay").enable_trainer_challenges == false or ElementalEditions.get_section("trainer_challenges").enabled == false then
        ElementalEditions.challenge_defs = {}
        return
    end

    local base_path = (ElementalEditions.mod and ElementalEditions.mod.path or "") .. "challenges/"
    local filenames = {}

    for _, filename in ipairs((ElementalEditions.nfs and ElementalEditions.nfs.getDirectoryItems(base_path)) or {}) do
        if filename:match("%.lua$") then
            local info = ElementalEditions.nfs.getInfo(base_path .. filename)
            if info and info.type == "file" then
                filenames[#filenames + 1] = filename
            end
        end
    end

    table.sort(filenames)
    ElementalEditions.challenge_defs = {}

    for _, filename in ipairs(filenames) do
        local challenge = assert(SMODS.load_file("challenges/" .. filename), "Elemental Editions failed to load challenges/" .. filename)()
        assert(type(challenge) == "table", ("Challenge file %s must return a table"):format(filename))
        assert(type(challenge.key) == "string" and challenge.key ~= "", ("Challenge file %s is missing a key"):format(filename))
        assert(type(challenge.name) == "string" and challenge.name ~= "", ("Challenge file %s is missing a name"):format(filename))

        local challenge_toggles = ElementalEditions.get_section("trainer_challenges")
        if not (challenge.enabled_key and challenge_toggles[challenge.enabled_key] == false) then
            if type(challenge.deck) == "string" then
                challenge.deck = { type = challenge.deck }
            end

            challenge.source_file = filename
            ElementalEditions.challenge_defs[#ElementalEditions.challenge_defs + 1] = challenge
        end
    end
end

function ElementalEditions.register_challenge_defs()
    for _, definition in ipairs(ElementalEditions.challenge_defs or {}) do
        SMODS.Challenge({
            key = definition.key,
            loc_txt = definition.loc_txt or { name = definition.name },
            rules = definition.rules,
            restrictions = definition.restrictions,
            jokers = definition.jokers,
            consumeables = definition.consumeables,
            vouchers = definition.vouchers,
            deck = definition.deck or { type = "Challenge Deck" },
            button_colour = definition.button_colour,
            text_colour = definition.text_colour,
            apply = definition.apply,
            calculate = definition.calculate,
        })
    end
end

return ElementalEditions
