local _, ns = ...;
local issecretvalue = ns.issecretvalue;

-- Every client except Retail loads this file: WoW: Forever and Classic (Era and MoP). On those, skinnable
-- corpses keep the UnableSkin cursor and UnitIsInInteractRange stays false even where the key skins, but the
-- Skinning spell's range check is right. The TOC excludes Retail.

-- Cursors whose interact range the game misreports, and the spell whose range check is right for them.
-- The check runs by the ID of the rank the character knows, highest first. Forever 1.60.1 build 70938 has a
-- hidden spell also named Skinning (1240974) with no range, so a lookup by name returns nil there. The name
-- check stays as the fallback for a client whose ranks aren't listed; the ID in `name` only localizes it.
local RANGE_SPELLS = {
  Skin = { ranks = {102216, 74522, 50305, 32678, 10768, 8618, 8617, 8613}, name = {8613, "Skinning"} },
};

local function Readable(value)
  if issecretvalue(value) then return nil end
  return value;
end

-- A client without C_SpellBook.IsSpellKnown (which Forever's IsPlayerSpell wraps) uses the name check.
local function RankRangeCheck(ranks, unit)
  local IsKnown = C_SpellBook and C_SpellBook.IsSpellKnown;
  if not IsKnown then return nil end
  for _, spellID in ipairs(ranks) do
    if Readable(IsKnown(spellID)) then return Readable(C_Spell.IsSpellInRange(spellID, unit)) end
  end
end

local function NameRangeCheck(spell, unit)
  local spellName = C_Spell.GetSpellName(spell[1]) or spell[2];
  -- Forever finds a spell in the spellbook by name. Era and MoP can't, and need no check: the game shows
  -- the Skin cursor only to characters with Skinning, and IsSpellInRange gives nil for an unknown spell.
  local findSlot = C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell;
  if findSlot and not findSlot(spellName) then return nil end --learned, any rank
  return Readable(C_Spell.IsSpellInRange(spellName, unit));
end

-- Whether the unit is in range of the cursor's range spell, or nil when there is no answer.
function ns.SpellRangeCheck(cursorName, unit)
  local rangeSpell = RANGE_SPELLS[cursorName];
  if not (rangeSpell and C_Spell and C_Spell.IsSpellInRange) then return nil end
  local inRange = RankRangeCheck(rangeSpell.ranks, unit);
  if inRange ~= nil then return inRange end
  return NameRangeCheck(rangeSpell.name, unit);
end
