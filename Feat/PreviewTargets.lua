local _, ns = ...;

----
--  Sample targets for the settings preview and for the HUD in Edit Mode: real Classic/Forever names,
--  grouped by their actual interaction. A weighted cycle spreads the families out while using every
--  name once, including just one generic mailbox.
----
local PREVIEW_FAMILIES = {
  { cursor = "Innkeeper", names = { "Innkeeper Gryshka", "Innkeeper Allison", "Innkeeper Firebrew", "Innkeeper Pala", "Innkeeper Farley" } },
  { cursor = "GatherHerbs", names = { "Peacebloom", "Silverleaf", "Earthroot", "Wild Steelbloom", "Mageroyal",
    "Briarthorn", "Kingsblood", "Goldthorn", "Sungrass", "Dreamfoil" } },
  { cursor = "Mine", names = { "Copper Vein", "Tin Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein",
    "Ooze Covered Rich Thorium Vein", "Ooze Covered Truesilver Deposit", "Ooze Covered Mithril Deposit",
    "Iron Deposit", "Gold Vein", "Rich Thorium Vein", "Silver Vein" } },
  { cursor = "Taxi", names = { "Doras", "Devrak", "Dungar Longdrink", "Gryth Thurden", "Thor" } },
  { cursor = "Quest", names = { "Thrall", "Marshal Dughan", "Cairne Bloodhoof", "King Magni Bronzebeard", "Deputy Willem",
    "Highlord Bolvar Fordragon", "High Tinker Mekkatorque", "Lady Sylvanas Windrunner", "Arch Druid Fandral Staghelm",
    "Tyrande Whisperwind", "Archmage Ansirem Runeweaver" } },
  { cursor = "Pickup", names = { "Olvia", "Thurman Mullby", "Trak'gen", "Thomas Miller" } },
  { cursor = "Trainer", names = { "Sian'tsu", "Ander Germaine", "Wu Shen", "Magar", "Gart Mistrunner" } },
  { cursor = "Skin", names = { "Prairie Wolf", "Plainstrider", "Elder Mottled Boar", "Elder Saltwater Crocolisk", "Young Goretusk", "Ragged Timber Wolf" } },
  { cursor = "Buy", names = { "Karus", "Koma", "Barnum Stonemantle", "Olivia Burnside" } },
  { cursor = "LootAll", names = { "Kobold Vermin", "Defias Pillager", "Frostmane Headhunter", "Burning Blade Neophyte", "Murloc Raider", "Southsea Brigand" } },
  { cursor = "Speak", names = { "High Overlord Saurfang", "Eitrigg" } },
  { cursor = "RepairNPC", names = { "Corina Steele", "Kaja" } },
  { cursor = "Directions", names = { "Stormwind City Guard", "Orgrimmar Grunt" } },
  { cursor = "Interact", names = { "Wanted Poster", "Battered Footlocker", "Waterlogged Footlocker", "Barrel of Milk", "Food Crate" } },
  { cursor = "Mail", names = { "Mailbox" } },
};
local PREVIEW_TARGETS, scores, used, total = {}, {}, {}, 0;
for i, family in ipairs(PREVIEW_FAMILIES) do
  scores[i], used[i] = 0, 0;
  total = total + #family.names;
end
local previous;
for step = 1, total do
  local selected;
  for i, family in ipairs(PREVIEW_FAMILIES) do
    scores[i] = scores[i] + #family.names;
    if used[i] < #family.names and i ~= previous and (step < total or i ~= 1)
      and (not selected or scores[i] > scores[selected]) then selected = i; end
  end
  if step == 1 then selected = 1; end --the settings preview opens on Innkeeper Gryshka
  local family = PREVIEW_FAMILIES[selected];
  used[selected], scores[selected] = used[selected] + 1, scores[selected] - total;
  PREVIEW_TARGETS[#PREVIEW_TARGETS + 1] = { name = family.names[used[selected]], cursor = family.cursor };
  previous = selected;
end
ns.PREVIEW_TARGETS = PREVIEW_TARGETS; --for the test tools

-- Samples whose real interaction is a gathering or opening cast, so the settings preview can show a
-- cast bar on them. Opening is limited to the objects measured with spell 22810, like the live tracker.
local CAST_CURSORS = { GatherHerbs = true, Mine = true, Skin = true };
local OPENING_SAMPLES = { ["Barrel of Milk"] = true, ["Food Crate"] = true };
function ns.SampleCastable(name, cursor)
  return CAST_CURSORS[cursor] or (cursor == "Interact" and OPENING_SAMPLES[name]) or false;
end

-- Each picker keeps its own position in the shared cycle, so the settings preview and Edit Mode step
-- through it separately. Requirements are resolved when shown, so a preview keeps following this
-- character's current gathering professions.
function ns.CreatePreviewPicker()
  local index = 0;
  return function()
    index = index % #PREVIEW_TARGETS + 1;
    local target = PREVIEW_TARGETS[index];
    local requirement = ns.RequirementFor(target.cursor);
    return target.name, requirement and "Unable" .. target.cursor or target.cursor, requirement, target.cursor;
  end;
end
