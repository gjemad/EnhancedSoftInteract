local _, ns = ...;

-- WoW: Forever and Retail load this file. A client that recognizes none of the TOC's game types loads
-- it anyway, so check the build too. Era and MoP Classic give a soft target object no nameplate.
local build = select(4, GetBuildInfo());
if build < 16000 or (build >= 20000 and build < 100000) then return end

-- Forever doesn't draw a game object's name above it, though the object still gets a nameplate. This
-- label shows the soft target object's name on that plate: under Blizzard's interaction icon, or in the
-- icon's place while the icons are hidden. It copies the plate's own name font, so it matches NPC names.
-- Blizzard animates the plate itself, so the label shows, hides and dims at once: it drops to
-- UNUSABLE_ALPHA whenever the HUD shows the same target as unusable (out of range, a missing profession,
-- not enough skill or any other Unable cursor).
-- Nothing attached to a nameplate may be measured: GetCenter and the like fail on it and taint the
-- addon. Anchoring and GetStringWidth work.
ns.ObjectNamesSupported = true;
local ICON_GAP = 2;
local USABLE_ALPHA, UNUSABLE_ALPHA = 1, 0.6;
local UNIT = "softinteract";

local holder = CreateFrame("Frame", nil, _G.WorldFrame); --nameplates live under WorldFrame too
holder:SetSize(1, 1);
holder:Hide();
local label = holder:CreateFontString(nil, "OVERLAY");
label:SetFontObject(SystemFont_NamePlate_Outlined);
ns.objectNameLabel = label; --for the test tools
local anchoredPlate;

local function Hide()
  holder:Hide();
  anchoredPlate = nil;
end

local function IconsShown()
  local size = tonumber(GetCVar("SoftTargetNameplateSize"));
  return size and size > 0;
end

-- The HUD's result, while the HUD shows this target: its color key is an Unable one. The HUD hasn't seen
-- a new target yet when this runs before it; the core calls Update again once the HUD has the target.
local function Unusable()
  local hud = ns.frame;
  local guid = UnitGUID(UNIT);
  if not hud or not hud.lastTarget or ns.issecretvalue(guid) or guid ~= hud.lastTarget then return false end
  return hud.outOfRange or ns.IsUnableKey(hud.colorKey);
end

local function Update()
  local db = EnhancedSoftInteractDB;
  local object = UnitIsGameObject(UNIT);
  if not (db and db.enabled and db.showObjectNames) or ns.issecretvalue(object) or not object then return Hide() end
  local plate = C_NamePlate.GetNamePlateForUnit(UNIT);
  if not plate or plate:IsForbidden() then return Hide() end
  local unitFrame = plate.UnitFrame;
  local nameText = unitFrame and unitFrame.name;
  local fontObject = nameText and nameText:GetFontObject();
  if fontObject then label:SetFontObject(fontObject); end
  label:SetText(UnitName(UNIT));
  label:ClearAllPoints();
  local icon = unitFrame and unitFrame.SoftTargetFrame;
  if icon and icon:IsShown() and IconsShown() then
    label:SetPoint("TOP", icon, "BOTTOM", 0, -ICON_GAP);
  else
    label:SetPoint("BOTTOM", plate, "TOP");
  end
  anchoredPlate = plate;
  holder:SetAlpha(Unusable() and UNUSABLE_ALPHA or USABLE_ALPHA);
  holder:Show();
end

-- Called when Enabled, Show Object Names or Show Target Icons changes, and after the HUD takes a target
-- or a change in range or state.
ns.UpdateObjectName = Update;

-- A plate can come after the target change, leave while the target stays, or be reused for another
-- unit, so plate events update the label as well. The icon size CVar decides where the label sits.
local watcher = CreateFrame("Frame");
watcher:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED");
watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED");
watcher:RegisterEvent("NAME_PLATE_UNIT_REMOVED");
watcher:RegisterEvent("CVAR_UPDATE");
watcher:SetScript("OnEvent", function(_, event, token)
  if event == "CVAR_UPDATE" then
    if ns.issecretvalue(token) or type(token) ~= "string" or token:lower() ~= "softtargetnameplatesize" then return end
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    local plate = C_NamePlate.GetNamePlateForUnit(token);
    if plate and plate ~= anchoredPlate then return end
    Hide();
    C_Timer.After(0, Update);
    return;
  end
  Update();
end);

table.insert(ns.onLoad, Update);
