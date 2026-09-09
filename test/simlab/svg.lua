local M = {}

local POINT_BY_NAME = {
  TOPLEFT = TOPLEFT, TOP = TOP, TOPRIGHT = TOPRIGHT,
  LEFT = LEFT, CENTER = CENTER, RIGHT = RIGHT,
  BOTTOMLEFT = BOTTOMLEFT, BOTTOM = BOTTOM, BOTTOMRIGHT = BOTTOMRIGHT,
}

local FRAC = {
  [TOPLEFT] = { 0, 0 }, [TOP] = { 0.5, 0 }, [TOPRIGHT] = { 1, 0 },
  [LEFT] = { 0, 0.5 }, [CENTER] = { 0.5, 0.5 }, [RIGHT] = { 1, 0.5 },
  [BOTTOMLEFT] = { 0, 1 }, [BOTTOM] = { 0.5, 1 }, [BOTTOMRIGHT] = { 1, 1 },
}

local CONTAINER_TAGS = {
  TopLevelControl = true, Control = true, Label = true,
  Texture = true, Backdrop = true, Button = true, Line = true,
}

local function parse_attrs(s)
  local a = {}
  for k, v in s:gmatch('([%w_]+)%s*=%s*"([^"]*)"') do a[k] = v end
  return a
end

function M.apply_xml(path)
  local f = io.open(path, "r")
  if not f then error("cannot open " .. path) end
  local xml = f:read("*a")
  f:close()
  xml = xml:gsub("<!%-%-.-%-%->", "")

  local stack = {}
  local function top() return stack[#stack] end

  for tag in xml:gmatch("<[^>]+>") do
    local closing = tag:match("^</%s*([%w_]+)")
    local self_closing = tag:match("/%s*>$") ~= nil
    local name = tag:match("^<%s*([%w_]+)")
    local attrs = parse_attrs(tag)

    if closing then
      if CONTAINER_TAGS[closing] and top() and top().tag == closing then
        stack[#stack] = nil
      end
    elseif CONTAINER_TAGS[name] then
      local parent = top()
      local ctrl = nil
      if attrs.virtual ~= "true" and attrs.name then
        local full = attrs.name:gsub("%$%(parent%)", parent and parent.full or "")
        ctrl = _G[full]
        if not ctrl then
          ctrl = HARNESS.mock_control(full)
          rawset(_G, full, ctrl)
        end
        ctrl._parent = parent and parent.ctrl or GuiRoot
        ctrl._xml_tag = name
        if attrs.hidden == "true" then ctrl._hidden = true end
        if attrs.textureFile then ctrl._tex = attrs.textureFile end
        if attrs.font then ctrl._font = attrs.font end
        if attrs.horizontalAlignment then ctrl._halign = attrs.horizontalAlignment end
        if attrs.verticalAlignment then ctrl._valign = attrs.verticalAlignment end
        if not self_closing then
          stack[#stack + 1] = { tag = name, full = full, ctrl = ctrl }
        end
      elseif not self_closing then
        stack[#stack + 1] = { tag = name, full = parent and parent.full or "", ctrl = parent and parent.ctrl }
      end
    elseif name == "Anchor" and top() and top().ctrl then
      local c = top().ctrl
      local rel = top().ctrl._parent
      if attrs.relativeTo then
        local rn = attrs.relativeTo:gsub("%$%(parent%)",
          (c._parent and c._parent._name) or "")
        rel = _G[rn] or rel
      end
      c._anchor_list = c._anchor_list or {}
      c._anchor_list[#c._anchor_list + 1] = {
        point = POINT_BY_NAME[attrs.point] or TOPLEFT,
        relTo = rel,
        relPoint = POINT_BY_NAME[attrs.relativePoint or attrs.point] or TOPLEFT,
        ox = tonumber(attrs.offsetX) or 0,
        oy = tonumber(attrs.offsetY) or 0,
      }
      c._anchors = #c._anchor_list
    elseif name == "AnchorFill" and top() and top().ctrl then
      top().ctrl._fill = top().ctrl._parent
      top().ctrl._anchors = 2
    elseif name == "Dimensions" and top() and top().ctrl then
      if attrs.x then top().ctrl._w = tonumber(attrs.x) end
      if attrs.y then top().ctrl._h = tonumber(attrs.y) end
    elseif name == "Center" and top() and top().ctrl then
      top().ctrl._center_file = attrs.file
    elseif name == "Edge" and top() and top().ctrl then
      top().ctrl._edge_file = attrs.file
    elseif name == "Textures" and top() and top().ctrl then
      if attrs.normal then top().ctrl._tex = attrs.normal end
    end
  end
end

local function esc(s)
  return tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

local function rich(s)
  local out = {}
  local pos = 1
  local open = false
  s = tostring(s):gsub("|t.-|t", "")
  while true do
    local a, b, hex = s:find("|c(%x%x%x%x%x%x)", pos)
    local ra, rb = s:find("|r", pos, true)
    if not a and not ra then break end
    if a and (not ra or a < ra) then
      out[#out + 1] = esc(s:sub(pos, a - 1))
      if open then out[#out + 1] = "</tspan>" end
      out[#out + 1] = '<tspan fill="#' .. hex .. '">'
      open = true
      pos = b + 1
    else
      out[#out + 1] = esc(s:sub(pos, ra - 1))
      if open then out[#out + 1] = "</tspan>" end
      open = false
      pos = rb + 1
    end
  end
  out[#out + 1] = esc(s:sub(pos))
  if open then out[#out + 1] = "</tspan>" end
  return table.concat(out)
end

local function col(r, g, b)
  return string.format("rgb(%d,%d,%d)",
    math.floor((r or 1) * 255), math.floor((g or 1) * 255), math.floor((b or 1) * 255))
end

local function font_px(f)
  if not f then return 12 end
  local n = tostring(f):match("|(%d+)")
  if n then return tonumber(n) end
  if tostring(f):find("Small") then return 12 end
  return 14
end

local function is_label(c)
  return c._ctype == CT_LABEL or c._xml_tag == "Label"
      or (c._text ~= nil and c._ctype ~= CT_TEXTURE and c._xml_tag ~= "Texture")
end

local function is_backdrop(c)
  return c._ctype == CT_BACKDROP or c._xml_tag == "Backdrop"
end

local function is_cooldown(c)
  return c._ctype == CT_COOLDOWN
end

local function arc_path(cx, cy, R, r, a0, sweep)
  local function pt(rad, ang) return cx + rad * math.cos(ang), cy + rad * math.sin(ang) end
  if sweep >= 2 * math.pi - 1e-6 then
    return string.format(
      "M %.1f %.1f A %.1f %.1f 0 1 1 %.1f %.1f A %.1f %.1f 0 1 1 %.1f %.1f Z M %.1f %.1f A %.1f %.1f 0 1 0 %.1f %.1f A %.1f %.1f 0 1 0 %.1f %.1f Z",
      cx + R, cy, R, R, cx - R, cy, R, R, cx + R, cy,
      cx + r, cy, r, r, cx - r, cy, r, r, cx + r, cy)
  end
  local large = (sweep > math.pi) and 1 or 0
  local x0, y0 = pt(R, a0)
  local x1, y1 = pt(R, a0 + sweep)
  local x2, y2 = pt(r, a0 + sweep)
  local x3, y3 = pt(r, a0)
  return string.format(
    "M %.1f %.1f A %.1f %.1f 0 %d 1 %.1f %.1f L %.1f %.1f A %.1f %.1f 0 %d 0 %.1f %.1f Z",
    x0, y0, R, R, large, x1, y1, x2, y2, r, r, large, x3, y3)
end

local function is_texture(c)
  return c._ctype == CT_TEXTURE or c._xml_tag == "Texture"
      or c._xml_tag == "Button" or c._tex ~= nil
      or (c._r ~= nil and not is_label(c))
end

function M.snapshot(H, root, out_path)
  local kids = {}
  for _, c in ipairs(H.controls) do
    local p = c._parent
    if p then
      kids[p] = kids[p] or {}
      kids[p][#kids[p] + 1] = c
    end
  end

  local flat = {}
  local function walk(c)
    if c._hidden then return end
    flat[#flat + 1] = c
    local ch = kids[c]
    if ch then
      for _, k in ipairs(ch) do walk(k) end
    end
  end
  walk(root)

  local order = {}
  for i, c in ipairs(flat) do order[c] = i end
  table.sort(flat, function(a, b)
    local ta, tb = a._draw_tier or 0, b._draw_tier or 0
    if ta ~= tb then return ta < tb end
    local la, lb = a._draw_layer or 0, b._draw_layer or 0
    if la ~= lb then return la < lb end
    local va, vb = a._draw_level or 0, b._draw_level or 0
    if va ~= vb then return va < vb end
    return order[a] < order[b]
  end)

  local rr = H.layout(root)
  local pad = 20
  local out = {}
  out[#out + 1] = string.format(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="%d %d %d %d" font-family="Segoe UI, sans-serif">',
    math.floor(rr.x - pad), math.floor(rr.y - pad),
    math.floor(rr.w + 2 * pad), math.floor(rr.h + 2 * pad))
  out[#out + 1] = string.format(
    '<rect x="%d" y="%d" width="%d" height="%d" fill="#101010"/>',
    math.floor(rr.x - pad), math.floor(rr.y - pad),
    math.floor(rr.w + 2 * pad), math.floor(rr.h + 2 * pad))

  for _, c in ipairs(flat) do
    local r = H.layout(c)
    local alpha = c._alpha or 1
    if r.w > 0 and r.h > 0 and alpha > 0 then
      local name = esc(c._name or "?")
      if is_backdrop(c) then
        local fill, fop
        if c._cr and c._center_file then
          fill, fop = col(c._cr * 0.22, c._cg * 0.22, c._cb * 0.22), math.min(1, (c._ca or 1) * alpha + 0.85)
        elseif c._cr then
          fill, fop = col(c._cr, c._cg, c._cb), (c._ca or 1) * alpha
        elseif c._center_file then
          fill, fop = "#2b2622", 0.95 * alpha
        else
          fill, fop = "none", 0
        end
        out[#out + 1] = string.format(
          '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" fill-opacity="%.2f" stroke="#6a5f4d" stroke-opacity="%.2f"><title>%s</title></rect>',
          r.x, r.y, r.w, r.h, fill, fop, 0.8 * alpha, name)
      elseif is_label(c) then
        local txt = c._text
        if txt and txt ~= "" then
          local px = font_px(c._font)
          local ha = c._halign
          local anchor, tx = "start", r.x
          if ha == TEXT_ALIGN_CENTER or ha == "CENTER" then anchor, tx = "middle", r.x + r.w / 2
          elseif ha == TEXT_ALIGN_RIGHT or ha == "RIGHT" then anchor, tx = "end", r.x + r.w end
          out[#out + 1] = string.format(
            '<text x="%.1f" y="%.1f" font-size="%d" data-w="%.0f" data-lines="%d" fill="%s" fill-opacity="%.2f" text-anchor="%s" dominant-baseline="middle"><title>%s</title>%s</text>',
            tx, r.y + r.h / 2, px, r.w, c._max_lines or 0, col(c._r, c._g, c._b), (c._a or 1) * alpha, anchor, name, rich(txt))
        end
      elseif is_cooldown(c) then
        local pct = c._cd_pct or 0
        if pct > 0 then
          local origin = c._cd_origin or 0
          if origin > 2 * math.pi + 1e-6 then origin = origin / 360 * 2 * math.pi end
          local R = math.min(r.w, r.h) / 2
          local a0 = -math.pi / 2 + origin
          if c._cd_cw == false then a0 = -math.pi / 2 - origin end
          local sweep = math.min(1, pct) * 2 * math.pi
          out[#out + 1] = string.format(
            '<path d="%s" fill="%s" fill-opacity="%.2f" data-pct="%.3f"><title>%s</title></path>',
            arc_path(r.x + r.w / 2, r.y + r.h / 2, R, R * 0.645, a0, sweep),
            col(c._fr, c._fg, c._fb), (c._fa or 1) * alpha, pct, name)
        end
      elseif is_texture(c) then
        local fill, fop
        if c._r ~= nil then
          fill, fop = col(c._r, c._g, c._b), (c._a or 1) * alpha
        elseif c._tex then
          fill, fop = "#8a8a8a", 0.35 * alpha
        else
          fill, fop = "#666666", 0.25 * alpha
        end
        local title = name .. (c._tex and ("  [" .. esc(c._tex) .. "]") or "")
        out[#out + 1] = string.format(
          '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" fill-opacity="%.2f"><title>%s</title></rect>',
          r.x, r.y, r.w, r.h, fill, fop, title)
      end
    end
  end

  out[#out + 1] = "</svg>"

  local dir = out_path:match("^(.*)[/\\][^/\\]+$")
  if dir then
    if package.config:sub(1, 1) == "\\" then
      os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" 2>nul')
    else
      os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
    end
  end
  local f = assert(io.open(out_path, "w"))
  f:write(table.concat(out, "\n"))
  f:close()
  return out_path
end

return M
