return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local V = Vermilion.lib.vsf

  local GOLDEN_DESC = {
    { name = "t", width = 2, delta = true },
    { name = "v", width = 3, scale = 10 },
  }
  local golden = V.pack({
    { t = 0, v = 1.5 }, { t = 1000, v = 2.7 }, { t = 2500, v = 0 },
  }, GOLDEN_DESC)
  ok(table.concat(golden.data) == "0000FFe00RNS000",
     "golden blob drifted: " .. table.concat(golden.data))
  ok(golden.chk == "Rpq2", "golden checksum drifted: " .. golden.chk)
  ok(golden.rlen == 5 and golden.n == 3, "golden shape drifted")

  local frozen = { n = 3, rlen = 5, chk = "Rpq2", data = { "0000FFe00RNS000" } }
  local back, err = V.unpack(frozen, GOLDEN_DESC)
  ok(back, "frozen v1 file must always decode: " .. tostring(err))
  ok(back[1].t == 0 and back[2].t == 1000 and back[3].t == 2500, "frozen timestamps wrong")
  ok(back[2].v == 2.7, "frozen scaled value wrong: " .. tostring(back[2].v))

  local Prng = dofile(HARNESS_ROOT .. "/test/simlab/prng.lua")
  local rng = Prng.new(20260822)
  local DESC = {
    { name = "t",   width = 2, delta = true },
    { name = "a",   width = 3 },
    { name = "b",   width = 3 },
    { name = "rho", width = 2, scale = 1000 },
  }
  local recs = {}
  local t = 0
  for i = 1, 500 do
    t = t + rng:range(0, 3000)
    recs[i] = {
      t = t,
      a = rng:range(0, 260000),
      b = rng:range(0, 100),
      rho = rng:range(0, 1000) / 1000,
    }
  end
  local stream = V.pack(recs, DESC)
  ok(#stream.data >= 3, "500 records must span several chunks")
  for i, c in ipairs(stream.data) do
    ok(#c <= 1800, "chunk " .. i .. " exceeds savedvars limit: " .. #c)
  end
  local out, uerr = V.unpack(stream, DESC)
  ok(out, "roundtrip failed: " .. tostring(uerr))
  for i = 1, 500 do
    ok(out[i].t == recs[i].t, "t mismatch at " .. i)
    ok(out[i].a == recs[i].a, "a mismatch at " .. i)
    ok(out[i].b == recs[i].b, "b mismatch at " .. i)
    ok(math.abs(out[i].rho - recs[i].rho) < 1e-9, "rho mismatch at " .. i)
  end

  local sat = V.pack({ { t = 0, a = 99999999, b = -5, rho = 9.9 } }, DESC)
  local sout = V.unpack(sat, DESC)
  ok(sout[1].a == 262143, "overflow must saturate at field max, got " .. sout[1].a)
  ok(sout[1].b == 0, "negative must clamp to zero")
  ok(sout[1].rho == 4.095, "scaled overflow must saturate, got " .. tostring(sout[1].rho))

  local corrupt = { n = stream.n, rlen = stream.rlen, chk = stream.chk,
                    data = { (stream.data[1]:gsub("^.", "9")), stream.data[2], stream.data[3] } }
  if table.concat(corrupt.data) ~= table.concat(stream.data) then
    local r, e = V.unpack(corrupt, DESC)
    ok(r == nil and e:find("checksum"), "corruption must fail the checksum, got " .. tostring(e))
  end

  local trunc = { n = stream.n, rlen = stream.rlen, chk = stream.chk,
                  data = { stream.data[1] } }
  local r2, e2 = V.unpack(trunc, DESC)
  ok(r2 == nil and e2:find("length"), "truncation must fail the length check")

  local r3, e3 = V.unpack({ n = 1, rlen = 4, data = {}, chk = "0000" }, DESC)
  ok(r3 == nil and e3:find("rlen"), "descriptor drift must be rejected")

  local r4, e4 = V.unpack("garbage", DESC)
  ok(r4 == nil and e4:find("malformed"), "garbage container must be rejected cleanly")
end
