return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, Skin = Vermilion.Graph, Vermilion.Skin
  local top, bottom, left, right = VermilionGraphWindowChromeTop, VermilionGraphWindowChromeBottom, VermilionGraphWindowChromeLeft, VermilionGraphWindowChromeRight

  local xml = assert(io.open(HARNESS_ROOT .. "/ui/graph.xml")):read("*a")
  for _, name in ipairs({ "ChromeTop", "ChromeBottom", "ChromeLeft", "ChromeRight" }) do
    local body = xml:match('name="%$%(parent%)' .. name .. '".-</Texture>')
    ok(body:find('addressMode="WRAP"', 1, true), name .. " repeats the surface instead of stretching it")
    ok(body:find('autoAdjustTextureCoords="false"', 1, true), name .. " keeps its exact coordinates")
    ok(not body:find('offsetX="6"', 1, true) and not body:find('offsetX="-6"', 1, true), name .. " reaches the frame, no gap")
  end

  local function near(a, b) return math.abs(a - b) < 1e-6 end
  local function check(w, h)
    G.fit_chrome()
    local px = 512
    ok(near(top._uv[2] * px, w - 2), "the top strip takes one pixel of surface per pixel of window, got " .. top._uv[2] * px)
    ok(near(left._uv[3], top._uv[4]), "the sides start where the top ends, no jump")
    ok(near(right._uv[3], top._uv[4]), "both sides")
    ok(near(left._uv[4], bottom._uv[3]), "the bottom starts where the sides end")
    ok(near(right._uv[1] * px, w - 14), "the right side samples its own place")
    ok(near(bottom._uv[4] * px, h - 2), "the bottom reaches its place")
  end
  local w0, h0 = VermilionGraphWindow:GetDimensions()
  check(w0, h0)
  VermilionGraphWindow:SetDimensions(1000, 700)
  G.on_resize_stop()
  local w1, h1 = VermilionGraphWindow:GetDimensions()
  ok(w1 == 1000 and h1 == 700, "the window took the new size")
  check(w1, h1)
  ok(top._uv[2] > 1, "a window wider than the surface repeats it")
  VermilionGraphWindow:SetDimensions(w0, h0)
  G.on_resize_stop()

  ok(top._r == left._r and left._r == right._r and right._r == bottom._r, "the four strips share one tone")
  ok(top._vtop > top._r, "only the top strip has its light, and it fades out before the sides")
  ok(left._vtop == nil and right._vtop == nil and bottom._vtop == nil, "the others stay flat")
  ok(VermilionGraphWindowBg._draw_level == 2, "the frame draws over the surface, so its corners stay round")

  G.on_resize_start()
  ok(VermilionGraphWindow._onOnUpdate == G.fit_chrome, "the surface follows the window during the drag")
  VermilionGraphWindow:SetDimensions(800, 500)
  VermilionGraphWindow._onOnUpdate()
  ok(near(top._uv[2] * 512, 798), "one pixel of surface per pixel of window, also mid drag")
  G.on_resize_stop()
  ok(VermilionGraphWindow._onOnUpdate == nil, "and it stops following when the drag ends")
  VermilionGraphWindow:SetDimensions(w0, h0)
  G.on_resize_stop()
end
