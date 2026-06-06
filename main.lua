local mod = SMODS.current_mod
local nfs = SMODS.NFS

local ElementalEditions = rawget(_G, "ElementalEditions") or {}
_G.ElementalEditions = ElementalEditions

ElementalEditions.mod = mod
ElementalEditions.nfs = nfs
ElementalEditions.default_config = assert(SMODS.load_file("config.lua"))()
ElementalEditions.namespace = "elem"

local function clone_value(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = clone_value(child)
    end
    return copy
end

local function merge_tables(base, override)
    local merged = clone_value(base or {})
    for key, value in pairs(override or {}) do
        if type(value) == "table" and type(merged[key]) == "table" then
            merged[key] = merge_tables(merged[key], value)
        else
            merged[key] = clone_value(value)
        end
    end
    return merged
end

function ElementalEditions.get_config()
    local runtime = (ElementalEditions.mod and ElementalEditions.mod.config) or {}
    return merge_tables(ElementalEditions.default_config or {}, runtime)
end

function ElementalEditions.copy_value(value)
    return clone_value(value)
end

function ElementalEditions.get_section(section)
    return ElementalEditions.get_config()[section] or {}
end

function ElementalEditions.get_shop_config()
    return ElementalEditions.get_section("shop")
end

function ElementalEditions.get_dev_config()
    return ElementalEditions.get_section("dev")
end

function ElementalEditions.is_enabled(key)
    return ElementalEditions.get_section("editions")[key] ~= false
end

function ElementalEditions.get_edition_center_key(key)
    if type(key) ~= "string" or key == "" then
        return nil
    end

    local namespaced_key = ElementalEditions.namespace .. "_" .. key
    local candidates = {
        key,
        "e_" .. key,
        namespaced_key,
        "e_" .. namespaced_key,
    }

    if G and type(G.P_CENTERS) == "table" then
        for _, candidate in ipairs(candidates) do
            if G.P_CENTERS[candidate] then
                return candidate
            end
        end
    end

    return "e_" .. namespaced_key
end

function ElementalEditions.ensure_ability(card)
    if not card then
        return nil
    end

    card.ability = card.ability or {}
    return card.ability
end

function ElementalEditions.ensure_extra(card)
    local ability = ElementalEditions.ensure_ability(card)
    if not ability then
        return nil
    end

    if type(ability.extra) ~= "table" then
        ability.extra = {}
    end
    return ability.extra
end

function ElementalEditions.ensure_table(parent, key)
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end
    return parent[key]
end

function ElementalEditions.ensure_number(card, key, default)
    local ability = ElementalEditions.ensure_ability(card)
    if not ability then
        return default
    end

    if type(ability[key]) ~= "number" then
        ability[key] = default
    end

    return ability[key]
end

function ElementalEditions.add_number(card, key, amount, default)
    local current = ElementalEditions.ensure_number(card, key, default or 0)
    local updated = current + (amount or 0)
    card.ability[key] = updated
    return updated
end

function ElementalEditions.card_has_edition(card, key)
    if not (card and card.edition and key) then
        return false
    end

    local edition = card.edition
    local center_key = ElementalEditions.get_edition_center_key(key)
    local legacy_center_key = "e_" .. key
    local namespaced_key = ElementalEditions.namespace .. "_" .. key

    return edition.type == key
        or edition.key == key
        or edition[key] == true
        or edition.type == legacy_center_key
        or edition.key == legacy_center_key
        or edition[legacy_center_key] == true
        or edition.type == center_key
        or edition.key == center_key
        or edition[center_key] == true
        or edition.type == namespaced_key
        or edition.key == namespaced_key
        or edition[namespaced_key] == true
end

function ElementalEditions.repair_legacy_card_edition(card)
    if not (card and card.edition and card.set_edition) then
        return false
    end

    local edition = card.edition
    for _, key in ipairs({ "fire", "water", "earth", "lightning", "singed" }) do
        local center_key = ElementalEditions.get_edition_center_key(key)
        local legacy_center_key = "e_" .. key
        local namespaced_key = ElementalEditions.namespace .. "_" .. key
        local current_key = edition.key or edition.type

        if center_key ~= legacy_center_key and (
            edition.type == key
            or edition.key == key
            or edition[key] == true
            or edition.type == legacy_center_key
            or edition.key == legacy_center_key
            or edition[legacy_center_key] == true
            or edition.type == namespaced_key
            or edition.key == namespaced_key
            or edition[namespaced_key] == true
        ) and current_key ~= center_key then
            return pcall(function()
                card:set_edition(center_key, true, true)
            end)
        end
    end

    return false
end

function ElementalEditions.repair_playing_card_editions()
    if not (G and type(G.playing_cards) == "table") then
        return 0
    end

    local repaired = 0
    for _, card in ipairs(G.playing_cards) do
        if ElementalEditions.repair_legacy_card_edition(card) then
            repaired = repaired + 1
        end
    end

    return repaired
end

function ElementalEditions.find_card_index(cards, target)
    if type(cards) ~= "table" or not target then
        return nil
    end

    for i = 1, #cards do
        if cards[i] == target then
            return i
        end
    end

    return nil
end

function ElementalEditions.remove_at(array, index)
    if type(array) ~= "table" or not index then
        return nil
    end

    local value = array[index]
    table.remove(array, index)
    return value
end

function ElementalEditions.safe_localize(key, fallback)
    if type(key) ~= "string" or not localize then
        return fallback or key
    end

    local ok, value = pcall(localize, key)
    if ok and type(value) == "string" and value ~= "" then
        return value
    end

    return fallback or key
end

function ElementalEditions.show_status_text(card, text, colour, options)
    if not (card and text and card_eval_status_text) then
        return
    end

    local extra = {
        message = text,
        colour = colour,
    }

    if type(options) == "table" then
        for key, value in pairs(options) do
            extra[key] = value
        end
    end

    return ElementalEditions.debug.safe_call("ui:show_status_text", function()
        card_eval_status_text(card, "extra", nil, nil, nil, extra)
    end, nil, options and options.context)
end

function ElementalEditions.show_status(card, message_key, colour, fallback, options)
    ElementalEditions.show_status_text(card, ElementalEditions.safe_localize(message_key, fallback), colour, options)
end

function ElementalEditions.element_label(element_key)
    return ElementalEditions.safe_localize("elem_" .. tostring(element_key), tostring(element_key))
end

function ElementalEditions.get_status_name(status_key)
    return ElementalEditions.safe_localize("elem_status_" .. tostring(status_key), tostring(status_key))
end

function ElementalEditions.get_runtime(card)
    local extra = ElementalEditions.ensure_extra(card)
    if not extra then
        return nil
    end

    return ElementalEditions.ensure_table(extra, "elem_runtime")
end

function ElementalEditions.get_hand_stamp(context)
    local ante = G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or 0
    local hands_played = G and G.GAME and G.GAME.current_round and G.GAME.current_round.hands_played or 0
    local scoring_name = context and context.scoring_name or "none"
    return table.concat({ tostring(ante), tostring(hands_played), tostring(scoring_name) }, ":")
end

function ElementalEditions.roll(seed_key, chance)
    if (chance or 0) <= 0 then
        return false
    end
    if chance >= 1 then
        return true
    end

    local value
    if pseudorandom and pseudoseed then
        value = pseudorandom(pseudoseed(seed_key))
    else
        value = math.random()
    end
    return value < chance
end

function ElementalEditions.pick_random(array, seed_key)
    if type(array) ~= "table" or #array == 0 then
        return nil, nil
    end

    if pseudorandom_element and pseudoseed then
        local picked = pseudorandom_element(array, pseudoseed(seed_key))
        return picked, ElementalEditions.find_card_index(array, picked)
    end

    return array[1], 1
end

function ElementalEditions.merge_calculate_results(base, addition)
    if type(addition) ~= "table" then
        return base
    end
    if type(base) ~= "table" then
        return clone_value(addition)
    end

    local merged = clone_value(base)
    for key, value in pairs(addition) do
        if type(value) == "number" and type(merged[key]) == "number" then
            merged[key] = merged[key] + value
        elseif value ~= nil then
            merged[key] = clone_value(value)
        end
    end
    return merged
end

function ElementalEditions.is_scoring_action_context(context)
    if type(context) ~= "table" then
        return false
    end

    if context.end_of_round or context.setting_blind or context.hand_drawn or context.other_drawn then
        return false
    end

    return context.before or context.after or context.joker_main or context.individual or context.repetition
end

function ElementalEditions.is_playing_card_edition_context(card, context)
    if not (card and context and G and context.cardarea == G.play) then
        return false
    end

    return context.edition == true or context.main_scoring == true
end

function ElementalEditions.is_pokermon_available()
    local mod_ref = SMODS and SMODS.Mods and SMODS.Mods["Pokermon"]
    if mod_ref and mod_ref.can_load ~= false then
        return true
    end

    return type(rawget(_G, "pokermon")) == "table"
end

local function load_module(path)
    return assert(SMODS.load_file(path), "Elemental Editions failed to load " .. path)()
end

function ElementalEditions.load_list_directory(dirname, mapper)
    local base_path = (ElementalEditions.mod and ElementalEditions.mod.path or "") .. dirname .. "/"
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

    for _, filename in ipairs(filenames) do
        local data = assert(SMODS.load_file(dirname .. "/" .. filename), "Elemental Editions failed to load " .. dirname .. "/" .. filename)()
        if data.init then
            data:init()
        end
        for _, item in ipairs(data.list or {}) do
            mapper(item)
        end
    end
end

load_module("functions/constants.lua")
load_module("functions/debug.lua")

if not ElementalEditions.is_pokermon_available() then
    ElementalEditions.available = false
    ElementalEditions.debug.warn("Pokermon was not detected; Elemental Editions is inactive.", "general")
    return
end

ElementalEditions.available = true

local module_paths = {
    "functions/pokermon_bridge.lua",
    "functions/element_channels.lua",
    "functions/feedback.lua",
    "functions/runtime_compat.lua",
    "functions/pokemon_hp.lua",
    "functions/joker_status.lua",
    "functions/pokemon_overrides.lua",
    "functions/pressure_damage.lua",
    "functions/card_creation.lua",
    "functions/battle_mode.lua",
    "functions/trainer_battles.lua",
    "functions/boss_hooks.lua",
    "functions/run_hooks.lua",
    "functions/ui_status.lua",
    "functions/challenge_framework.lua",
    "enhancements/battle_status_cards.lua",
    "editions/fire.lua",
    "editions/water.lua",
    "editions/lightning.lua",
    "editions/earth.lua",
}

for _, path in ipairs(module_paths) do
    load_module(path)
end

if ElementalEditions.register_pokemon_overrides then
    ElementalEditions.register_pokemon_overrides()
end

ElementalEditions.load_list_directory("backs", SMODS.Back)
if ElementalEditions.load_challenge_defs and ElementalEditions.register_challenge_defs then
    ElementalEditions.load_challenge_defs()
    ElementalEditions.register_challenge_defs()
end

if ElementalEditions.install_joker_wrapper then
    ElementalEditions.install_joker_wrapper()
end

if ElementalEditions.install_tooltip_wrapper then
    ElementalEditions.install_tooltip_wrapper()
end

SMODS.current_mod.calculate = function(self, context)
    return ElementalEditions.handle_calculate and ElementalEditions.handle_calculate(context) or nil
end

SMODS.current_mod.set_debuff = function(card)
    return ElementalEditions.handle_set_debuff and ElementalEditions.handle_set_debuff(card) or false
end

ElementalEditions.debug.log("Loaded standalone Pokermon add-on runtime.", "general")
