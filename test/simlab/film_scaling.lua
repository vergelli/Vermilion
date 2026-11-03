SIMLAB_ROOT   = arg[1] or "."
HARNESS_ROOT  = SIMLAB_ROOT
HARNESS_DEBUG = false

dofile(SIMLAB_ROOT .. "/test/harness/mock_eso.lua")
dofile(SIMLAB_ROOT .. "/test/harness/loader.lua")
HARNESS.fire(EVENT_ADD_ON_LOADED, "Vermilion")
Vermilion.Visibility.set("graph", true)

print(Vermilion.FilmTest.run({ 8, 20, 30, 45, 60, 120 }, function() return os.clock() * 1000 end))
