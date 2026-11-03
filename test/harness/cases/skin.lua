return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local Skin = Vermilion.Skin
  local paths = { Skin.CHROME, Skin.TAB_ON, Skin.RADIO_ON, Skin.RADIO_OFF, Skin.CARET, Skin.FRAME_EDGE }
  for _, set in ipairs({ Skin.PLAIN, Skin.LACQUER }) do
    for _, p in pairs(set) do paths[#paths + 1] = p end
  end
  local function le32(s, at)
    local a, b, c, d = s:byte(at, at + 3)
    return a + b * 256 + c * 65536 + d * 16777216
  end
  for _, p in ipairs(paths) do
    local rel = p:gsub("^Vermilion/", "")
    local f = io.open(HARNESS_ROOT .. "/" .. rel, "rb")
    ok(f ~= nil, "the skin ships " .. p)
    local head = f:read(128)
    f:close()
    ok(head:sub(1, 4) == "DDS ", p .. " is a dds")
    local h, w = le32(head, 13), le32(head, 17)
    ok(math.log(w, 2) % 1 == 0 and math.log(h, 2) % 1 == 0, p .. " has power of two sides")
    ok(head:sub(85, 88) == "DXT5", p .. " is DXT5")
  end
end
