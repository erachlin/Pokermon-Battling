local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local function localized_line(key, fallback)
    local value = ElementalEditions.safe_localize(key, fallback)
    if value == key then
        return fallback
    end
    return value
end

local function append_text_row(desc_nodes, text, colour, scale)
    if not (desc_nodes and text and text ~= "") then
        return
    end

    desc_nodes[#desc_nodes + 1] = {
        { n = G.UIT.T, config = { text = text, colour = colour or G.C.WHITE, scale = scale or 0.24 } },
    }
end

local function append_localized_row(desc_nodes, key, fallback, colour, scale)
    append_text_row(desc_nodes, localized_line(key, fallback), colour, scale)
end

local function append_override_rows(card, desc_nodes)
    local lines = ElementalEditions.get_pokemon_override_tooltip_lines and ElementalEditions.get_pokemon_override_tooltip_lines(card) or nil
    if type(lines) ~= "table" or #lines == 0 then
        return
    end

    local heading = ElementalEditions.safe_localize("elem_override_heading", "Elemental")
    append_text_row(desc_nodes, heading .. ": " .. tostring(lines[1]), G.C.SECONDARY_SET.Enhanced or G.C.BLUE, 0.23)

    for index = 2, #lines do
        append_text_row(desc_nodes, tostring(lines[index]), G.C.WHITE, 0.21)
    end
end

local function append_counter_rows(card, desc_nodes)
    local counters = {}
    for _, counter_key in ipairs({ "blaze", "static", "growth", "rage", "splash", "armor" }) do
        local count = ElementalEditions.get_elemental_counter and ElementalEditions.get_elemental_counter(card, counter_key) or 0
        if count and count > 0 then
            counters[#counters + 1] = string.format("%s %d", ElementalEditions.safe_localize("elem_counter_" .. counter_key, counter_key), count)
        end
    end

    if #counters > 0 then
        append_text_row(desc_nodes, table.concat(counters, " | "), G.C.YELLOW, 0.24)
    end
end

local function append_flower_rows(desc_nodes)
    append_text_row(desc_nodes, ElementalEditions.safe_localize("elem_flower_channel_heading", "Flower Cards"), G.C.GREEN, 0.27)
    append_localized_row(desc_nodes, "elem_flower_channel_desc_1", "Count as Grass battle cards for Elemental Editions.", G.C.WHITE, 0.22)
    append_localized_row(desc_nodes, "elem_flower_channel_desc_2", "They can cause Sleep, healing, Growth, and Grass-type synergies.", G.C.WHITE, 0.22)
end

local function append_status_rows(card, desc_nodes)
    if not (card and desc_nodes and ElementalEditions.is_pokermon_joker(card)) then
        return
    end

    local hp = ElementalEditions.init_pokemon_hp(card)
    if not hp then
        return
    end

    local hp_text = string.format("%s %d/%d", ElementalEditions.safe_localize("elem_hp", "HP"), hp.current or 0, hp.max or 0)
    if hp.knocked_out then
        hp_text = hp_text .. " - " .. ElementalEditions.safe_localize("elem_knocked_out", "Knocked Out")
    end

    append_text_row(desc_nodes, hp_text, hp.knocked_out and G.C.RED or G.C.FILTER, 0.30)
    append_localized_row(desc_nodes, "elem_hp_tooltip", "HP: Elemental cards can damage Pokemon Jokers. At 0 HP, they are Knocked Out until they recover.", G.C.WHITE, 0.22)
    append_localized_row(desc_nodes, "elem_elemental_damage_tooltip", "Elemental Damage: Scored elemental cards damage Pokemon Jokers. Discarded elemental cards may apply weaker pressure.", G.C.WHITE, 0.22)
    append_localized_row(desc_nodes, "elem_type_effectiveness_tooltip", "Type Effectiveness: Super effective hits deal more HP damage. Matching types usually resist their own element.", G.C.WHITE, 0.22)
    if hp.knocked_out then
        append_localized_row(desc_nodes, "elem_knocked_out_tooltip", "Knocked Out: This Pokemon has 0 HP and cannot use Elemental Editions battle effects until revived.", G.C.RED, 0.22)
    end

    local status = ElementalEditions.get_joker_status(card)
    if status then
        local status_text = string.format("%s (%d)", ElementalEditions.get_status_name(status.key), status.turns or 0)
        append_text_row(desc_nodes, status_text, G.C.ORANGE, 0.28)
        append_text_row(desc_nodes, localized_line("elem_status_" .. status.key .. "_desc_1"), G.C.WHITE, 0.22)
        append_text_row(desc_nodes, localized_line("elem_status_" .. status.key .. "_desc_2"), G.C.WHITE, 0.22)
    end

    append_override_rows(card, desc_nodes)
    append_counter_rows(card, desc_nodes)
end

function ElementalEditions.install_pokemon_center_wrappers()
    if ElementalEditions._pokemon_center_wrappers_installed or not (G and G.P_CENTERS) then
        return
    end

    ElementalEditions._pokemon_center_wrappers_installed = true

    for _, center in pairs(G.P_CENTERS) do
        local key = center and center.key or ""
        local is_pokemon_center = center and (center.stage or key:match("^j_poke_"))
        local is_flower_center = key == "m_poke_flower"

        if center and (is_pokemon_center or is_flower_center) and not center.elem_ui_wrapped then
            center.elem_ui_wrapped = true
            local previous_generate_ui = center.generate_ui
            center.generate_ui = function(self, info_queue, card, desc_nodes, specific_vars, full_UI_table)
                local result = nil
                if previous_generate_ui then
                    result = previous_generate_ui(self, info_queue, card, desc_nodes, specific_vars, full_UI_table)
                elseif SMODS and SMODS.Center and SMODS.Center.generate_ui then
                    result = SMODS.Center.generate_ui(self, info_queue, card, desc_nodes, specific_vars, full_UI_table)
                end

                if is_pokemon_center then
                    append_status_rows(card, desc_nodes)
                elseif is_flower_center then
                    append_flower_rows(desc_nodes)
                end

                return result
            end
        end
    end
end

function ElementalEditions.install_tooltip_wrapper()
    if ElementalEditions._tooltip_wrapper_installed then
        return
    end

    local original = Card.generate_UIBox_ability_table
    ElementalEditions._tooltip_wrapper_installed = true

    function Card:generate_UIBox_ability_table(...)
        ElementalEditions.install_pokemon_center_wrappers()
        return original(self, ...)
    end
end

return ElementalEditions
