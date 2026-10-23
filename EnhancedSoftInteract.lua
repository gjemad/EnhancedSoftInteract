local ADDON_NAME, ns = ...; --the addon folder name, and the table this addon's files share
local media = LibStub:GetLibrary("LibSharedMedia-3.0", true);
media:Register("font", "PT Sans Narrow", [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\Fonts\PTSansNarrow-Regular.ttf]]);

local issecretvalue = ns.issecretvalue;

-- The Feat files add functions to run once the saved settings are ready, and /esi subcommands.
ns.onLoad = {};
ns.slashCommands = {};

local function Notify(msg) print("|cffffd100Enhanced Soft Interact:|r " .. msg) end

-- Saved-setting defaults. LoadSettings fills in unset keys from here.
local DEFAULTS = {
  enabled = true, showBlizzardTooltip = false, showBlizzardIcons = false, showObjectNames = true,
  forceInteractKey = true, forceInteractIcons = true,
  showIcon = true, elvShowIcon = false, swapIconAndKey = false, showKey = true, hudSize = "normal",
  showSkillUp = true, castBarEnabled = true, castBarTimer = true, castBarHideGame = true, castBarClicked = true, hudStyle = "levelup",
  -- Retail defaults to Plunderstorm keys; Forever and the Classic clients default to the Classic keys.
  elvFont = "PT Sans Narrow", keyStyle = select(4, GetBuildInfo()) >= 100000 and "plunderstorm" or "classic",
  -- The game's own defaults are 10 yards, straight ahead.
  interactRange = 20, interactArc = 1,
};
-- Each settings slider's {min, max, step}.
local SLIDER_RANGES = {
  interactRange = {5, 45, 1},
};

local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];

-- The soft shadow behind the text, and how far it reaches past the box's ends (x) and above and below it (y).
local SHADOW = MEDIA .. "SoftShadow";
local SHADOW_PADDING = { x = 75, y = 16 };

----
--  CreateHUD builds the real HUD and UI previews. Each owns its textures, animations and state.
----
local function CreateHUD(frame)
  local hud = { frame = frame };
  -- frame.box is the layout box (icon | name | key, hudHeight tall) that everything anchors to. It draws
  -- nothing itself.
  frame.box = frame:CreateTexture(nil, "BACKGROUND");
  frame.box:SetPoint("CENTER"); --layout keeps the name column centered on the HUD
  frame.shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -1);
  frame.shadow:SetTexture(SHADOW); --HUD\Appearance.lua sets its strength and shows it for styles with a shadow
  frame.iconGlow = frame:CreateTexture(nil, "BACKGROUND", nil, 1);
  frame.iconGlow:SetBlendMode("ADD");
  frame.lineLowGlow = frame:CreateTexture(nil, "BORDER", nil, -1);
  frame.lineLowGlow:SetBlendMode("ADD");
  frame.lineLow = frame:CreateTexture(nil, "BORDER");
  frame.lineHigh = frame:CreateTexture(nil, "BORDER");
  -- Keep pulse opacity on a frame: texture tint/atlas setup cannot overwrite this alpha.
  frame.flashHolder = CreateFrame("Frame", nil, frame);
  frame.flashHolder:SetAllPoints(frame);
  frame.flashHolder:SetFrameLevel(frame:GetFrameLevel());
  frame.flashHolder:SetAlpha(0);
  frame.flash = frame.flashHolder:CreateTexture(nil, "BORDER");
  frame.flash:SetBlendMode("ADD");
  ns.styles.Create(frame);
  frame.icon = frame:CreateTexture(nil, "ARTWORK");
  -- Era has no Game17Font_Shadow. SetFont replaces the template's font and size,
  -- so the name uses the same anchor on every client.
  local NAME_FONT = _G.Game17Font_Shadow and "Game17Font_Shadow" or "GameFontHighlightLarge";
  frame.nameHolder = CreateFrame("Frame", nil, frame);
  frame.nameHolder:SetAllPoints(frame);
  frame.nameHolder:SetFrameLevel(frame:GetFrameLevel());
  frame.name = frame.nameHolder:CreateFontString(nil, "ARTWORK", NAME_FONT);
  frame.name:SetWordWrap(false); --one line; a name wider than its column ends in "..."
  frame.name:SetJustifyH("CENTER");
  frame.nameColor = { frame.name:GetTextColor() };
  frame.compactName = frame.nameHolder:CreateFontString(nil, "ARTWORK", NAME_FONT);
  frame.compactName:SetWordWrap(false);
  frame.compactName:SetJustifyH("CENTER");
  frame.compactName:SetAlpha(0);
  frame.skillIcon = frame.nameHolder:CreateTexture(nil, "ARTWORK"); --skill-up arrows before the name
  frame.skillIcon:Hide();
  frame.requirement = frame:CreateFontString(nil, "ARTWORK", NAME_FONT);
  frame.requirement:SetWordWrap(false);
  frame.requirement:SetJustifyH("CENTER");
  frame.requirement:SetTextColor(RED_FONT_COLOR:GetRGB()); --Blizzard's color for unmet requirements
  frame.requirement:Hide();
  for _, label in ipairs({ frame.name, frame.compactName, frame.requirement }) do label.baseShadow = { label:GetShadowOffset() }; end
  frame.statusShadow = frame:CreateTexture(nil, "BACKGROUND", nil, -1);
  frame.statusShadow:SetTexture(SHADOW);
  frame.statusShadow:SetVertexColor(0, 0, 0, 0.35);
  frame.statusShadow:Hide();
  ns.CastBar.Create(frame);

  -- The interact flash covers the box and 20 units past its ends. The icon glow follows the icon.
  frame.shadow:SetPoint("TOPLEFT", frame.box, "TOPLEFT", -SHADOW_PADDING.x, SHADOW_PADDING.y);
  frame.shadow:SetPoint("BOTTOMRIGHT", frame.box, "BOTTOMRIGHT", SHADOW_PADDING.x, -SHADOW_PADDING.y);
  frame.flash:SetPoint("TOPLEFT", frame.box, "TOPLEFT", -20, 0);
  frame.flash:SetPoint("BOTTOMRIGHT", frame.box, "BOTTOMRIGHT", 20, 0);
  frame.iconGlow:SetPoint("CENTER", frame.icon, "CENTER");

  ns.SetupKeyCap(hud);
  ns.SetupInteraction(hud);
  ns.SetupFade(hud);
  ns.SetupLayout(hud);
  ns.SetupAppearance(hud);
  ns.SetupDisplay(hud);

  return hud;
end

----
--  The HUD frame. Edit Mode moves it (LibEditMode, Feat\EditMode.lua), and each Edit Mode layout keeps
--  its own position in EnhancedSoftInteractDB.layouts. Outside Edit Mode it ignores the mouse.
----
local HUD_DEFAULT_POSITION = { point = "CENTER", x = 200, y = -100 };
local frame = CreateFrame("Frame", "EnhancedSoftInteractHUD", UIParent);
local hud = CreateHUD(frame);
local huds = { hud }; --the real HUD and any UI previews
frame:SetSize(200, 40);
frame:SetPoint(HUD_DEFAULT_POSITION.point, UIParent, HUD_DEFAULT_POSITION.point, HUD_DEFAULT_POSITION.x, HUD_DEFAULT_POSITION.y);
frame:SetMovable(true);
frame:SetDontSavePosition(true); --Edit Mode layouts hold the position, not WoW's layout-local.txt
frame:EnableMouse(false);
frame:Hide();
frame.editModeName = "Enhanced Soft Interact";

-- With the addon disabled, every target counts as none.
-- A success or interrupt outcome finishes before the HUD follows new target state.
-- Right after a cast the game re-sends the corpse or node as Unable, can clear it and returns it as
-- LootAll within a few frames. Only the latest state matters, so it is applied once the outcome ends.
local targetQueued = false;
local function OnSoftInteractChanged(oldTarget, newTarget, fromRangeCheck)
  if frame.inEditMode then
    if ns.DebugSoftTarget then ns.DebugSoftTarget(oldTarget, newTarget, nil, "edit_mode"); end
    return;
  end
  local remaining = ns.CastBar.OutcomeRemaining(frame);
  if remaining > 0 and EnhancedSoftInteractDB.enabled then
    if not targetQueued then
      targetQueued = true;
      C_Timer.After(remaining, function()
        targetQueued = false;
        local guid = UnitGUID("softinteract");
        OnSoftInteractChanged(guid, guid);
      end);
    end
    if ns.DebugSoftTarget and not fromRangeCheck then ns.DebugSoftTarget(oldTarget, newTarget, nil, "queued"); end
    return;
  end
  frame.fadeToken = (frame.fadeToken or 0) + 1;
  local target, changed;
  if newTarget and EnhancedSoftInteractDB.enabled then
    target, changed = hud.OnSoftTargetChanged(newTarget);
  else
    frame.targetState = nil;
    frame.inRangeTarget = nil;
    if frame:IsShown() and not frame.fadingOut then hud.OnSoftTargetCleared(); end
  end
  ns.RefreshInteractionCastBar();
  if ns.UpdateObjectName then ns.UpdateObjectName(); end
  -- Selected debug sources retain clears/repeats while open; unchanged range polls stay silent.
  if ns.DebugSoftTarget and (not fromRangeCheck or changed) then
    ns.DebugSoftTarget(oldTarget, newTarget, target, EnhancedSoftInteractDB.enabled and "active" or "disabled", fromRangeCheck);
  end
end
ns.OnSoftInteractChanged = OnSoftInteractChanged;

-- The game doesn't always re-send PLAYER_SOFT_INTERACT_CHANGED when you walk into or out of interact
-- range (seen with skinnable corpses), while the mouse cursor updates on its own. So while the HUD shows a
-- target, rangeWatcher checks that target again every RANGE_CHECK_INTERVAL seconds, and the repeat filter
-- skips unchanged checks. It leaves a target with a secret GUID (combat, instances) to the game's event.
local RANGE_CHECK_INTERVAL = 0.2;
local rangeWatcher = CreateFrame("Frame", nil, frame);
local sinceRangeCheck = 0;
rangeWatcher:SetScript("OnUpdate", function(_, elapsed)
  sinceRangeCheck = sinceRangeCheck + elapsed;
  if sinceRangeCheck < RANGE_CHECK_INTERVAL then return end
  sinceRangeCheck = 0;
  if not frame:IsShown() or frame.fadingOut or frame.inEditMode then return end
  local guid = UnitGUID("softinteract");
  if not guid or issecretvalue(guid) or guid ~= frame.lastTarget then return end
  OnSoftInteractChanged(guid, guid, true);
end);

-- Builds a UI preview HUD on frame, once the settings are loaded.
local function AddHUD(hudFrame)
  local h = CreateHUD(hudFrame);
  h.ApplyAllSettings();
  table.insert(huds, h);
  return h;
end

-- Fills in defaults, applies every setting and runs ns.onLoad.
local function LoadSettings()
  local db = EnhancedSoftInteractDB or {};
  EnhancedSoftInteractDB = db;
  for key, value in pairs(DEFAULTS) do
    if db[key] == nil then db[key] = value; end
  end
  db.layouts = db.layouts or {};
  db.font = db.font or media:GetDefault("font"); --not in DEFAULTS: fonts from other addons may register later
  hud.ApplyAllSettings();
  for _, fn in ipairs(ns.onLoad) do fn(); end
end

-- The key cap follows binding and input device changes once the settings are loaded.
local function RefreshKeyCap()
  if not frame.loaded then return end
  for _, h in ipairs(huds) do
    h.UpdateKeyCap();
    h.UpdateLayout();
  end
end

frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED");
frame:RegisterEvent("PLAYER_SOFT_TARGET_INTERACTION");
frame:RegisterEvent("UPDATE_BINDINGS");
frame:RegisterEvent("GAME_PAD_ACTIVE_CHANGED");
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... == ADDON_NAME then
      LoadSettings();
      frame.loaded = true;
      frame:UnregisterEvent("ADDON_LOADED");
    end
  elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
    OnSoftInteractChanged(...);
  elseif event == "PLAYER_SOFT_TARGET_INTERACTION" then
    for _, h in ipairs(huds) do
      if h.frame:IsShown() and not h.frame.fadingOut then h.PlayInteractPulse("game"); end
    end
  elseif event == "GAME_PAD_ACTIVE_CHANGED" then
    ns.gamepadActive = (...) and true or false; --payload: isActive
    RefreshKeyCap();
  elseif event == "UPDATE_BINDINGS" then
    RefreshKeyCap();
  end
end);

-- /esi opens the Interface AddOns settings (Feat\Settings.lua); the Feat files add subcommands to ns.slashCommands.
SLASH_ENHANCEDSOFTINTERACT1 = "/esi";
function SlashCmdList.ENHANCEDSOFTINTERACT(msg)
  local command = ns.slashCommands[strtrim(msg or ""):lower()];
  if command then command(); elseif ns.OpenSettings then ns.OpenSettings(); end
end

-- Shared with the Feat files.
ns.frame, ns.media, ns.AddHUD = frame, media, AddHUD;
ns.DEFAULTS, ns.SLIDER_RANGES, ns.HUD_DEFAULT_POSITION = DEFAULTS, SLIDER_RANGES, HUD_DEFAULT_POSITION;
ns.Notify = Notify;
ns.RefreshKeyCap = RefreshKeyCap;

-- A setting changes the real HUD and the settings preview alike, so each of these runs on every HUD.
function ns.ShowSample(...) for _, h in ipairs(huds) do h.ShowSample(...); end end
function ns.UpdateStyle() for _, h in ipairs(huds) do h.UpdateStyle(); end end
function ns.UpdateIcon() for _, h in ipairs(huds) do h.UpdateIcon(); end end
function ns.SetIconSide() for _, h in ipairs(huds) do h.SetIconSide(); end end
function ns.UpdateFont() for _, h in ipairs(huds) do h.UpdateFont(); end end
function ns.UpdateKeyCap() for _, h in ipairs(huds) do h.UpdateKeyCap(); end end
function ns.UpdateLayout() for _, h in ipairs(huds) do h.UpdateLayout(); end end
-- Only the test tools call this one.
function ns.PlayInteractPulse(source) for _, h in ipairs(huds) do h.PlayInteractPulse(source); end end
