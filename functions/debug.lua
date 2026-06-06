local ElementalEditions = assert(rawget(_G, "ElementalEditions"))

local debuglib = debug
local unpack_fn = table.unpack or unpack

local function pack(...)
    return { n = select("#", ...), ... }
end

local function debug_config()
    return ElementalEditions.get_section("debug")
end

local function performance_config()
    return ElementalEditions.get_section("performance")
end

local function read_flag(config, short_key, explicit_key, default)
    if config[explicit_key] ~= nil then
        return config[explicit_key]
    end
    if config[short_key] ~= nil then
        return config[short_key]
    end
    return default
end

local function legacy_debug_enabled()
    local dev = ElementalEditions.get_dev_config()
    return dev and dev.debug_logging == true
end

local function read_number(config, short_key, explicit_key, default)
    local value = read_flag(config, short_key, explicit_key, default)
    value = tonumber(value)
    if value == nil then
        return default
    end
    return value
end

local function read_context_flags(context)
    if type(context) ~= "table" then
        return "none"
    end

    local flags = {}
    for _, key in ipairs({
        "before",
        "after",
        "discard",
        "individual",
        "repetition",
        "joker_main",
        "edition",
        "main_scoring",
        "setting_blind",
        "end_of_round",
        "hand_drawn",
    }) do
        if context[key] then
            flags[#flags + 1] = key
        end
    end

    return #flags > 0 and table.concat(flags, ",") or "none"
end

local function get_blind_name()
    if not (G and G.GAME and G.GAME.blind) then
        return nil
    end
    return G.GAME.blind.loc_name or G.GAME.blind.name or nil
end

local function build_run_context(context)
    local ante = G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or nil
    local hands = G and G.GAME and G.GAME.current_round and G.GAME.current_round.hands_played or nil
    local discards = G and G.GAME and G.GAME.current_round and G.GAME.current_round.discards_used or nil
    local blind_name = get_blind_name()
    local scoring_name = type(context) == "table" and context.scoring_name or nil
    local trace_id = type(context) == "table" and context.elem_trace_id or nil

    local parts = {}
    if trace_id then
        parts[#parts + 1] = "trace=" .. tostring(trace_id)
    end
    if ante ~= nil then
        parts[#parts + 1] = "ante=" .. tostring(ante)
    end
    if hands ~= nil then
        parts[#parts + 1] = "hands=" .. tostring(hands)
    end
    if discards ~= nil then
        parts[#parts + 1] = "discards=" .. tostring(discards)
    end
    if blind_name then
        parts[#parts + 1] = "blind=" .. tostring(blind_name)
    end
    if scoring_name then
        parts[#parts + 1] = "hand=" .. tostring(scoring_name)
    end
    if type(context) == "table" then
        parts[#parts + 1] = "phase=" .. read_context_flags(context)
    end

    return #parts > 0 and table.concat(parts, " ") or nil
end

local function is_card_like(value)
    return type(value) == "table" and value.ability and value.config
end

local function shallow_card_summary(card)
    local edition = card and card.edition or nil
    local enhancement = card and card.config and card.config.center_key or nil
    local status = card and card.ability and card.ability.extra and card.ability.extra.elem_status or nil
    local hp = card and card.ability and card.ability.extra and card.ability.extra.elem_hp or nil
    local area = card and card.area and card.area.config and card.area.config.type or nil

    local summary = {
        key = card and card.config and card.config.center and card.config.center.key or nil,
        name = card and card.ability and card.ability.name or nil,
        area = area,
        edition = edition and (edition.key or edition.type or tostring(edition)) or nil,
        enhancement = enhancement,
        debuff = card and card.debuff or nil,
        sort_id = card and card.sort_id or nil,
    }

    if type(hp) == "table" then
        summary.hp = string.format("%s/%s", tostring(hp.current or "?"), tostring(hp.max or "?"))
        summary.ko = hp.knocked_out == true
    end
    if type(status) == "table" then
        summary.status = string.format("%s:%s", tostring(status.key), tostring(status.turns or "?"))
    end

    return summary
end

local function serialize_value(value, seen, depth)
    local value_type = type(value)
    if value_type == "nil" then
        return "nil"
    end
    if value_type == "number" or value_type == "boolean" then
        return tostring(value)
    end
    if value_type == "string" then
        return value
    end
    if value_type == "function" then
        return "<function>"
    end
    if value_type ~= "table" then
        return "<" .. value_type .. ">"
    end

    if value == _G then
        return "<_G>"
    end
    if G and value == G then
        return "<G>"
    end
    if seen[value] then
        return "<recursive>"
    end
    if depth <= 0 then
        return "<depth>"
    end

    seen[value] = true

    if is_card_like(value) then
        local card_summary = shallow_card_summary(value)
        seen[value] = nil
        return serialize_value(card_summary, seen, depth - 1)
    end

    local parts = {}
    local count = 0
    for key, child in pairs(value) do
        count = count + 1
        if count > 8 then
            parts[#parts + 1] = "..."
            break
        end
        parts[#parts + 1] = tostring(key) .. "=" .. serialize_value(child, seen, depth - 1)
    end
    seen[value] = nil
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function serialize_data(data)
    if data == nil then
        return nil
    end
    return serialize_value(data, {}, 3)
end

local function debug_file_name()
    return "ElementalEditions_debug.log"
end

local function append_to_debug_file(line)
    if not (love and love.filesystem and love.filesystem.append) then
        return false
    end

    local ok = pcall(function()
        love.filesystem.append(debug_file_name(), line .. "\n")
    end)
    return ok
end

local function emit_lovely(line)
    if type(sendDebugMessage) == "function" then
        return pcall(sendDebugMessage, line)
    end
    return false
end

local function category_enabled(category)
    local config = debug_config()
    if category == "performance" then
        local perf = performance_config()
        if read_flag(perf, "logging_enabled", "performance_logging_enabled", false) == true then
            return true
        end
    end

    if not (read_flag(config, "enabled", "debug_enabled", false) == true or legacy_debug_enabled()) then
        return false
    end

    local field_by_category = {
        scoring = { "scoring", "debug_scoring" },
        discard = { "discard", "debug_discard" },
        status = { "status", "debug_status" },
        editions = { "editions", "debug_editions" },
        challenges = { "challenges", "debug_challenges" },
        messages = { "messages", "debug_messages" },
        damage = { "damage", "debug_damage" },
        hp = { "status", "debug_status" },
        overrides = { "overrides", "debug_overrides" },
        performance = { "performance", "debug_performance" },
    }

    local field = field_by_category[category]
    if field and read_flag(config, field[1], field[2], true) == false then
        return false
    end
    return true
end

local function should_sample_trace(context)
    local config = debug_config()
    local sample_rate = math.max(1, math.floor(read_number(config, "sample_rate", "debug_sample_rate", 1) or 1))
    local every_n = math.max(1, math.floor(read_number(config, "trace_scoring_every_n", "debug_trace_scoring_every_n", 1) or 1))

    if sample_rate <= 1 and every_n <= 1 then
        return true
    end

    local trace_id = ElementalEditions.get_debug_trace_id and ElementalEditions.get_debug_trace_id(context, false) or nil
    if not trace_id then
        return true
    end

    if every_n > 1 and (trace_id % every_n) ~= 0 then
        return false
    end
    if sample_rate > 1 and (trace_id % sample_rate) ~= 0 then
        return false
    end

    return true
end

local function build_line(level, category, message, data, context)
    local parts = {
        "[ElementalEditions]",
        "[" .. tostring(level) .. "]",
        "[" .. tostring(category or "general") .. "]",
        tostring(message or ""),
    }

    local run_context = build_run_context(context)
    if run_context then
        parts[#parts + 1] = run_context
    end

    local serialized = serialize_data(data)
    if serialized and serialized ~= "" then
        parts[#parts + 1] = serialized
    end

    return table.concat(parts, " ")
end

local function log_line(level, category, message, data, context)
    if (level == "info" or level == "trace") and not category_enabled(category) then
        return
    end

    local config = debug_config()
    local line = build_line(level, category, message, data, context)

    print(line)

    if read_flag(config, "lovely_enabled", "debug_lovely_enabled", true) ~= false then
        emit_lovely(line)
    end
    if read_flag(config, "file_enabled", "debug_file_enabled", true) ~= false then
        append_to_debug_file(line)
    end
end

function ElementalEditions.get_debug_trace_id(context, force_new)
    ElementalEditions._debug_trace_counter = (ElementalEditions._debug_trace_counter or 0)

    if type(context) ~= "table" then
        if force_new then
            ElementalEditions._debug_trace_counter = ElementalEditions._debug_trace_counter + 1
            return ElementalEditions._debug_trace_counter
        end
        return nil
    end

    if force_new or context.elem_trace_id == nil then
        ElementalEditions._debug_trace_counter = ElementalEditions._debug_trace_counter + 1
        context.elem_trace_id = ElementalEditions._debug_trace_counter
    end

    return context.elem_trace_id
end

local debug_api = {}

function debug_api.log(message, category, data, context)
    log_line("info", category or "general", message, data, context)
end

function debug_api.warn(message, category, data, context)
    log_line("warn", category or "general", message, data, context)
end

function debug_api.error(message, category, data, context)
    log_line("error", category or "general", message, data, context)
end

function debug_api.trace(label, data, category, context)
    local config = debug_config()
    if read_flag(config, "verbose", "debug_verbose", false) ~= true and category ~= "error" then
        return
    end
    if not category_enabled(category or "general") then
        return
    end
    if not should_sample_trace(context) then
        return
    end
    log_line("trace", category or "general", label, data, context)
end

function debug_api.enabled(category)
    return category_enabled(category or "general")
end

function debug_api.safe_call(label, fn, fallback, ...)
    if type(fn) ~= "function" then
        return fallback
    end

    local args = pack(...)
    local context = nil
    for i = 1, args.n do
        if type(args[i]) == "table" and (
            args[i].scoring_name or
            args[i].setting_blind or
            args[i].after or
            args[i].discard or
            args[i].joker_main or
            args[i].edition
        ) then
            context = args[i]
            break
        end
    end

    local function runner()
        return fn(unpack_fn(args, 1, args.n))
    end

    local ok, result_a, result_b, result_c, result_d, result_e = xpcall(runner, function(err)
        local trace = debuglib and debuglib.traceback and debuglib.traceback(err, 2) or tostring(err)
        debug_api.error(label .. " failed", "error", { error = trace }, context)
        return trace
    end)

    if ok then
        return result_a, result_b, result_c, result_d, result_e
    end

    return fallback
end

function debug_api.wrap(label, fn, fallback)
    return function(...)
        return debug_api.safe_call(label, fn, fallback, ...)
    end
end

ElementalEditions.debug = debug_api

function ElementalEditions.is_debug_enabled(category)
    return category_enabled(category or "general")
end

function ElementalEditions.is_aoe_debug_enabled()
    return ElementalEditions.get_section("damage").debug_aoe_damage == true or ElementalEditions.is_debug_enabled("damage")
end

function ElementalEditions.log(...)
    if not ElementalEditions.is_debug_enabled("general") then
        return
    end

    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    debug_api.log(table.concat(parts, " "), "general")
end

function ElementalEditions.log_aoe(...)
    if not ElementalEditions.is_aoe_debug_enabled() then
        return
    end

    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    debug_api.log(table.concat(parts, " "), "damage")
end

function ElementalEditions.serialize_debug_data(data)
    return serialize_data(data)
end

local perf_api = {}

local function performance_logging_enabled()
    local perf = performance_config()
    if read_flag(perf, "logging_enabled", "performance_logging_enabled", false) == true then
        return true
    end
    return category_enabled("performance")
end

function perf_api.start(label, context)
    if not performance_logging_enabled() then
        return nil
    end

    local timer = love and love.timer and love.timer.getTime or os.clock
    if type(timer) ~= "function" then
        return nil
    end

    return {
        label = label,
        context = context,
        started_at = timer(),
        timer = timer,
    }
end

function perf_api.stop(token, data, context)
    if not (token and token.started_at and token.timer and performance_logging_enabled()) then
        return nil
    end

    local elapsed_ms = (token.timer() - token.started_at) * 1000
    local perf = performance_config()
    local threshold = read_number(perf, "log_threshold_ms", "performance_log_threshold_ms", 4) or 4
    if elapsed_ms < threshold then
        return elapsed_ms
    end

    debug_api.log("perf:" .. tostring(token.label), "performance", {
        elapsed_ms = string.format("%.2f", elapsed_ms),
        data = data,
    }, context or token.context)

    return elapsed_ms
end

ElementalEditions.perf = perf_api

return debug_api
