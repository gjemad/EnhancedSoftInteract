local _, ns = ...;
local frame = ns.frame;
local HUD_DEFAULT_POSITION, Notify = ns.HUD_DEFAULT_POSITION, ns.Notify;
local UpdateLayout = ns.UpdateLayout;

----
--  Samples for the HUD in Edit Mode: Classic Era NPCs and game objects (also in WoW: Forever), in three
--  name lengths, each with its cursor. Edit Mode shows a sample while the HUD is moved.
----
local PREVIEW_NPCS = {
  { --short
    { "Thrall", "Quest" }, { "Doras", "Taxi" }, { "Devrak", "Taxi" }, { "Karus", "Buy" },
    { "Olvia", "Buy" }, { "Gamon", "Speak" }, { "Sian'tsu", "Trainer" },
    { "Mailbox", "Mail" }, { "Peacebloom", "GatherHerbs" }, { "Silverleaf", "GatherHerbs" },
    { "Earthroot", "GatherHerbs" }, { "Tin Vein", "Mine" }, { "Copper Vein", "Mine" },
    { "Prairie Wolf", "Skin" }, { "Plainstrider", "Skin" }, { "Kobold Vermin", "LootAll" },
  },
  { --medium
    { "Innkeeper Gryshka", "Innkeeper" }, { "Innkeeper Allison", "Innkeeper" }, { "Dungar Longdrink", "Taxi" },
    { "Thurman Mullby", "Pickup" }, { "Marshal Dughan", "Quest" }, { "Cairne Bloodhoof", "Quest" },
    { "Magni Bronzebeard", "Quest" }, { "Ander Germaine", "Trainer" }, { "Deputy Willem", "Quest" },
    { "Wild Steelbloom", "GatherHerbs" }, { "Mithril Deposit", "Mine" }, { "Truesilver Deposit", "Mine" },
    { "Small Thorium Vein", "Mine" }, { "Wanted Poster", "Interact" },
    { "Elder Mottled Boar", "Skin" }, { "Defias Pillager", "LootAll" }, { "Frostmane Headhunter", "LootAll" },
    { "Battered Footlocker", "PickLock" }, { "Waterlogged Footlocker", "PickLock" },
  },
  { --long
    { "Highlord Bolvar Fordragon", "Quest" }, { "High Tinker Mekkatorque", "Quest" },
    { "Lady Sylvanas Windrunner", "Quest" }, { "Arch Druid Fandral Staghelm", "Quest" },
    { "High Priestess Tyrande Whisperwind", "Quest" }, { "Archmage Ansirem Runeweaver", "Quest" },
    { "Ooze Covered Rich Thorium Vein", "Mine" }, { "Ooze Covered Truesilver Deposit", "Mine" },
    { "Ooze Covered Mithril Deposit", "Mine" },
    { "Elder Saltwater Crocolisk", "Skin" }, { "Burning Blade Neophyte", "LootAll" },
  },
};

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

-- Shows a sample target of the next name length on every HUD (the real one and the preview). Herbs and
-- ore look the way this character would see them, so without the profession they are unable and show the
-- requirement line.
local sampleLength, sampleName = 0, nil;
local function ShowNextEditModeSample()
  sampleLength = sampleLength % #PREVIEW_NPCS + 1;
  local npcs = PREVIEW_NPCS[sampleLength];
  local npc;
  repeat npc = npcs[math.random(#npcs)] until #npcs == 1 or npc[1] ~= sampleName;
  local name, cursor = npc[1], npc[2];
  sampleName = name;
  local requirement = ns.RequirementFor(cursor);
  if requirement then cursor = "Unable" .. cursor; end
  ns.ShowSample(name, cursor, requirement);
end
ns.ShowNextEditModeSample = ShowNextEditModeSample;

local function ShowEditModeSample()
  frame.inEditMode = true;
  sampleLength = 0;
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
