local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local custom_edition_keys = { "fire", "water", "earth", "lightning", "singed" }

local function resolve_elemental_edition_candidate(candidate)
    if type(candidate) ~= "string" or candidate == "" then
        return nil
    end

    for _, element_key in ipairs(custom_edition_keys) do
        local center_key = ElementalEditions.get_edition_center_key(element_key)
        local namespaced_key = ElementalEditions.namespace .. "_" .. element_key
        if candidate == element_key
            or candidate == ("e_" .. element_key)
            or candidate == namespaced_key
            or candidate == ("e_" .. namespaced_key)
            or candidate == center_key then
            return center_key
        end
    end

    return nil
end

local function normalize_custom_edition_input(edition)
    if type(edition) == "string" then
        return resolve_elemental_edition_candidate(edition) or edition
    end

    if type(edition) ~= "table" then
        return edition
    end

    local truthy_count = 0
    local found_key = nil
    for key, value in pairs(edition) do
        if value then
            truthy_count = truthy_count + 1
            found_key = key
            if truthy_count > 1 then
                return edition
            end
        end
    end

    if truthy_count ~= 1 then
        return edition
    end

    return resolve_elemental_edition_candidate(found_key) or edition
end

local function can_create_scry_view()
    return G and G.deck and type(rawget(_G, "create_scry_cardarea")) == "function"
end

local function ensure_scry_view()
    if G and G.scry_view then
        return G.scry_view
    end

    if not can_create_scry_view() then
        return nil
    end

    local ok, area = pcall(create_scry_cardarea)
    if not ok or not area then
        ElementalEditions.log("Failed to instantiate deferred scry_view card area.")
        return nil
    end

    G.scry_view = area
    ElementalEditions.log("Instantiated deferred Pokermon scry_view card area.")
    return area
end

function ElementalEditions.recover_optional_cardareas()
    if not (G and G.GAME) then
        return false
    end

    local area = nil
    if G.load_scry_view then
        area = ensure_scry_view()
        if area and area.load then
            local ok = pcall(function()
                area:load(G.load_scry_view)
            end)
            if ok then
                if area.align_cards then
                    area:align_cards()
                end
                if area.hard_set_cards then
                    area:hard_set_cards()
                end
                G.load_scry_view = nil
                ElementalEditions.log("Recovered deferred scry_view load data.")
                return true
            end
        end
        return false
    end

    if (G.GAME.scry_amount or 0) > 0 and not G.scry_view then
        return not not ensure_scry_view()
    end

    return false
end

if Card and Card.set_edition and not ElementalEditions._set_edition_wrapper_installed then
    ElementalEditions._set_edition_wrapper_installed = true

    local base_set_edition = Card.set_edition
    function Card:set_edition(edition, immediate, silent)
        return base_set_edition(self, normalize_custom_edition_input(edition), immediate, silent)
    end
end

if Game and Game.start_run and not ElementalEditions._start_run_wrapper_installed then
    ElementalEditions._start_run_wrapper_installed = true

    local base_start_run = Game.start_run
    function Game:start_run(args)
        local result = base_start_run(self, args)
        if ElementalEditions.available and ElementalEditions.recover_optional_cardareas then
            pcall(ElementalEditions.recover_optional_cardareas)
        end
        return result
    end
end

return ElementalEditions
