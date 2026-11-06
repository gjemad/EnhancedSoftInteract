local ADDON_NAME, ns = ...;

-- WoW: Forever and Retail load this file. A client that recognizes none of the TOC's game types loads
-- it anyway, so check the build too. Era and MoP Classic give a soft target object no nameplate.
local build = select(4, GetBuildInfo());
if build < 16000 or (build >= 20000 and build < 100000) then return end

-- Forever doesn't draw a game object's name above it, though the object still gets a nameplate. This
-- label shows the soft target object's name on that plate: under Blizzard's interaction icon, or in the
-- icon's place while the icons are hidden. It copies the plate's own name font, so it matches NPC names.
-- It stays hidden while Plumber or Plater draws the name, so the name doesn't show twice.
-- Retail gives an object no plate with its icons off, so Feat\HideBlizzard.lua keeps the object icon's
-- CVar on for this option, and the icon art is made invisible here while object icons are off.
-- A new target's label fades in and rises, and a lost one fades out. It drops to UNUSABLE_ALPHA whenever the
-- HUD shows the same target as unusable (out of range, a missing profession, not enough skill or any other
-- Unable cursor). A removed plate takes the label with it at once, because a hidden plate gives its anchors
-- no reliable place. The glow eases its alpha and size every frame and takes the HUD's color as that blends,
-- so a new target or a range change has no visible step.
-- The icon gets the HUD's soft glow: its type color, strength and proportions. The texture moves onto the
-- plate's SoftTargetFrame, whose Icon is on the ARTWORK layer, because only that puts it behind the art.
-- Nothing attached to a nameplate may be measured: GetCenter and the like fail on it and taint the
-- addon. Anchoring and GetStringWidth work.
ns.ObjectNamesSupported = true;
local ICON_GAP, PLATE_GAP = 4, 2;
local USABLE_ALPHA, UNUSABLE_ALPHA = 1, 0.6;
local UNIT = "softinteract";

local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];
-- The HUD's GLOW_W and GLOW_H of 2.2 and 1.9 icon sizes and its out-of-range scale, around the plate's
-- 24-unit icon. Nothing on a plate may be measured, so these are fixed outsets.
local FADE_IN_TIME, FADE_OUT_TIME, DIM_TIME = 0.12, 0.1, 0.1;
local RISE = 5;
local GLOW_STRENGTH = 0.6; --in the color, as on the HUD
local GLOW_OUTSET_X, GLOW_OUTSET_Y = 14.4, 10.8;
local GLOW_UNUSABLE_X, GLOW_UNUSABLE_Y = 2.5, 0.5;
local SHADOW_OUTSET_X, SHADOW_OUTSET_Y, SHADOW_ALPHA = 14, 7, 0.6;

local holder = CreateFrame("Frame", nil, _G.WorldFrame); --nameplates live under WorldFrame too
holder:SetSize(1, 1);
holder:Hide();
local label = holder:CreateFontString(nil, "OVERLAY");
label:SetFontObject(SystemFont_NamePlate_Outlined);
ns.objectNameLabel = label; --for the test tools
local shadow = holder:CreateTexture(nil, "BACKGROUND");
shadow:SetTexture(MEDIA .. "SoftShadow");
shadow:SetVertexColor(0, 0, 0);
shadow:SetAlpha(SHADOW_ALPHA);
shadow:SetPoint("TOPLEFT", label, "TOPLEFT", -SHADOW_OUTSET_X, SHADOW_OUTSET_Y);
shadow:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", SHADOW_OUTSET_X, -SHADOW_OUTSET_Y);

local glow = holder:CreateTexture(nil, "BACKGROUND");
glow:SetTexture(MEDIA .. "SoftGlow");
glow:SetBlendMode("ADD");
glow:SetVertexColor(GLOW_STRENGTH, GLOW_STRENGTH, GLOW_STRENGTH, 1);
glow:Hide();
ns.objectIconGlow = glow; --for the test tools

local anchoredPlate, shownName;
local hiddenArt;

-- A repeat of the running fade's value changes nothing, since the core updates the label several times
-- for one target.
local fadeTween, wantedAlpha = ns.CreateTween(), nil;
local function FadeLabel(to, duration, from)
  if to == wantedAlpha and not from then return end
  wantedAlpha = to;
  from = from or holder:GetAlpha();
  holder:SetAlpha(from);
  fadeTween:Play(duration, function(t)
    holder:SetAlpha(from + (to - from) * t);
    if t == 1 and to == 0 then holder:Hide(); end
  end);
end

-- The label's anchor plus the rise's offset, which runs apart from the fades.
local anchor = {};
local riseOffset = 0;
local riseTween = ns.CreateTween();
local function PlaceLabel()
  label:ClearAllPoints();
  label:SetPoint(anchor[1], anchor[2], anchor[3], 0, anchor[4] + riseOffset);
end
local function StartRise()
  riseOffset = -RISE;
  PlaceLabel();
  riseTween:Play(FADE_IN_TIME, function(t)
    riseOffset = -RISE * (1 - t) * (1 - t);
    PlaceLabel();
  end);
end

-- removed: the plate is gone, so nothing can fade.
local function Hide(removed)
  if removed then
    riseTween:Stop();
    riseOffset = 0;
    fadeTween:Stop();
    wantedAlpha = 0;
    holder:Hide();
  elseif holder:IsShown() then
    FadeLabel(0, FADE_OUT_TIME);
  end
  anchoredPlate, shownName = nil, nil;
end

local function IconsShown()
  local size = tonumber(GetCVar("SoftTargetNameplateSize"));
  return size and size > 0;
end

-- Read from each addon's own settings. A change there reaches the label at the next target change.
local function OtherAddonDrawsName()
  return ns.PlumberOwnsTargetIcons() or ns.PlaterDrawsObjectNames();
end

-- The HUD's result, while the HUD shows this target: its color key is an Unable one. The HUD hasn't seen
-- a new target yet when this runs before it; the core calls Update again once the HUD has the target.
local function Unusable()
  local hud = ns.frame;
  local guid = UnitGUID(UNIT);
  if not hud or not hud.lastTarget or ns.issecretvalue(guid) or guid ~= hud.lastTarget then return false end
  return hud.outOfRange or ns.IsUnableKey(hud.colorKey);
end

-- With object icons off the art stays invisible on the object's plate, which Show Object Names and the
-- target loot effect keep. With only object icons on,
-- SoftTargetIconInteract is off and Blizzard's plate code hides this art, so the addon draws it the way
-- that code does. The game reuses plates, so the art gets its alpha back once it stops being this object's.
local function UpdateIconArt(db, object)
  local art, draw;
  if db and db.enabled and not ns.PlumberOwnsTargetIcons() and not ns.issecretvalue(object) and object then
    draw = db.showObjectIcons and not db.showNpcIcons;
    local needsPlate = db.showObjectNames or ns.PlaterDrawsObjectNames()
      or (ns.LootEffectNeedsObjectPlates and ns.LootEffectNeedsObjectPlates(db));
    if draw or (needsPlate and not db.showObjectIcons) then
      local plate = C_NamePlate.GetNamePlateForUnit(UNIT);
      local frame = plate and not plate:IsForbidden() and plate.UnitFrame and plate.UnitFrame.SoftTargetFrame;
      art = frame and frame.Icon;
    end
  end
  if hiddenArt and hiddenArt ~= art then hiddenArt:SetAlpha(1); end
  hiddenArt = nil;
  if not art then return end
  if draw then
    art:SetAlpha(1);
    art:SetShown(SetUnitCursorTexture(art, UNIT));
  else
    art:SetAlpha(0);
    hiddenArt = art;
  end
end

-- One frame of the glow: everything moves toward its wanted value, and the color comes from the HUD while
-- the HUD shows this target. The alpha goes last, because a texture's color call can carry an alpha too.
local glowDriver = CreateFrame("Frame");
glowDriver:Hide();
local glowFrame, glowFollowsHud;
local glowAlpha, glowAlphaTo, glowSize, glowSizeTo = 0, 0, 1, 1;

local function MoveToward(value, to, step)
  if value < to then return math.min(to, value + step) end
  return math.max(to, value - step);
end

local function PaintGlow()
  local x = GLOW_UNUSABLE_X + (GLOW_OUTSET_X - GLOW_UNUSABLE_X) * glowSize;
  local y = GLOW_UNUSABLE_Y + (GLOW_OUTSET_Y - GLOW_UNUSABLE_Y) * glowSize;
  glow:ClearAllPoints();
  glow:SetPoint("TOPLEFT", glowFrame, "TOPLEFT", -x, y);
  glow:SetPoint("BOTTOMRIGHT", glowFrame, "BOTTOMRIGHT", x, -y);
  local rgb = glowFollowsHud and ns.frame and ns.frame.rgb;
  if rgb then glow:SetVertexColor(rgb[1] * GLOW_STRENGTH, rgb[2] * GLOW_STRENGTH, rgb[3] * GLOW_STRENGTH, 1); end
  glow:SetAlpha(glowAlpha);
end

glowDriver:SetScript("OnUpdate", function(self, elapsed)
  glowAlpha = MoveToward(glowAlpha, glowAlphaTo, elapsed / (glowAlphaTo > glowAlpha and FADE_IN_TIME or FADE_OUT_TIME));
  glowSize = MoveToward(glowSize, glowSizeTo, elapsed / FADE_IN_TIME);
  PaintGlow();
  if glowAlpha == 0 and glowAlphaTo == 0 then
    glow:Hide();
    self:Hide();
    glowFrame = nil;
  end
end);

-- removed: the plate is gone, so nothing can fade.
local function HideGlow(removed)
  glowAlphaTo = 0;
  if removed or not glowFrame then
    glowAlpha = 0;
    glow:Hide();
    glowDriver:Hide();
    glowFrame = nil;
  end
end

-- The glow follows the icon the game or Show Target Icons draws, on NPCs and objects alike.
local function UpdateGlow(db, object)
  if not (db and db.enabled) or ns.PlumberOwnsTargetIcons() or ns.issecretvalue(object) or not IconsShown()
    or not (object and db.showObjectIcons or (not object and db.showNpcIcons)) then return HideGlow() end
  local plate = C_NamePlate.GetNamePlateForUnit(UNIT);
  local frame = plate and not plate:IsForbidden() and plate.UnitFrame and plate.UnitFrame.SoftTargetFrame;
  if not (frame and frame:IsShown()) then return HideGlow() end
  local hud, guid = ns.frame, UnitGUID(UNIT);
  glowFollowsHud = hud and not ns.issecretvalue(guid) and guid == hud.lastTarget;
  glowSizeTo = Unusable() and 0 or 1;
  glowAlphaTo = 1;
  if frame ~= glowFrame then
    glowFrame = frame;
    glowAlpha, glowSize = 0, glowSizeTo;
    glow:SetParent(frame);
    glow:SetDrawLayer("BACKGROUND");
    PaintGlow();
    glow:Show();
  end
  glowDriver:Show();
end

local function Update()
  local db = EnhancedSoftInteractDB;
  local object = UnitIsGameObject(UNIT);
  UpdateIconArt(db, object);
  UpdateGlow(db, object);
  if not (db and db.enabled and db.showObjectNames) or ns.issecretvalue(object) or not object or OtherAddonDrawsName() then return Hide() end
  local plate = C_NamePlate.GetNamePlateForUnit(UNIT);
  if not plate or plate:IsForbidden() then return Hide() end
  local unitFrame = plate.UnitFrame;
  local nameText = unitFrame and unitFrame.name;
  local fontObject = nameText and nameText:GetFontObject();
  if fontObject then label:SetFontObject(fontObject); end
  local name = UnitName(UNIT);
  label:SetText(name);
  local icon = unitFrame and unitFrame.SoftTargetFrame;
  anchor[1], anchor[2], anchor[3], anchor[4] = "BOTTOM", plate, "TOP", -PLATE_GAP;
  if icon and icon:IsShown() and IconsShown() and db.showObjectIcons then
    anchor[1], anchor[2], anchor[3], anchor[4] = "TOP", icon, "BOTTOM", -ICON_GAP;
  end
  local alpha = Unusable() and UNUSABLE_ALPHA or USABLE_ALPHA;
  -- A secret name can't be compared, so a plate change alone marks a new target there.
  local sameName = ns.issecretvalue(name) or name == shownName;
  if plate == anchoredPlate and sameName and holder:IsShown() then
    PlaceLabel();
    FadeLabel(alpha, DIM_TIME);
    return;
  end
  anchoredPlate, shownName = plate, not ns.issecretvalue(name) and name or nil;
  StartRise();
  holder:Show();
  FadeLabel(alpha, FADE_IN_TIME, 0);
end

-- Called when Enabled, Show Object Names or Show Target Icons changes, and after the HUD takes a target
-- or a change in range or state.
ns.UpdateObjectName = Update;

-- A plate can come after the target change, leave while the target stays, or be reused for another
-- unit, so plate events update the label as well. The icon CVars decide whether and where the label sits.
local ICON_CVARS = { softtargetnameplatesize = true, softtargeticongameobject = true };
local watcher = CreateFrame("Frame");
watcher:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED");
watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED");
watcher:RegisterEvent("NAME_PLATE_UNIT_REMOVED");
watcher:RegisterEvent("CVAR_UPDATE");
watcher:SetScript("OnEvent", function(_, event, token)
  if event == "CVAR_UPDATE" then
    if ns.issecretvalue(token) or type(token) ~= "string" or not ICON_CVARS[token:lower()] then return end
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    local plate = C_NamePlate.GetNamePlateForUnit(token);
    if plate and plate ~= anchoredPlate then return end
    Hide(true);
    HideGlow(true);
    C_Timer.After(0, Update);
    return;
  end
  Update();
end);

table.insert(ns.onLoad, Update);
