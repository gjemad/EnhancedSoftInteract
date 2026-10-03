local ADDON_NAME, ns = ...; --the addon folder name, and the table this addon's files share
local media = LibStub:GetLibrary("LibSharedMedia-3.0", true);

-- Fallbacks for APIs that some clients lack.
local issecretvalue = issecretvalue or function() return false end;
local SetUnitCursorTexture = SetUnitCursorTexture or function() return false end;

-- The Feat files add functions to run once the saved settings are ready, and /esi subcommands.
ns.onLoad = {};
ns.slashCommands = {};

-- Colors per icon type, for targets you can interact with. Unable icons always get UNABLE_COLOR or
-- OUT_OF_RANGE_COLOR, so they have no entries. Each color is an OKLCH hue and chroma picked per family
-- (related types share a hue band; icons with a strong color of their own, such as quest marks, pawprints
-- and transmog, use the icon's measured hue), at the lightest lightness sRGB can show, then scaled so the
-- strongest channel is 1. The lines and glows light at full strength, and colorBrightness dims them.
local TYPE_COLORS = {
  ["default"] = {1, 0.83, 0.33}, --unknown or secret icon: plain gold
  -- Quests: gold for normal quests and quest objects, blue for repeatable ones, amber for the campaign.
  ["Cursor Quest"] = {1, 0.85, 0.09},
  ["Cursor QuestInteract"] = {1, 0.85, 0.09},
  ["Cursor QuestRepeatable"] = {0.05, 0.59, 1},
  ["Cursor CampaignQuest"] = {1, 0.5, 0.05},
  ["Cursor CampaignQuestTurnIn"] = {1, 0.5, 0.05},
  -- Gathering and looting: leaf green, ore copper, hide tan, loot sand, and cool steel for locks and hands.
  ["Cursor GatherHerbs"] = {0.41, 1, 0.46},
  ["Cursor Mine"] = {1, 0.74, 0.44},
  ["Cursor Skin"] = {1, 0.6, 0.49},
  ["Cursor LootAll"] = {1, 0.83, 0.47},
  ["Cursor PickLock"] = {0.78, 0.88, 1}, --locked chests and footlockers
  ["Cursor OpenHand"] = {0.92, 0.95, 1}, --chests, petting animals
  ["Cursor OpenHandGlow"] = {0.73, 0.96, 1},
  -- Merchants and services.
  ["Cursor Pickup"] = {1, 0.73, 0.5}, --vendor: warm brown
  ["Cursor Buy"] = {1, 0.95, 0.68}, --bank: pale gold
  ["Cursor RepairNPC"] = {0.86, 0.94, 1}, --steel
  ["Cursor Reforge"] = {0.35, 0.97, 1}, --reforge and upgrade NPCs: teal
  ["Cursor Mail"] = {1, 0.29, 0.23}, --mailbox red
  ["Cursor Innkeeper"] = {0.4, 0.79, 1}, --hearthstone blue
  ["Cursor Taxi"] = {0.99, 1, 0.62}, --flight masters: pale straw
  ["Cursor Trainer"] = {1, 0.66, 0.47},
  ["Cursor Directions"] = {1, 0.55, 0.64}, --guards: rose
  ["Cursor Missions"] = {1, 0.64, 0.65},
  ["Cursor VoidStorage"] = {1, 0.54, 0.91}, --magenta
  ["Cursor Transmogrify"] = {0.69, 0.48, 1}, --violet
  -- Generic icons stay close to white, with a warm or cool tint.
  ["Cursor Speak"] = {1, 0.96, 0.91},
  ["Cursor Inspect"] = {0.81, 0.94, 1},
  ["Cursor Interact"] = {1, 0.79, 0.41}, --the cog: bronze
  -- Battle pets: green when you can capture the pet, gold otherwise.
  ["Cursor WildPetCapturable"] = {0.33, 1, 0.5},
  ["Cursor WildPet"] = {1, 0.74, 0.19},
};

-- Cursor textures come in several spellings: plain names ("Cursor Innkeeper"), the crosshair version both
-- clients use ("Cursor Crosshair_Innkeeper_64", or the bare atlas name "Crosshair_Innkeeper_64"), sized
-- ones ("Cursor Cursor_CampaignQuest_32") and file paths ("Interface\Cursor\Innkeeper"). CursorName
-- reduces each one to "innkeeper", and returns nil for anything that isn't a cursor.
local function CursorName(key)
  local name = key:match("^[Cc]ursor (.+)$") or key:match("[Cc][Uu][Rr][Ss][Oo][Rr][\\/]([%w_]+)[%.%w]*$")
    or key:match("^[Cc]rosshair_.+$");
  if not name then return nil end
  return (name:gsub("^[Cc]rosshair_", ""):gsub("^[Cc]ursor_", ""):gsub("_%d+$", ""):lower());
end

-- The lookup form of a key: "cursor innkeeper". Other keys (file IDs, "default") stay as they are.
local function NormalizeCursorKey(key)
  local name = CursorName(key);
  return name and "cursor " .. name or key:lower();
end

-- Maps each normalized key to its TYPE_COLORS spelling, and to its Unable version ("Cursor UnableSkin").
local COLOR_KEY_BY_LOWER = {};
for key in pairs(TYPE_COLORS) do
  COLOR_KEY_BY_LOWER[NormalizeCursorKey(key)] = key;
  local name = key:match("^Cursor (.+)$");
  if name then COLOR_KEY_BY_LOWER[NormalizeCursorKey("Cursor Unable" .. name)] = "Cursor Unable" .. name; end
end
local function ColorKeyFor(cursorKey)
  return COLOR_KEY_BY_LOWER[NormalizeCursorKey(cursorKey)] or cursorKey;
end

local function IsUnableKey(key)
  return key ~= nil and key:lower():find("unable") ~= nil;
end

-- Icons that say "you can interact" without saying how. A talkable NPC with one of them gets the
-- speech bubble.
local GENERIC_ICONS = {
  ["Cursor Interact"] = true, --cogwheel
  ["Cursor UnableInteract"] = true,
  ["default"] = true, --secret or unknown icon
};

-- Friendly creature you can interact with: not a player, not attackable, not a game object such as a
-- herb or mailbox.
local function IsTalkableNPC(unit)
  if not UnitExists(unit) or UnitIsPlayer(unit) or UnitCanAttack("player", unit) then return false end
  if UnitIsGameObject and UnitIsGameObject(unit) then return false end
  if UnitIsInteractable and not UnitIsInteractable(unit) then return false end
  return true;
end

-- Whether the soft target is in interact range, the check Blizzard's gamepad action bar makes. nil on a
-- client without UnitIsInInteractRange (retail); the cursor's Unable state then decides.
local function InInteractRange()
  if not UnitIsInInteractRange then return nil end
  return UnitIsInInteractRange("softinteract");
end

local function Notify(msg) print("|cffffd100Enhanced Soft Interact:|r " .. msg) end

-- The same setting as Options > Controls > Enable Interact Key.
local function IsInteractKeyEnabled()
  return tonumber(GetCVar("softTargetInteract")) == Enum.SoftTargetEnableFlags.Any;
end

-- Saved-setting defaults. LoadSettings fills in unset keys from here, and the Edit Mode panel resets to them.
local DEFAULTS = {
  showIcon = true, iconSize = 30, swapIconAndKey = false, showKey = true, keySize = 130,
  fontSize = 17, nameMinWidth = 100, nameMaxWidth = 200, hudHeight = 50, colorBrightness = 100,
  interactAnim = true, switchAnim = true,
  fadeEnabled = true, fadeInTime = 0.07, fadeOutTime = 0.1,
};
-- Each Edit Mode slider's {min, max, step}. Fade times start above 0, because the Fade Animations checkbox turns fading off.
local SLIDER_RANGES = {
  iconSize = {16, 48, 2}, keySize = {75, 150, 5},
  fontSize = {10, 32, 1}, nameMinWidth = {50, 300, 5}, nameMaxWidth = {50, 400, 5},
  colorBrightness = {30, 100, 5}, hudHeight = {20, 80, 2},
  fadeInTime = {0.01, 1, 0.01}, fadeOutTime = {0.01, 1, 0.01},
};

----
--  The HUD frame. Edit Mode moves it (LibEditMode, Feat\EditMode.lua), and each Edit Mode layout keeps
--  its own position in EnhancedSoftInteractDB.layouts. Outside Edit Mode it ignores the mouse.
----
local HUD_DEFAULT_POSITION = { point = "CENTER", x = 200, y = -100 };
local frame = CreateFrame("Frame", "EnhancedSoftInteractHUD", UIParent);
frame:SetSize(200, 40);
frame:SetPoint(HUD_DEFAULT_POSITION.point, UIParent, HUD_DEFAULT_POSITION.point, HUD_DEFAULT_POSITION.x, HUD_DEFAULT_POSITION.y);
frame:SetMovable(true);
frame:SetDontSavePosition(true); --Edit Mode layouts hold the position, not WoW's layout-local.txt
frame:EnableMouse(false);
frame:Hide();
frame.editModeName = "Enhanced Soft Interact";

local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];

-- The look follows Blizzard's level-up banner. There is no plate, only a soft shadow (Media\SoftShadow.tga,
-- white with a Gaussian alpha falloff that reaches zero at every edge, drawn black) that keeps the text
-- readable. The target type's color lights the lines (LevelUp-Bar-White) and a glow behind the icon
-- (Media\SoftGlow.tga, same falloff, additive). The interact flash is the same glow over the whole HUD.
local SHADOW, GLOW = MEDIA .. "SoftShadow", MEDIA .. "SoftGlow";
local SHADOW_ALPHA = 0.9;
local LINE_ATLAS = "LevelUp-Bar-White";

-- frame.box is the layout box (icon | name | key, hudHeight tall) that everything anchors to. It draws
-- nothing itself.
frame.box = frame:CreateTexture(nil, "BACKGROUND");
frame.box:SetPoint("CENTER"); --a longer name widens the box equally on both sides
frame.shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -1);
frame.iconGlow = frame:CreateTexture(nil, "BACKGROUND", nil, 1);
frame.iconGlow:SetBlendMode("ADD");
frame.lineLowGlow = frame:CreateTexture(nil, "BORDER", nil, -1);
frame.lineLowGlow:SetBlendMode("ADD");
frame.lineLow = frame:CreateTexture(nil, "BORDER");
frame.lineHigh = frame:CreateTexture(nil, "BORDER");
frame.flash = frame:CreateTexture(nil, "BORDER");
frame.flash:SetBlendMode("ADD");
frame.flash:SetAlpha(0);
frame.icon = frame:CreateTexture(nil, "ARTWORK");
local NAME_FONT = _G.Game17Font_Shadow and "Game17Font_Shadow" or "GameFontNormalLarge";
frame.name = frame:CreateFontString(nil, "ARTWORK", NAME_FONT);
frame.name:SetWordWrap(false); --one line; a name wider than its column ends in "..."
frame.name:SetJustifyH("CENTER");
frame.nameColor = { frame.name:GetTextColor() };
frame.requirement = frame:CreateFontString(nil, "ARTWORK", NAME_FONT);
frame.requirement:SetWordWrap(false);
frame.requirement:SetJustifyH("CENTER");
frame.requirement:SetTextColor(RED_FONT_COLOR:GetRGB()); --Blizzard's color for unmet requirements
frame.requirement:Hide();

-- The shadow reaches SHADOW_PAD_X past both ends of the box and SHADOW_PAD_Y above and below it. The
-- interact flash covers the box and 20 units past its ends. The icon glow follows the icon.
local SHADOW_PAD_X, SHADOW_PAD_Y = 75, 16;
frame.shadow:SetPoint("TOPLEFT", frame.box, "TOPLEFT", -SHADOW_PAD_X, SHADOW_PAD_Y);
frame.shadow:SetPoint("BOTTOMRIGHT", frame.box, "BOTTOMRIGHT", SHADOW_PAD_X, -SHADOW_PAD_Y);
frame.flash:SetPoint("TOPLEFT", frame.box, "TOPLEFT", -20, 0);
frame.flash:SetPoint("BOTTOMRIGHT", frame.box, "BOTTOMRIGHT", 20, 0);
frame.iconGlow:SetPoint("CENTER", frame.icon, "CENTER");

----
--  Interact key cap, on Blizzard's key art: the plunderstorm key, else the tutorial key, else a plain
--  box. margins is the transparent art around the key face (left, top, right, bottom), as shares of the
--  art's width and height. The plunderstorm key's border runs from x 16 to 92 and y 16 to 80 of its
--  108x96 image. Shares hold whatever size GetAtlasInfo reports. The cap frame is the face, so the layout
--  spaces the visible key like the icon, and the art's margins hang outside the frame.
----
local KEYCAP_STYLES = { --in order of preference
  { atlas = "plunderstorm-icon-key", textColor = {1, 1, 1}, shadow = true,
    margins = {16 / 108, 16 / 96, 15 / 108, 15 / 96} },
  { atlas = "newplayertutorial-icon-key", textColor = {0, 0, 0}, shadow = false },
};
local NO_MARGINS = {0, 0, 0, 0};

local cap = CreateFrame("Frame", nil, frame);
cap.icon = cap:CreateTexture(nil, "ARTWORK");
cap.text = cap:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
cap:Hide();
frame.keyCap = cap;

-- Styles the cap with the first key art this client has, else a plain dark box. cap.art keeps the art's
-- proportions and face margins for SetKeyCapText.
local function StyleKeyCap()
  cap.isGlyph = false;
  for _, style in ipairs(KEYCAP_STYLES) do
    local info = C_Texture.GetAtlasInfo(style.atlas);
    if info and info.width > 0 and info.height > 0 then
      cap.icon:SetAtlas(style.atlas);
      cap.art = { aspect = info.width / info.height, margins = style.margins or NO_MARGINS };
      cap.textColor = style.textColor;
      cap.text:SetShadowOffset(style.shadow and 1 or 0, style.shadow and -1 or 0);
      return;
    end
  end
  cap.art = { aspect = 1, margins = NO_MARGINS };
  cap.icon:SetColorTexture(0, 0, 0, 0.6);
  cap.textColor = {1, 1, 1};
  cap.text:SetShadowOffset(1, -1);
end

-- Out of range, the key label turns RED_FONT_COLOR, the way ActionButton_UpdateRangeIndicator colors an
-- action button's hotkey. A gamepad glyph has no label, so the glyph itself turns red. It loses its own
-- colors first, because red over a colored glyph (Xbox's blue X) comes out nearly black.
local function PaintKeyCap()
  local red = frame.outOfRange and { RED_FONT_COLOR:GetRGB() };
  cap.icon:SetDesaturated(cap.isGlyph and red and true or false);
  if cap.isGlyph then
    cap.icon:SetVertexColor(unpack(red or {1, 1, 1}));
  else
    cap.icon:SetVertexColor(1, 1, 1);
    cap.text:SetTextColor(unpack(red or cap.textColor));
  end
end

----
--  Animations
----

-- Calls step(t) every frame for duration seconds, with t going from 0 to 1. Playing again replaces the
-- running tween.
local function CreateTween()
  local driver = CreateFrame("Frame");
  function driver:Play(duration, step)
    local elapsed = 0;
    self:SetScript("OnUpdate", function(_, dt)
      elapsed = elapsed + dt;
      local t = math.min(1, elapsed / duration);
      step(t);
      if t == 1 then self:SetScript("OnUpdate", nil); end
    end);
  end
  function driver:Stop() self:SetScript("OnUpdate", nil); end
  return driver;
end

local function AnimationGroup(steps)
  local group = frame:CreateAnimationGroup();
  for _, s in ipairs(steps) do
    local a = group:CreateAnimation(s[1]);
    a:SetTarget(s[2]);
    a:SetOrder(s[3]);
    a:SetDuration(s[4]);
    if s.smoothing then a:SetSmoothing(s.smoothing); end
    if s.alpha then a:SetFromAlpha(s.alpha[1]); a:SetToAlpha(s.alpha[2]); end
    if s.scale then a:SetScaleFrom(1, 1); a:SetScaleTo(s.scale, s.scale); a:SetOrigin("CENTER", 0, 0); end
    if s.offset then a:SetOffset(0, s.offset); end
  end
  return group;
end

-- Interact feedback, 0.3 seconds: an additive glow in the target type's color over the HUD, the icon
-- scaling to POP and back, and the key cap dipping 2 units. Only rendering changes; the layout stays.
-- Scale steps in one group multiply, so step 2 scales by 1/POP to end at exactly the icon's size.
local PULSE_TIME = 0.3;
local POP = 1.15;
frame.pulse = AnimationGroup({
  { "Alpha", frame.flash, 1, 0.06, smoothing = "OUT", alpha = {0, 0.45} },
  { "Alpha", frame.flash, 2, 0.24, smoothing = "IN", alpha = {0.45, 0} },
  { "Scale", frame.icon, 1, 0.08, smoothing = "OUT", scale = POP },
  { "Scale", frame.icon, 2, 0.2, smoothing = "IN_OUT", scale = 1 / POP },
  { "Translation", cap, 1, 0.05, smoothing = "OUT", offset = -2 },
  { "Translation", cap, 2, 0.15, smoothing = "IN_OUT", offset = 2 },
});

-- When the frame changes to another target or another action (skinning, then looting the same corpse),
-- the icon and name drop 5 units at once, then rise into place and fade in over SWITCH_TIME. Translation
-- steps in one group add up. The icon glow fades in with them: it moves with the icon at once, so without
-- the fade it would show the old color at the new spot before the icon arrives. The type color and the
-- HUD's alpha blend over at the same time (SetTypeColor, FadeOver).
local SWITCH_TIME = 0.2;
local switchSteps = {};
for _, region in ipairs({ frame.icon, frame.name }) do
  table.insert(switchSteps, { "Translation", region, 1, 0, offset = -5 });
  table.insert(switchSteps, { "Translation", region, 2, SWITCH_TIME, smoothing = "OUT", offset = 5 });
end
for _, region in ipairs({ frame.icon, frame.name, frame.iconGlow }) do
  table.insert(switchSteps, { "Alpha", region, 1, 0, alpha = {0, 0} });
  table.insert(switchSteps, { "Alpha", region, 2, SWITCH_TIME, smoothing = "OUT", alpha = {0, 1} });
end
frame.switchAnim = AnimationGroup(switchSteps);

local function PlaySwitchAnim()
  frame.switchAnim:Stop();
  frame.switchAnim:Play();
end

local function PlayInteractPulse()
  frame.pulse:Stop();
  frame.pulse:Play();
end

-- The HUD fades with its own animation group, not Blizzard's shared fade manager, which risks taint.
-- FadeTo's durations are for a full fade from 0 to 1 alpha, so partial fades (interruptions) take
-- proportionally less. FadeOver takes the given time whatever the distance.
frame.fader = frame:CreateAnimationGroup();
frame.fadeAnim = frame.fader:CreateAnimation("Alpha");
frame.fader:SetToFinalAlpha(true);
frame.fader:SetScript("OnFinished", function()
  if frame.fadingOut then
    frame.fadingOut = false;
    frame:Hide();
  end
end);

-- Returns the fade-in and fade-out durations, or 0 (instant) when fade animations are off.
local function GetFadeTimes()
  if not EnhancedSoftInteractDB.fadeEnabled then return 0, 0 end
  return EnhancedSoftInteractDB.fadeInTime, EnhancedSoftInteractDB.fadeOutTime;
end

local function CurrentAlpha()
  if not frame:IsShown() then return 0 end
  if frame.fader:IsPlaying() then
    local from, to = frame.fadeAnim:GetFromAlpha(), frame.fadeAnim:GetToAlpha();
    return from + (to - from) * frame.fadeAnim:GetSmoothProgress();
  end
  return frame:GetAlpha();
end

local function FadeOver(toAlpha, duration, hideWhenDone)
  local fromAlpha = CurrentAlpha();
  frame.fader:Stop();
  frame.fadingOut = hideWhenDone;
  frame:SetAlpha(toAlpha);
  frame:Show();
  frame.fadeAnim:SetFromAlpha(fromAlpha);
  frame.fadeAnim:SetToAlpha(toAlpha);
  frame.fadeAnim:SetDuration(math.max(0.01, duration));
  frame.fader:Play();
end

local function FadeTo(toAlpha, fullDuration, hideWhenDone)
  FadeOver(toAlpha, fullDuration * math.abs(toAlpha - CurrentAlpha()), hideWhenDone);
end

----
--  Layout
----

-- Lines in the target type's color: a strong one under the name, 5 units wider than the box on each
-- side, with an additive glow, and a fainter one above the name, 20 units shorter on each side. They sit
-- LINE_GAP beyond the name's letters, so they move apart as the font grows.
-- The level-up bar art is a 7-pixel strip whose stroke is its bottom row, so a texture draws its line
-- near its bottom edge. frame.lineStrokeShift (3/7 for that art, 0 for the plain fallback) raises each
-- texture by that share of its height, which puts the middle of the stroke on the line's position.
local LINE_GAP = 6.5;
local function UpdateLines()
  local y = EnhancedSoftInteractDB.fontSize * 0.5 + LINE_GAP;
  local function Line(tex, inset, offsetY, height)
    offsetY = offsetY + height * (frame.lineStrokeShift or 0);
    tex:ClearAllPoints();
    tex:SetPoint("LEFT", frame.box, "LEFT", inset, offsetY);
    tex:SetPoint("RIGHT", frame.box, "RIGHT", -inset, offsetY);
    tex:SetHeight(height);
  end
  Line(frame.lineLow, -5, -y, 4);
  Line(frame.lineLowGlow, -5, -y, 10);
  Line(frame.lineHigh, 20, y, 3);
end

-- The icon and the key cap sit at opposite ends of the box, EDGE_INSET from the edge. "Swap Icon and
-- Key" (swapIconAndKey) swaps their ends. The name sits between them (UpdateLayout).
local EDGE_INSET = 7;
local function Inset(side) return side == "LEFT" and EDGE_INSET or -EDGE_INSET end

-- Most cursor art isn't centered in its image. ns.iconArtOffsets (Feat\Cursors.lua) has how far each
-- one's art sits right of and below center, in 64px units; the icon moves the other way. AnchorIcon
-- rounds the nudge to whole units, because the renderer may snap a fractional nudge away. Unable icons
-- use their cursor's offset. Icons from a file ID are 32px files that are already centered.
local function AnchorIcon()
  local side = EnhancedSoftInteractDB.swapIconAndKey and "RIGHT" or "LEFT";
  local key = frame.colorKey and NormalizeCursorKey(frame.colorKey):gsub("^cursor unable", "cursor ");
  local offset = key and not frame.iconFromFileID and ns.iconArtOffsets[key];
  local nudgeX, nudgeY = 0, 0;
  if offset then
    local function Round(v) return v >= 0 and math.floor(v + 0.5) or -math.floor(-v + 0.5) end
    local scale = EnhancedSoftInteractDB.iconSize / 64;
    nudgeX, nudgeY = Round(-offset[1] * scale), Round(offset[2] * scale);
  end
  frame.iconNudgeX, frame.iconNudgeY = nudgeX, nudgeY; --for /esi debug
  frame.icon:ClearAllPoints();
  frame.icon:SetPoint(side, frame.box, side, Inset(side) + nudgeX, nudgeY);
end

local function SetIconSide()
  local keySide = EnhancedSoftInteractDB.swapIconAndKey and "LEFT" or "RIGHT";
  AnchorIcon();
  cap:ClearAllPoints();
  cap:SetPoint(keySide, frame.box, keySide, Inset(keySide), 0);
end

-- The glow behind the icon is GLOW_W x GLOW_H icon sizes in range and shrinks to GLOW_OUT_OF_RANGE_SCALE
-- of that out of range. While the HUD is visible it gets there over GLOW_TIME, easing out from its
-- current size, so a range change halfway reverses smoothly. It resizes the texture instead of using a
-- Scale animation, so repeated changes can't add up.
local GLOW_W, GLOW_H = 2.2, 1.9;
local GLOW_OUT_OF_RANGE_SCALE = 0.55;
local GLOW_TIME = 0.25;
local function SizeGlow()
  local size = EnhancedSoftInteractDB.iconSize * (frame.glowScale or 1);
  frame.iconGlow:SetSize(size * GLOW_W, size * GLOW_H);
end

local glowTween, glowTarget = CreateTween(), nil;
local function SetGlowScale(target, animate)
  if not (animate and frame.glowScale) then
    glowTween:Stop();
    glowTarget, frame.glowScale = target, target;
    SizeGlow();
    return;
  end
  if target == glowTarget then return end --already there or on the way
  glowTarget = target;
  local from = frame.glowScale;
  glowTween:Play(GLOW_TIME, function(t)
    frame.glowScale = from + (target - from) * (1 - (1 - t) ^ 2);
    SizeGlow();
  end);
end

local function UpdateIcon()
  local db = EnhancedSoftInteractDB;
  frame.icon:SetSize(db.iconSize, db.iconSize);
  frame.icon:SetShown(db.showIcon);
  frame.iconGlow:SetShown(db.showIcon);
  SizeGlow();
  AnchorIcon(); --the nudge scales with the icon size
end

----
--  Interact key
----

-- The interact key's text ("F", "s-F"), or nil when it's unbound. While a controller is the active input
-- (GAME_PAD_ACTIVE_CHANGED), a gamepad binding ("PAD1", "PADLTRIGGER-PAD1") wins over a keyboard one.
-- WoW: Forever's gamepad UI has a fixed interact button instead of a binding; ns.GamepadInteractGlyph
-- (Feat\Forever.lua) returns its glyph while that UI is on.
ns.gamepadActive = false;
local function IsPadKey(key) return key:find("^PAD") ~= nil or key:find("%-PAD") ~= nil end
local function GetInteractKeyText()
  local glyph = ns.GamepadInteractGlyph and ns.GamepadInteractGlyph();
  if glyph then return "|A:" .. glyph .. ":14:14|a" end
  local keys = { GetBindingKey("INTERACTTARGET") };
  local key = keys[1];
  for _, k in ipairs(keys) do
    if IsPadKey(k) == ns.gamepadActive then key = k; break end
  end
  if not key then return nil end
  local text = GetBindingText(key, 1);
  if not text or text == "" then return nil end
  return text;
end

-- UpdateKeyCap and UpdateLayout measure text on hidden font strings that aren't anchored to the HUD.
-- GetStringWidth is SecretWhenAnchoringSecret, so a region anchored to the NPC name, which is secret in
-- instances and combat, returns secret sizes.
local function CreateMeasure()
  local fs = UIParent:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
  fs:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT"); --off-screen
  fs:Hide();
  return fs;
end
local keyTextMeasure, nameMeasure = CreateMeasure(), CreateMeasure();

-- A font string centers text by the letters' advance widths, but in Friz Quadrata (the default font) the
-- ink of some letters sits off-center in that width; an "R" leans 0.05 font sizes right because of its
-- leg. FRIZ_BEARINGS has each character's left and right side bearing in 1/1000 font sizes, read from
-- Fonts\FRIZQT__.TTF. InkOffset returns how far right of center a label's ink sits, in font sizes, and 0
-- for other fonts and unknown characters.
local FRIZ_BEARINGS = {
  ["A"]={9,2}, ["B"]={52,44}, ["C"]={40,13}, ["D"]={52,40}, ["E"]={52,9}, ["F"]={52,26}, ["G"]={40,69},
  ["H"]={52,53}, ["I"]={52,52}, ["J"]={-37,45}, ["K"]={52,-19}, ["L"]={52,13}, ["M"]={26,27}, ["N"]={44,40},
  ["O"]={40,41}, ["P"]={52,27}, ["Q"]={40,-118}, ["R"]={52,-43}, ["S"]={37,39}, ["T"]={-7,-7}, ["U"]={49,52},
  ["V"]={-5,7}, ["W"]={-6,12}, ["X"]={5,6}, ["Y"]={-7,4}, ["Z"]={25,16}, ["a"]={35,6}, ["b"]={35,41},
  ["c"]={40,-4}, ["d"]={40,36}, ["e"]={40,40}, ["f"]={34,-53}, ["g"]={15,3}, ["h"]={38,39}, ["i"]={42,39},
  ["j"]={-26,64}, ["k"]={38,-12}, ["l"]={38,39}, ["m"]={42,37}, ["n"]={42,38}, ["o"]={40,40}, ["p"]={35,40},
  ["q"]={41,39}, ["r"]={42,9}, ["s"]={30,26}, ["t"]={27,9}, ["u"]={38,39}, ["v"]={-12,2}, ["w"]={-8,2},
  ["x"]={-5,-5}, ["y"]={-21,5}, ["z"]={11,-1}, ["0"]={39,40}, ["1"]={157,201}, ["2"]={53,43}, ["3"]={61,78},
  ["4"]={13,24}, ["5"]={71,70}, ["6"]={45,48}, ["7"]={80,57}, ["8"]={39,36}, ["9"]={47,44}, ["-"]={35,34},
};
local function InkOffset(text, fontPath)
  if not fontPath:lower():find("frizqt__") then return 0 end
  local first, last = FRIZ_BEARINGS[text:sub(1, 1)], FRIZ_BEARINGS[text:sub(-1)];
  if not (first and last) then return 0 end
  return (first[1] - last[2]) / 2000;
end

-- SetKeyCapText moves the key text off the cap's center. A font string centers its whole line, including
-- the room for descenders, so capitals sit high. An "R" sat about 0.7 units high at font size 18, so the
-- text moves down 0.04 font sizes. On screenshots, letters also sat 0.8 to 1.3 units left after InkOffset
-- ("O", "R", "T"), so the text moves right by KEY_TEXT_NUDGE_X font sizes. WoW snaps text to whole pixels,
-- so a letter can still land half a pixel off.
local KEY_TEXT_NUDGE_X = 0.06;

-- The whole key art is max(24, fontSize + 9) x keySize% tall and keeps its proportions. The cap frame
-- (capWidth x capHeight, what the layout uses) is the key's face, and the art hangs past it by its
-- margins. A label too wide for the face widens it to the text plus KEY_TEXT_PAD and stretches the art.
-- A gamepad button comes from GetBindingText as one atlas markup ("|A:Gamepad_Gen_1_32:14:14|a"); the
-- cap then draws that button's 64px glyph, which fills its square, in place of the key art.
local KEY_TEXT_PAD = 10;
local function SetKeyCapText(text)
  local db = EnhancedSoftInteractDB;
  local scale = db.keySize / 100;
  local height = math.max(24, db.fontSize + 9) * scale;
  local glyph = text:match("^|A:([^:|]+):[^|]*|a$");
  glyph = glyph and glyph:gsub("_32$", "_64");
  if glyph and C_Texture.GetAtlasInfo(glyph) then
    cap.icon:SetAtlas(glyph);
    cap.icon:ClearAllPoints();
    cap.icon:SetAllPoints();
    cap.text:SetText("");
    cap.isGlyph = true;
    cap.capWidth, cap.capHeight = height, height;
    cap:SetSize(height, height);
    PaintKeyCap();
    return;
  end
  if cap.isGlyph then StyleKeyCap(); end --back from a gamepad glyph
  local fontPath = media:Fetch("font", db.font);
  local fontSize = math.max(10, (db.fontSize - 3) * scale);
  cap.text:SetFont(fontPath, fontSize, "");
  cap.text:SetPoint("CENTER", fontSize * (KEY_TEXT_NUDGE_X - InkOffset(text, fontPath)), -fontSize * 0.04);
  cap.text:SetText(text);
  keyTextMeasure:SetFont(fontPath, fontSize, "");
  keyTextMeasure:SetText(text);
  local textWidth = keyTextMeasure:GetStringWidth();
  if issecretvalue(textWidth) then textWidth = fontSize * #text * 0.6; end --rough estimate; not seen yet
  local m = cap.art.margins;
  local faceShareX, faceShareY = 1 - m[1] - m[3], 1 - m[2] - m[4];
  cap.capWidth = math.max(height * cap.art.aspect * faceShareX, textWidth + KEY_TEXT_PAD * scale);
  cap.capHeight = height * faceShareY;
  cap:SetSize(cap.capWidth, cap.capHeight);
  local artWidth = cap.capWidth / faceShareX; --wider than normal only when a long label stretches the art
  cap.icon:ClearAllPoints();
  cap.icon:SetPoint("TOPLEFT", -m[1] * artWidth, m[2] * height);
  cap.icon:SetPoint("BOTTOMRIGHT", m[3] * artWidth, -m[4] * height);
  PaintKeyCap();
end

local function UpdateKeyCap()
  -- The Edit Mode sample shows "F" when the key is unbound.
  local text = EnhancedSoftInteractDB.showKey and (GetInteractKeyText() or (frame.sampleName and "F"));
  cap:SetShown(text and true or false);
  if text then SetKeyCapText(text); end
end

----
--  Name, requirement line and columns
----

-- In range but unable (the character lacks the profession; ns.RequirementFor in Feat\Cursors.lua), a red
-- line under the name says why, in Blizzard's tooltip wording ("Requires Herbalism"). The HUD keeps its
-- height: the name shrinks to REQ_NAME_SCALE of the font size, turns grey and moves up REQ_NAME_Y, and the
-- requirement sits REQ_TEXT_Y below center at REQ_TEXT_SCALE. All of these are shares of the font size.
local REQ_NAME_SCALE, REQ_TEXT_SCALE = 0.82, 0.65;
local REQ_NAME_Y, REQ_TEXT_Y = 0.26, -0.41;
local REQ_NAME_GREY = 0.8;
local function NameFontSize()
  local size = EnhancedSoftInteractDB.fontSize;
  return frame.showRequirement and size * REQ_NAME_SCALE or size;
end

local function StyleName()
  local db = EnhancedSoftInteractDB;
  local font = media:Fetch("font", db.font);
  frame.showRequirement = frame.requirementText ~= nil and not frame.outOfRange;
  frame.name:SetFont(font, NameFontSize());
  if frame.showRequirement then
    frame.name:SetTextColor(REQ_NAME_GREY, REQ_NAME_GREY, REQ_NAME_GREY);
    frame.requirement:SetFont(font, db.fontSize * REQ_TEXT_SCALE);
    frame.requirement:SetText(frame.requirementText);
  else
    frame.name:SetTextColor(unpack(frame.nameColor));
  end
  frame.requirement:SetShown(frame.showRequirement);
end

-- The box is a table of three columns: icon | name | key cap (swapIconAndKey swaps the outer two). The icon
-- and key columns are as wide as their contents plus COLUMN_GAP; an empty column takes no room. The name
-- column fits the name (and the requirement line) between nameMinWidth and nameMaxWidth, and cuts a longer
-- name short with "...". A secret name has a secret width; its column then takes nameMaxWidth.
local COLUMN_GAP = 8;
local function UpdateLayout()
  local db = EnhancedSoftInteractDB;
  StyleName(); --sets frame.showRequirement, which the name column depends on
  local minName = db.nameMinWidth;
  local maxName = math.max(minName, db.nameMaxWidth);
  local function Column(width) return width > 0 and width + COLUMN_GAP or 0 end
  local left, right = Column(db.showIcon and db.iconSize or 0), Column(cap:IsShown() and cap.capWidth or 0);
  if db.swapIconAndKey then left, right = right, left; end
  local function FitWidth(text, size, width)
    nameMeasure:SetFont(media:Fetch("font", db.font), size, "");
    nameMeasure:SetText(text);
    local textWidth = nameMeasure:GetStringWidth();
    if issecretvalue(textWidth) then return maxName end
    return math.min(maxName, math.max(width, math.ceil(textWidth) + 1)); --+1: no "..." on an exact fit
  end
  local nameWidth = FitWidth(frame.sampleName or UnitName("softInteract") or "", NameFontSize(), minName);
  local nameY = 0;
  if frame.showRequirement then
    nameWidth = FitWidth(frame.requirementText, db.fontSize * REQ_TEXT_SCALE, nameWidth);
    nameY = db.fontSize * REQ_NAME_Y;
    frame.requirement:ClearAllPoints();
    frame.requirement:SetPoint("LEFT", frame.box, "LEFT", EDGE_INSET + left, db.fontSize * REQ_TEXT_Y);
    frame.requirement:SetWidth(nameWidth);
  end
  frame.name:ClearAllPoints();
  frame.name:SetPoint("LEFT", frame.box, "LEFT", EDGE_INSET + left, nameY);
  frame.name:SetWidth(nameWidth);
  local width = EDGE_INSET + left + nameWidth + right + EDGE_INSET;
  frame.box:SetWidth(width);
  frame.boxWidth, frame.nameWidth = width, nameWidth; --for /esi debug; reading them back could be secret
end

-- After a font or font size change, the name, key cap, columns and lines follow.
local function UpdateFont()
  frame.name:SetText(frame.sampleName or UnitName("softInteract"));
  UpdateKeyCap();
  UpdateLayout();
  UpdateLines();
end

local function UpdateHeight()
  frame.box:SetHeight(EnhancedSoftInteractDB.hudHeight);
end

----
--  Colors
----

-- Only a target you can interact with gets its type's color. In range but unable (such as a herb without
-- Herbalism) is UNABLE_COLOR. Out of range is OUT_OF_RANGE_COLOR, the frame fades to OUT_OF_RANGE_ALPHA,
-- and the key label turns red, as an action button's hotkey does when its target is out of range.
local OUT_OF_RANGE_COLOR = {.35, .35, .35};
local UNABLE_COLOR = {.5, .5, .5};
local IN_RANGE_ALPHA, OUT_OF_RANGE_ALPHA = 1, 0.75;

-- The color for an icon key (frame.colorKey) and range, dimmed by colorBrightness (percent).
local function GetTypeColor(key, outOfRange)
  local color;
  if outOfRange then
    color = OUT_OF_RANGE_COLOR;
  elseif IsUnableKey(key) then
    color = UNABLE_COLOR;
  else
    color = TYPE_COLORS[key] or TYPE_COLORS["default"];
  end
  local scale = EnhancedSoftInteractDB.colorBrightness / 100;
  return color[1] * scale, color[2] * scale, color[3] * scale;
end

local function PaintColor(r, g, b)
  frame.iconGlow:SetVertexColor(r, g, b, 0.6);
  frame.lineLow:SetVertexColor(r, g, b, 1);
  frame.lineLowGlow:SetVertexColor(r, g, b, 0.35);
  frame.lineHigh:SetVertexColor(r, g, b, 0.5);
  frame.flash:SetVertexColor(r, g, b);
end

-- Sets the colors, the key label and the glow size from frame.colorKey and frame.outOfRange. With blend
-- (the HUD is visible), the glow animates, and with switchAnim on the color blends over SWITCH_TIME from
-- wherever it is now, also from the middle of a running blend.
local colorTween = CreateTween();
local function SetTypeColor(blend)
  PaintKeyCap();
  SetGlowScale(frame.outOfRange and GLOW_OUT_OF_RANGE_SCALE or 1, blend);
  local to = { GetTypeColor(frame.colorKey, frame.outOfRange) };
  if not (blend and EnhancedSoftInteractDB.switchAnim and frame.rgb) then
    colorTween:Stop();
    frame.rgb = to;
    PaintColor(unpack(to));
    return;
  end
  local from = { unpack(frame.rgb) };
  colorTween:Play(SWITCH_TIME, function(t)
    for i = 1, 3 do frame.rgb[i] = from[i] + (to[i] - from[i]) * t; end
    PaintColor(unpack(frame.rgb));
  end);
end

local function UpdateColors() SetTypeColor(false); end

-- Textures for the shadow, glows and lines. A client without the level-up bar art gets plain lines.
local function ApplyTextures()
  local hasLineArt = C_Texture.GetAtlasInfo(LINE_ATLAS) ~= nil;
  frame.shadow:SetTexture(SHADOW);
  frame.shadow:SetVertexColor(0, 0, 0, SHADOW_ALPHA);
  frame.iconGlow:SetTexture(GLOW);
  frame.flash:SetTexture(GLOW);
  for _, line in ipairs({ frame.lineLow, frame.lineLowGlow, frame.lineHigh }) do
    if hasLineArt then line:SetAtlas(LINE_ATLAS); else line:SetTexture([[Interface\Buttons\WHITE8X8]]); end
  end
  frame.lineStrokeShift = hasLineArt and 3 / 7 or 0; --see UpdateLines
end

----
--  Showing a cursor and the soft target handler
----

-- Shows a cursor by name ("Skin", "UnableSpeak") on the icon and returns its key in the TYPE_COLORS
-- spelling. It uses the crosshair atlas (ns.CrosshairAtlasFor), the centered art SetUnitCursorTexture
-- uses too, else the classic Interface\Cursor file, whose art sits in the top-left corner (the mouse
-- hotspot).
local function ShowCursor(name)
  frame.iconFromFileID = false;
  local atlas = ns.CrosshairAtlasFor(name);
  if atlas then
    frame.icon:SetAtlas(atlas);
  else
    frame.icon:SetTexture([[Interface\Cursor\]] .. name);
  end
  return ColorKeyFor("Cursor " .. name);
end

-- Draws the soft target's cursor on the icon, as Blizzard's nameplates and gamepad action bar do, asking
-- for the centered crosshair art. Returns false when the target has no cursor.
local CROSSHAIR_STYLE = Enum.CursorStyle and Enum.CursorStyle.Crosshair;
local function DrawTargetCursor()
  return SetUnitCursorTexture(frame.icon, "softinteract", CROSSHAIR_STYLE);
end

-- Which cursor DrawTargetCursor drew, as a TYPE_COLORS key. It asks the texture in three ways: its atlas
-- name, the cursor name in its path ("Cursor Crosshair_Mail_64"), then its file ID, because retail draws
-- some cursors straight from their own files (ns.cursorFileNames, Feat\Cursors.lua). The crosshair atlases
-- live in those same files, so the file ID only counts when the other two say nothing. A secret icon is
-- "default", and an unknown file ID stays a number, which has no color. frame.iconSource keeps what
-- matched, for /esi debug.
local function IdentifyCursor()
  local icon = frame.icon;
  local atlas = icon:GetAtlas();
  if issecretvalue(atlas) then frame.iconSource = "secret"; return "default" end
  if atlas and atlas ~= "" then frame.iconSource = "atlas " .. atlas; return ColorKeyFor(atlas) end
  local path = icon:GetTextureFilePath();
  if issecretvalue(path) then frame.iconSource = "secret"; return "default" end
  if type(path) == "string" and CursorName(path) then frame.iconSource = "path " .. path; return ColorKeyFor(path) end
  local fileID = icon:GetTextureFileID();
  if issecretvalue(fileID) then frame.iconSource = "secret"; return "default" end
  frame.iconSource = "file " .. tostring(fileID);
  local name = fileID and ns.cursorFileNames[fileID];
  if not name then return tostring(fileID) end
  frame.iconFromFileID = true;
  return ColorKeyFor("Cursor " .. name);
end

local function OnSoftTargetCleared()
  frame.lastTarget, frame.lastSignature, frame.lastAction = nil, nil, nil;
  -- A running interact pulse finishes before the fade-out (looting clears the target at once).
  local wait = frame.pulseUntil - GetTime();
  local token = frame.fadeToken;
  local function FadeOut()
    if token == frame.fadeToken and frame:IsShown() and not frame.fadingOut then
      FadeTo(0, select(2, GetFadeTimes()), true);
    end
  end
  if wait > 0 then C_Timer.After(wait, FadeOut); else FadeOut(); end
end

local function OnSoftTargetChanged(oldTarget, newTarget)
  frame.name:SetText(UnitName("softInteract"));
  UpdateKeyCap(); --UpdateLayout runs below, once the requirement line is known

  -- A target without a cursor gets the Interact cog, or UnableInteract out of interact range, as on
  -- Blizzard's gamepad action bar.
  frame.iconFromFileID = false;
  local hasCursor = DrawTargetCursor();
  local iconKey;
  if hasCursor then
    iconKey = IdentifyCursor();
  else
    frame.iconSource = "none";
    iconKey = ShowCursor(InInteractRange() == false and "UnableInteract" or "Interact");
  end
  local resolvedKey = iconKey;

  -- Range comes from UnitIsInInteractRange, which Blizzard's gamepad action bar also uses for its
  -- Interact and UnableInteract icons. The soft-target cursor can stay on an Unable icon in interact
  -- range (seen with skinnable corpses). While you cast or channel (skinning, gathering), the game reports
  -- the target as Unable and out of range, because you can't interact while busy. The target that was in
  -- range keeps its in-range look, and the range check restores the real state after the cast. A spell's
  -- range check overrules both where the game gets a cursor wrong (ns.SpellRangeCheck in
  -- Feat\Forever.lua, for skinnable corpses).
  local knownTarget = not issecretvalue(newTarget) and newTarget or nil;
  local unableName = iconKey:match("^Cursor Unable(.+)$");
  local busy = UnitCastingInfo("player") or UnitChannelInfo("player");
  local canInteract = InInteractRange();
  local spellInRange = unableName and ns.SpellRangeCheck and ns.SpellRangeCheck(unableName, "softInteract");
  if spellInRange ~= nil then canInteract = spellInRange end
  if unableName and (canInteract or (busy and knownTarget and knownTarget == frame.inRangeTarget)) then
    iconKey = ShowCursor(unableName);
  end

  -- The range is final here, but the next steps can still make an in-range target Unable.
  local inRange = not IsUnableKey(iconKey);
  if inRange then frame.inRangeTarget = knownTarget; end

  -- The game shows the gather cursor even to characters who can't gather. Without the profession, the
  -- HUD shows the Unable icon and a requirement line.
  local cursorName = iconKey:match("^Cursor (.+)$");
  local requirement = cursorName and ns.RequirementFor(cursorName);
  if requirement then iconKey = ShowCursor("Unable" .. cursorName); end

  -- A talkable NPC with only a generic icon gets the speech bubble. Specific icons (trainer, transmog,
  -- vendor, quest, ...) always win.
  local talkBadge = (not hasCursor or GENERIC_ICONS[iconKey]) and IsTalkableNPC("softInteract");
  if talkBadge then
    local talkRange = InInteractRange();
    if talkRange ~= nil then inRange = talkRange end
    iconKey = ShowCursor(inRange and "Speak" or "UnableSpeak");
  end
  local outOfRange = not inRange;

  -- The game re-sends this event for the same target, when you step into range (the icon changes from
  -- Unable) and sometimes with nothing changed. The handler skips identical repeats.
  local signature = iconKey .. "|" .. tostring(talkBadge and true or false) .. "|" .. tostring(outOfRange);
  if knownTarget and knownTarget == frame.lastTarget and signature == frame.lastSignature
      and frame:IsShown() and not frame.fadingOut then
    -- The debug log keeps every game event, doubles included; unchanged range checks aren't logged.
    if ns.DebugSoftTarget and not frame.fromRangeCheck then
      ns.DebugSoftTarget(oldTarget, newTarget, hasCursor, resolvedKey, iconKey, talkBadge, outOfRange);
    end
    return;
  end
  -- It's a switch when the visible frame changes to another target or another action, not only its range.
  local action = iconKey:lower():gsub("unable", "");
  local visible = frame:IsShown() and not frame.fadingOut;
  local switched = visible and (action ~= frame.lastAction or not knownTarget or knownTarget ~= frame.lastTarget);
  frame.lastTarget, frame.lastSignature, frame.lastAction = knownTarget, signature, action;

  -- A visible HUD dims or brightens over SWITCH_TIME, together with its colors. A short fade-in time
  -- would otherwise drop it from 1 to 0.75 in about 0.02 seconds while the colors still blend.
  local toAlpha = outOfRange and OUT_OF_RANGE_ALPHA or IN_RANGE_ALPHA;
  if visible and EnhancedSoftInteractDB.switchAnim then
    FadeOver(toAlpha, SWITCH_TIME, false);
  else
    FadeTo(toAlpha, (GetFadeTimes()), false);
  end

  frame.colorKey, frame.outOfRange = iconKey, outOfRange;
  frame.requirementText = IsUnableKey(iconKey) and requirement or nil;
  UpdateLayout();
  AnchorIcon();
  SetTypeColor(visible); --blend while the frame is up, set at once when it fades in
  if switched and EnhancedSoftInteractDB.switchAnim then PlaySwitchAnim(); end

  if ns.DebugSoftTarget then
    ns.DebugSoftTarget(oldTarget, newTarget, hasCursor, resolvedKey, iconKey, talkBadge, outOfRange);
  end
end

local function OnSoftInteractChanged(oldTarget, newTarget)
  if frame.inEditMode then return end --Edit Mode shows a sample instead (Feat\EditMode.lua)
  frame.fadeToken = (frame.fadeToken or 0) + 1; --cancels a delayed fade-out
  if newTarget then
    OnSoftTargetChanged(oldTarget, newTarget);
  elseif frame:IsShown() and not frame.fadingOut then
    OnSoftTargetCleared();
  end
end
ns.OnSoftInteractChanged = OnSoftInteractChanged;

-- The game doesn't always re-send PLAYER_SOFT_INTERACT_CHANGED when you walk into or out of interact
-- range (seen with skinnable corpses), while the mouse cursor updates on its own. So while the HUD shows a
-- target, rangeWatcher checks that target again every RANGE_CHECK_INTERVAL seconds, and the repeat filter
-- skips unchanged checks. It leaves a target with a secret GUID (combat, instances) to the game's event.
local RANGE_CHECK_INTERVAL = 0.2;
local rangeWatcher = CreateFrame("Frame");
local sinceRangeCheck = 0;
rangeWatcher:SetScript("OnUpdate", function(_, elapsed)
  sinceRangeCheck = sinceRangeCheck + elapsed;
  if sinceRangeCheck < RANGE_CHECK_INTERVAL then return end
  sinceRangeCheck = 0;
  if not frame:IsShown() or frame.fadingOut or frame.inEditMode then return end
  local guid = UnitGUID("softinteract");
  if not guid or issecretvalue(guid) or guid ~= frame.lastTarget then return end
  frame.fromRangeCheck = true;
  OnSoftInteractChanged(guid, guid);
  frame.fromRangeCheck = false;
end);

----
--  Settings and events
----

-- Applies every setting to the HUD (on load).
local function ApplyAllSettings()
  ApplyTextures();
  StyleKeyCap();
  SetIconSide();
  UpdateIcon();
  UpdateFont();
  UpdateHeight();
  UpdateColors();
end

-- Fills in defaults, applies every setting and runs ns.onLoad.
local function LoadSettings()
  local db = EnhancedSoftInteractDB or {};
  EnhancedSoftInteractDB = db;
  for key, value in pairs(DEFAULTS) do
    if db[key] == nil then db[key] = value; end
  end
  db.editModeSections = db.editModeSections or {};
  db.layouts = db.layouts or {};
  db.font = db.font or media:GetDefault("font"); --not in DEFAULTS: fonts from other addons may register later
  ApplyAllSettings();
  for _, fn in ipairs(ns.onLoad) do fn(); end
end

-- The key cap follows binding and input device changes once the settings are loaded.
local function RefreshKeyCap()
  if not frame.loaded then return end
  UpdateKeyCap();
  UpdateLayout();
end

frame.pulseUntil = 0;
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
    if EnhancedSoftInteractDB.interactAnim and frame:IsShown() and not frame.fadingOut then
      PlayInteractPulse();
      frame.pulseUntil = GetTime() + PULSE_TIME;
    end
  elseif event == "GAME_PAD_ACTIVE_CHANGED" then
    ns.gamepadActive = (...) and true or false; --payload: isActive
    RefreshKeyCap();
  elseif event == "UPDATE_BINDINGS" then
    RefreshKeyCap();
    if ns.RefreshOptionsState then ns.RefreshOptionsState(); end
  end
end);

-- /esi opens the HUD in Edit Mode (Feat\EditMode.lua); the Feat files add subcommands to ns.slashCommands.
SLASH_ENHANCEDSOFTINTERACT1 = "/esi";
function SlashCmdList.ENHANCEDSOFTINTERACT(msg)
  local command = ns.slashCommands[strtrim(msg or ""):lower()];
  if command then command(); elseif ns.OpenHUDInEditMode then ns.OpenHUDInEditMode(); end
end

-- Shared with the Feat files.
ns.frame, ns.media, ns.typeColors = frame, media, TYPE_COLORS;
ns.DEFAULTS, ns.SLIDER_RANGES, ns.HUD_DEFAULT_POSITION = DEFAULTS, SLIDER_RANGES, HUD_DEFAULT_POSITION;
ns.Notify, ns.IsInteractKeyEnabled, ns.IsUnableKey = Notify, IsInteractKeyEnabled, IsUnableKey;
ns.ShowCursor, ns.GetTypeColor, ns.SetTypeColor, ns.UpdateColors = ShowCursor, GetTypeColor, SetTypeColor, UpdateColors;
ns.AnchorIcon, ns.SetIconSide, ns.UpdateIcon, ns.UpdateFont = AnchorIcon, SetIconSide, UpdateIcon, UpdateFont;
ns.UpdateKeyCap, ns.UpdateLayout, ns.UpdateHeight, ns.RefreshKeyCap = UpdateKeyCap, UpdateLayout, UpdateHeight, RefreshKeyCap;
ns.PlayInteractPulse, ns.PlaySwitchAnim = PlayInteractPulse, PlaySwitchAnim;
