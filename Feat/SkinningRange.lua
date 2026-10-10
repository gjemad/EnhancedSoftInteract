local _, ns = ...;
local issecretvalue = ns.issecretvalue;

-- Every client except Retail loads this file: WoW: Forever and Classic (Era and MoP). On those, skinnable
-- corpses keep the UnableSkin cursor where the key already skins (measured on Forever, user-confirmed on
-- Classic, 2026-10-10). Retail is unchecked, so the TOC leaves it out.

-- Cursors whose interact range the game misreports, and the spell whose range check is right for them.
-- The check needs the name (spell ID 8613 gave nil for a higher rank on Forever), so the ID only localizes
-- it. When it gives nil, UnitIsInInteractRange decides where the client has it.
-- On skinnable corpses, the cursor stays UnableSkin and UnitIsInInteractRange stays false even where the
-- key skins (measured in game), but the Skinning spell's range check is right.
local RANGE_SPELLS = {
  Skin = {8613, "Skinning"},
};

-- Whether the unit is in range of the cursor's range spell, or nil when there is no answer.
function ns.SpellRangeCheck(cursorName, unit)
  local rangeSpell = RANGE_SPELLS[cursorName];
  if not (rangeSpell and C_Spell and C_Spell.IsSpellInRange) then return nil end
  local spellName = C_Spell.GetSpellName(rangeSpell[1]) or rangeSpell[2];
  -- Forever finds a spell in the spellbook by name. Era and MoP can't, and need no check: the game shows
  -- the Skin cursor only to characters with Skinning, and IsSpellInRange gives nil for an unknown spell.
  local findSlot = C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell;
  if findSlot and not findSlot(spellName) then return nil end --learned, any rank
  local inRange = C_Spell.IsSpellInRange(spellName, unit);
  if issecretvalue(inRange) then return nil end
  return inRange;
end
