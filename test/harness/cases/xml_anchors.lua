return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local manifest = assert(io.open(HARNESS_ROOT .. "/Vermilion.txt", "r"))
  local checked = 0
  for line in manifest:lines() do
    local rel = line:match("^%s*(%S+%.xml)")
    if rel then
      local f = assert(io.open(HARNESS_ROOT .. "/" .. rel:gsub(string.char(92), "/"), "r"))
      local src = f:read("*a"):gsub("<!%-%-.-%-%->", "")
      f:close()
      local declared = {}
      local at = 1
      while true do
        local s_name, e_name, name = src:find('name="%$%(parent%)([%w_]+)"', at)
        local s_ref, e_ref, ref = src:find('relativeTo="%$%(parent%)([%w_]+)"', at)
        if not s_name and not s_ref then break end
        if s_ref and (not s_name or s_ref < s_name) then
          ok(declared[ref], rel .. " anchors to " .. ref .. " before declaring it")
          checked = checked + 1
          at = e_ref + 1
        else
          declared[name] = true
          at = e_name + 1
        end
      end
    end
  end
  manifest:close()
  ok(checked > 0, "the lint found anchors to check")
end
