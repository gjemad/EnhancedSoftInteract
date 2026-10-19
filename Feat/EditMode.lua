local _, ns = ...;
local frame = ns.frame;
local HUD_DEFAULT_POSITION, Notify = ns.HUD_DEFAULT_POSITION, ns.Notify;
local UpdateLayout = ns.UpdateLayout;

----
--  Shared Classic/Forever preview targets, grouped by their actual interaction. A weighted cycle
--  spreads the families out while using every name once, including just one generic mailbox.
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
ns.PREVIEW_TARGETS = PREVIEW_TARGETS;

-- Samples whose real interaction is a gathering or opening cast, so the settings preview can show a
-- cast bar on them. Opening is limited to the objects measured with spell 22810, like the live tracker.
local CAST_CURSORS = { GatherHerbs = true, Mine = true, Skin = true };
local OPENING_SAMPLES = { ["Barrel of Milk"] = true, ["Food Crate"] = true };
function ns.SampleCastable(name, cursor)
  return CAST_CURSORS[cursor] or (cursor == "Interact" and OPENING_SAMPLES[name]) or false;
end

-- Each surface owns its position in the shared cycle. Requirements are resolved when shown, so
-- a preview keeps following this character's current gathering professions.
function ns.CreatePreviewPicker()
  local index = 0;
  return function()
    index = index % #PREVIEW_TARGETS + 1;
    local target = PREVIEW_TARGETS[index];
    local requirement = ns.RequirementFor(target.cursor);
    return target.name, requirement and "Unable" .. target.cursor or target.cursor, requirement, target.cursor;
  end;
end

----
--  Edit Mode (LibEditMode). In Edit Mode the HUD shows a sample target, so you can see it while you drag
--  it. A settings shortcut opens the AddOns page. Each layout keeps its own position; a layout without one uses
--  HUD_DEFAULT_POSITION.
----
local LibEditMode = LibStub("LibEditMode", true);
local settingsPending;

local function GetLayoutPosition(layoutName)
  return (layoutName and EnhancedSoftInteractDB.layouts[layoutName]) or HUD_DEFAULT_POSITION;
end

local function ApplyPosition(pos)
  frame:ClearAllPoints();
  frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y);
  if ns.styles.Get().Pixel then UpdateLayout(); end
end

-- Edit Mode changes every HUD; the settings card uses its own picker and HUD directly.
local nextEditModeSample = ns.CreatePreviewPicker();
local function ShowNextEditModeSample()
  ns.ShowSample(nextEditModeSample());
end
ns.ShowNextEditModeSample = ShowNextEditModeSample;

local function ShowEditModeSample()
  frame.inEditMode = true;
  ShowNextEditModeSample();
end

-- Back to the real soft target, or fade out when there is none.
local function EndEditModeSample()
  frame.inEditMode = false;
  frame.sampleName = nil;
  frame.lastTarget, frame.lastSignature = nil, nil;
  ns.OnSoftInteractChanged(nil, UnitGUID("softinteract"));
  if settingsPending then
    settingsPending = nil;
    -- Let Blizzard finish its native exit, including saving/closing controls, before opening another panel.
    C_Timer.After(0, function()
      if InCombatLockdown() then Notify("Settings can't be opened in combat."); return end
      ns.OpenSettings();
    end);
  end
end

local function SetupEditMode()
  if not LibEditMode then return end
  LibEditMode:AddFrame(frame, function(_, layoutName, point, x, y)
    EnhancedSoftInteractDB.layouts[layoutName] = { point = point, x = x, y = y };
    if ns.styles.Get().Pixel then UpdateLayout(); end
  end, HUD_DEFAULT_POSITION, "Enhanced Soft Interact");
  -- Keep the native position controls and one shortcut; all addon options live on the AddOns page.
  LibEditMode:AddFrameSettingsButtons(frame, {
    { text = "Open Settings", click = function()
      if InCombatLockdown() then return end
      settingsPending = true;
      -- This is the native Escape/close callback, including the unsaved-layout prompt.
      -- Its closure already owns the manager; no addon-supplied self or lock state is needed.
      if EditModeManagerFrame.onCloseCallback then
        securecallfunction(EditModeManagerFrame.onCloseCallback);
      else
        Notify("Close the main Edit Mode window to open Enhanced Soft Interact settings.");
      end
    end },
  });
  LibEditMode:RegisterCallback("layout", function(layoutName) ApplyPosition(GetLayoutPosition(layoutName)); end);
  LibEditMode:RegisterCallback("rename", function(oldName, newName)
    local layouts = EnhancedSoftInteractDB.layouts;
    layouts[newName], layouts[oldName] = layouts[oldName], nil;
  end);
  LibEditMode:RegisterCallback("delete", function(layoutName) EnhancedSoftInteractDB.layouts[layoutName] = nil; end);
  LibEditMode:RegisterCallback("enter", ShowEditModeSample);
  LibEditMode:RegisterCallback("exit", EndEditModeSample);
end

-- Opens Edit Mode for moving the HUD; all options live in the Interface AddOns page.
function ns.OpenHUDInEditMode()
  if InCombatLockdown() then Notify("Edit Mode can't be opened in combat."); return end
  if not LibEditMode then Notify("Edit Mode isn't available."); return end
  if ns.settingsPanel then ns.settingsPanel:Hide(); end
  if SettingsPanel:IsShown() then SettingsPanel:Close(true); end
  if not EditModeManagerFrame:IsShown() then
    if not EditModeManagerFrame:CanEnterEditMode() then Notify("Edit Mode isn't available right now."); return end
    ShowUIPanel(EditModeManagerFrame);
  end
end

table.insert(ns.onLoad, function()
  ApplyPosition(GetLayoutPosition(LibEditMode and LibEditMode:GetActiveLayoutName()));
  SetupEditMode();
  if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    local info = UIDropDownMenu_CreateInfo();
    info.text = "Enhanced Soft Interact";
    info.notCheckable = true;
    info.func = function() ns.OpenSettings(); end;
    AddonCompartmentFrame:RegisterAddon(info);
  end
end);
