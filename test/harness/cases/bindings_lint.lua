return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  local function slurp(path)
    local f = io.open(path, "r")
    ok(f ~= nil, "cannot open " .. path)
    local s = f:read("*a")
    f:close()
    return s
  end

  local function keys_sorted(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
    return out
  end

  local bindings = slurp(HARNESS_ROOT .. "/bindings.xml")
  local locale = slurp(HARNESS_ROOT .. "/locales/default.lua")

  local actions, handlers = {}, {}
  for block in bindings:gmatch('<Action name="[A-Z_]+".-</Action>') do
    local name = block:match('<Action name="([A-Z_]+)"')
    local down = block:match("<Down>(.-)</Down>")
    actions[name] = true
    handlers[name] = down
  end

  local named = {}
  for name in locale:gmatch('SI_BINDING_NAME_([A-Z_]+)') do named[name] = true end

  local missing_action, missing_name, missing_handler = {}, {}, {}
  for name in pairs(named) do
    if not actions[name] then missing_action[#missing_action + 1] = name end
  end
  for name in pairs(actions) do
    if not named[name] then missing_name[#missing_name + 1] = name end
    if not (handlers[name] and handlers[name]:find("^Vermilion%.")) then missing_handler[#missing_handler + 1] = name end
  end
  table.sort(missing_action)
  table.sort(missing_name)
  table.sort(missing_handler)

  ok(#missing_action == 0, "every keybind with a display name needs a live Action in bindings.xml, missing: " .. table.concat(missing_action, ", "))
  ok(#missing_name == 0, "every Action in bindings.xml needs a SI_BINDING_NAME_ string so it shows a label, missing: " .. table.concat(missing_name, ", "))
  ok(#missing_handler == 0, "every Action needs a Vermilion.* handler in its Down block, missing: " .. table.concat(missing_handler, ", "))
end
