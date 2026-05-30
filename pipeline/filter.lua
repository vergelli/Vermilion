-- pipeline/filter.lua
--
-- Stage 2 of the pipeline. Pure predicate over a populated VermilionEvent.
-- Returns true to allow the event through, false to drop.
--
-- ── Hostility (SPEC §15.4 / §15.7) — VALIDATED, SPEC §8.2 OVERRIDDEN ───────
-- SPEC §8.2 proposed a target-hostility predicate ("target_type must not be
-- COMBAT_UNIT_TYPE_PLAYER or COMBAT_UNIT_TYPE_GROUP"). Validation against the
-- ZOS source (esoui/ingame/combatlogs/targetdummylog.lua) shows that is WRONG:
--   • ZOS's own outgoing-damage aggregator does NO target-hostility filtering.
--     It attributes purely by sourceType == PLAYER and hitValue > 0.
--   • In PvP an enemy player's target_type IS COMBAT_UNIT_TYPE_PLAYER, so the
--     proposed predicate would drop ALL PvP damage — a stated in-scope case
--     (SPEC §2.3). This is exactly the §15.7 failure mode.
-- Correct model: a player-sourced DAMAGE / DAMAGE_SHIELDED event inherently
-- targets something the player is attacking. We therefore rely on:
--   • source = PLAYER  (enforced by REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE), and
--   • result code      (enforced at the subscription dispatcher in pipeline.lua),
-- and do NOT gate on target_type. target_type is still captured on the event
-- for the future per-target view, but it is not a filter input.
--
-- No ShieldRegistry check (dropped) and no GroupSet check (dropped): both were
-- Verdant healer-domain predicates with no Vermilion analog.

Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Pipeline = Vermilion.Pipeline or {}
Vermilion.Pipeline.Filter = {}
local M = Vermilion.Pipeline.Filter

-- Both kinds pass: amount > 0 is enforced in acquisition, source/result are
-- enforced upstream. The stage is retained as an explicit pipeline seam so a
-- future per-event predicate (e.g. an opt-in self-damage or pet-source guard)
-- has a single home.
function M.allow(_ev)
  return true
end
