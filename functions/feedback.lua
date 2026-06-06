local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local function message_config()
    return ElementalEditions.get_section("messages")
end

local function gameplay_config()
    return ElementalEditions.get_section("gameplay")
end

local function message_state(context)
    ElementalEditions._message_runtime = ElementalEditions._message_runtime or {}
    local trace_id = type(context) == "table" and context.elem_trace_id or "global"
    local stamp = ElementalEditions.get_hand_stamp(context)
    local key = tostring(trace_id) .. ":" .. tostring(stamp)
    local runtime = ElementalEditions._message_runtime

    if runtime.key ~= key then
        runtime.key = key
        runtime.count = 0
    end

    return runtime
end

local function can_emit_message(context)
    local limit = message_config().max_messages_per_scoring_event or 4
    if not limit or limit <= 0 then
        return true
    end

    local runtime = message_state(context)
    if runtime.count >= limit then
        return false
    end

    runtime.count = runtime.count + 1
    return true
end

local function pick_flavor(element_key, context)
    local flavors = (message_config().flavor or {})[element_key] or {}
    local picked = ElementalEditions.pick_random(flavors, "elem_flavor:" .. tostring(element_key) .. ":" .. ElementalEditions.get_hand_stamp(context))
    return picked or (ElementalEditions.element_label(element_key) .. " hit!")
end

local function summary_anchor(source_card, targets)
    if source_card then
        return source_card
    end
    if type(targets) == "table" then
        return targets[1] or nil
    end
    return nil
end

local function is_message_enabled()
    return gameplay_config().enable_damage_messages ~= false
end

function ElementalEditions.get_message_delay(kind)
    local config = message_config()
    local multiplier = config.message_duration_multiplier or 1
    local base = config.summary_message_duration or 1.35

    if kind == "damage" then
        base = config.damage_message_duration or 0.80
    elseif kind == "status" then
        base = config.status_message_duration or 1.05
    elseif kind == "summary" then
        base = config.summary_message_duration or 1.35
    end

    return base * multiplier
end

function ElementalEditions.should_show_individual_damage(target_count)
    if not is_message_enabled() then
        return false
    end

    if message_config().aggregate_aoe_damage_messages ~= false and target_count > 1 then
        return false
    end

    local verbosity = gameplay_config().message_verbosity or "normal"
    local limit = message_config().show_individual_damage_up_to or 2
    if verbosity == "high" then
        return true
    end
    if verbosity == "low" then
        return target_count <= 1
    end
    return target_count <= limit
end

function ElementalEditions.show_damage_message(target_card, amount, element_key, context, effectiveness)
    if not (is_message_enabled() and target_card and amount and amount > 0) then
        return
    end
    if not can_emit_message(context) then
        return
    end

    ElementalEditions.debug.trace("damage_message", {
        amount = amount,
        element = element_key,
        effectiveness = effectiveness,
        target = target_card,
    }, "messages", context)

    ElementalEditions.show_status_text(target_card, "-" .. tostring(amount) .. " HP", G.C.RED, {
        delay = ElementalEditions.get_message_delay("damage"),
        context = context,
    })

    if gameplay_config().message_verbosity == "high" and effectiveness then
        local message_key = ElementalEditions.format_effectiveness_message(effectiveness)
        if message_key then
            local colour = effectiveness <= 0 and G.C.GREY or effectiveness > 1 and G.C.RED or G.C.BLUE
            ElementalEditions.show_status(target_card, message_key, colour, message_key, {
                delay = ElementalEditions.get_message_delay("status"),
                context = context,
            })
        end
    end
end

function ElementalEditions.show_effectiveness_summary(element_key, summary, source_card, targets, context)
    if not (is_message_enabled() and message_config().show_effectiveness_summary ~= false) then
        return
    end

    local anchor = summary_anchor(source_card, targets)
    if not anchor or type(summary) ~= "table" then
        return
    end

    if (summary.no_effect or 0) > 0 then
        if not can_emit_message(context) then
            return
        end
        ElementalEditions.show_status(anchor, "elem_no_effect", G.C.GREY, "No effect!", {
            delay = ElementalEditions.get_message_delay("summary"),
            context = context,
        })
        return
    end
    if (summary.super_effective or 0) > 0 then
        if not can_emit_message(context) then
            return
        end
        ElementalEditions.show_status(anchor, "elem_super_effective", G.C.RED, "Super effective!", {
            delay = ElementalEditions.get_message_delay("summary"),
            context = context,
        })
        return
    end
    if (summary.resisted or 0) > 0 and (summary.damage or 0) > 0 then
        if not can_emit_message(context) then
            return
        end
        ElementalEditions.show_status(anchor, "elem_resisted", G.C.BLUE, "Resisted!", {
            delay = ElementalEditions.get_message_delay("summary"),
            context = context,
        })
    end
end

function ElementalEditions.show_aoe_damage_summary(element_key, totals, source_card, targets, context, source_kind)
    if not is_message_enabled() then
        return
    end

    local anchor = summary_anchor(source_card, targets)
    if not anchor then
        return
    end

    local target_count = type(targets) == "table" and #targets or tonumber(targets) or totals and totals.target_count or 0
    local total_damage = totals and totals.damage or 0
    if target_count <= 0 or total_damage <= 0 then
        return
    end
    if target_count < (message_config().aoe_summary_threshold or 2) and ElementalEditions.should_show_individual_damage(target_count) then
        return
    end

    local verbosity = gameplay_config().message_verbosity or "normal"
    local flavor = pick_flavor(element_key, context)
    local message = flavor

    if verbosity ~= "low" then
        if source_kind == "discard" then
            message = string.format("%s -%d HP to %d", flavor, total_damage, target_count)
        else
            message = string.format("%s %d Pokemon, -%d HP", flavor, target_count, total_damage)
        end
    end

    ElementalEditions.debug.trace("aoe_summary", {
        element = element_key,
        message = message,
        target_count = target_count,
        total_damage = total_damage,
        source_kind = source_kind,
    }, "messages", context)

    if not can_emit_message(context) then
        return
    end

    ElementalEditions.show_status_text(anchor, message, G.C.ORANGE, {
        delay = ElementalEditions.get_message_delay("summary"),
        context = context,
    })
end

function ElementalEditions.show_ability_trigger_message(pokemon_card, message, colour, context)
    if not (is_message_enabled() and pokemon_card and message) then
        return
    end
    if not can_emit_message(context) then
        return
    end
    ElementalEditions.show_status_text(pokemon_card, message, colour or G.C.YELLOW, {
        delay = ElementalEditions.get_message_delay("status"),
        context = context,
    })
end

return ElementalEditions
