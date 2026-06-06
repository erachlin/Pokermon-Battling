local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local function center_key(card)
    return card and card.config and card.config.center and card.config.center.key or nil
end

local function normalize_type_name(type_name)
    if type(type_name) ~= "string" or type_name == "" then
        return nil
    end

    return ElementalEditions.constants.type_aliases[type_name] or type_name
end

local function push_unique(list, seen, value)
    local normalized = normalize_type_name(value)
    if normalized and not seen[normalized] then
        seen[normalized] = true
        list[#list + 1] = normalized
    end
end

function ElementalEditions.get_center_key(card)
    return center_key(card)
end

function ElementalEditions.is_pokermon_joker(card)
    if not (card and card.ability and card.ability.set == "Joker") then
        return false
    end

    if ElementalEditions.get_section("gameplay").allow_non_pokemon_hp then
        return true
    end

    local center = card.config and card.config.center or nil
    local key = center_key(card)
    return not not (
        (center and center.stage) or
        (center and center.ptype) or
        (center and center.poke_custom_prefix) or
        (type(key) == "string" and key:match("^j_poke_"))
    )
end

function ElementalEditions.get_pokemon_type(card)
    if not card then
        return nil
    end

    if type(rawget(_G, "get_type")) == "function" then
        local ok, value = pcall(get_type, card)
        if ok and value then
            return normalize_type_name(value)
        end
    end

    local extra = card.ability and card.ability.extra
    if type(extra) == "table" and extra.ptype then
        return normalize_type_name(extra.ptype)
    end

    local center = card.config and card.config.center or nil
    return normalize_type_name(center and center.ptype or nil)
end

function ElementalEditions.get_pokemon_types(card)
    local types = {}
    local seen = {}

    push_unique(types, seen, ElementalEditions.get_pokemon_type(card))

    local extra = card and card.ability and card.ability.extra or nil
    if type(extra) == "table" and type(extra.elem_extra_types) == "table" then
        for _, value in ipairs(extra.elem_extra_types) do
            push_unique(types, seen, value)
        end
    end

    local center = card and card.config and card.config.center or nil
    if center and type(center.elem_extra_types) == "table" then
        for _, value in ipairs(center.elem_extra_types) do
            push_unique(types, seen, value)
        end
    end

    if ElementalEditions.get_override_extra_types then
        local override_types = ElementalEditions.get_override_extra_types(card)
        if type(override_types) == "table" then
            for _, value in ipairs(override_types) do
                push_unique(types, seen, value)
            end
        end
    end

    return types
end

function ElementalEditions.get_primary_pokemon_type(card)
    return ElementalEditions.get_pokemon_types(card)[1]
end

function ElementalEditions.get_element_attack_type(element_key)
    local element = ElementalEditions.constants.elements[element_key]
    return element and element.attack_type or nil
end

function ElementalEditions.has_flower_channel(card)
    return card and SMODS and SMODS.has_enhancement and SMODS.has_enhancement(card, ElementalEditions.constants.elements.grass.enhancement)
end

function ElementalEditions.element_matches_type(element_key, pokemon_type)
    local attack_type = ElementalEditions.get_element_attack_type(element_key)
    return normalize_type_name(attack_type) == normalize_type_name(pokemon_type)
end

function ElementalEditions.get_type_multiplier_against_types(element_key, type_list)
    local damage_config = ElementalEditions.get_section("damage")
    local chart = ElementalEditions.get_section("effectiveness")
    local row = chart[element_key] or {}
    local attack_type = normalize_type_name(ElementalEditions.get_element_attack_type(element_key))

    if type(type_list) ~= "table" or #type_list == 0 then
        return 1
    end

    local multiplier = 1
    for _, value in ipairs(type_list) do
        local target_type = normalize_type_name(value)
        local entry = row[target_type]

        if attack_type == "Lightning" and target_type == "Earth" then
            entry = damage_config.lightning_ground_multiplier
        elseif attack_type == "Earth" and target_type == "Bird" then
            entry = damage_config.earth_bird_multiplier
        end

        if entry == nil and attack_type and target_type == attack_type then
            entry = damage_config.same_type_resist or 0.5
        end

        if entry == nil then
            entry = 1
        end

        multiplier = multiplier * entry
    end

    local min_multiplier = damage_config.min_multiplier or 0
    local max_multiplier = damage_config.max_multiplier or 4
    multiplier = math.max(min_multiplier, math.min(max_multiplier, multiplier))
    return multiplier
end

function ElementalEditions.get_type_multiplier(element_key, pokemon_card)
    return ElementalEditions.get_type_multiplier_against_types(element_key, ElementalEditions.get_pokemon_types(pokemon_card))
end

function ElementalEditions.format_effectiveness_message(multiplier)
    local damage_config = ElementalEditions.get_section("damage")
    if multiplier <= 0 then
        return "elem_no_effect"
    end
    if multiplier >= (damage_config.super_effective_threshold or 1.5) then
        return "elem_super_effective"
    end
    if multiplier < (damage_config.resisted_threshold or 0.75) then
        return "elem_resisted"
    end
    return nil
end

function ElementalEditions.get_pokemon_jokers(include_knocked_out)
    local jokers = {}
    if not (G and G.jokers and type(G.jokers.cards) == "table") then
        return jokers
    end

    for _, card in ipairs(G.jokers.cards) do
        if ElementalEditions.is_pokermon_joker(card) then
            if include_knocked_out or not ElementalEditions.is_pokemon_knocked_out or not ElementalEditions.is_pokemon_knocked_out(card) then
                jokers[#jokers + 1] = card
            end
        end
    end

    return jokers
end

return ElementalEditions
