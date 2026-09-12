local Prng = {}
Prng.__index = Prng

function Prng.new(seed)
  return setmetatable({ s = (seed or 1) % 4294967296 }, Prng)
end

function Prng:next()
  self.s = (self.s * 1664525 + 1013904223) % 4294967296
  return self.s / 4294967296
end

function Prng:range(a, b)
  return a + math.floor(self:next() * (b - a + 1))
end

function Prng:jitter(base, pct)
  return base * (1 + (self:next() * 2 - 1) * pct)
end

function Prng:chance(p)
  return self:next() < p
end

return Prng
