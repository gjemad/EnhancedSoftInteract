local ADDON_NAME, ns = ...; --the addon folder name, and the table this addon's files share
local media = LibStub:GetLibrary("LibSharedMedia-3.0", true);

-- Fallbacks for APIs that some clients lack.
local issecretvalue = issecretvalue or function() return false end;

-- The Feat files add functions to run once the saved settings are ready, and /esi subcommands.
ns.onLoad = {};
ns.slashCommands = {};

local NormalizeCursorKey, ColorKeyFor = ns.NormalizeCursorKey, ns.ColorKeyFor;
local GetTypeColor = ns.GetTypeColor;

-- Every chat message of the addon starts with "ESI:".
local function Notify(msg) print("|cffffd100ESI:|r " .. msg) end

-- Saved-setting defaults. LoadSettings fills in unset keys from here, and the Edit Mode panel resets to them.
local DEFAULTS = {
  enabled = true, hideBlizzard = true, forceInteractKey = true, forceInteractIcons = true, previewMinimized = true,
  showIcon = true, iconSize = 30, swapIconAndKey = false, showKey = true, keyScale = 100,
  fontSize = 17, nameMinWidth = 100, nameMaxWidth = 250, hudHeight = 50, colorBrightness = 100,
  animationsEnabled = true, hudStyle = "levelup", shadowStrength = 90,
};
-- Each Edit Mode slider's {min, max, step}.
local SLIDER_RANGES = {
  iconSize = {16, 48, 2}, keyScale = {60, 150, 5},
  fontSize = {10, 32, 1}, nameMinWidth = {50, 300, 5}, nameMaxWidth = {50, 400, 5},
  colorBrightness = {30, 100, 5}, hudHeight = {20, 80, 2}, shadowStrength = {0, 100, 5},
};

-- Animation timings match the user's chosen settings.
local FADE_IN_TIME, FADE_OUT_TIME = 0.18, 0.22;

local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];

-- Common shadow and glow textures; style-specific artwork lives in Styles/.
local SHADOW, GLOW = MEDIA .. "SoftShadow", MEDIA .. "SoftGlow";
ns.HUD_SHADOW_PADDING = { x = 75, y = 16 };

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

-- Keeps an animated value inside its range, so no tween or blend can push a glow, color or press depth
-- past its limits.
local function Clamp(value, low, high) return math.max(low, math.min(high, value)) end

local CreateTween = ns.CreateTween;

----
--  Interact key
----

local GetInteractKeyText, IsChordDown = ns.GetInteractKeyText, ns.IsChordDown;

local InkOffset = ns.InkOffset;
local keyTextMeasure, nameMeasure = ns.CreateMeasure(), ns.CreateMeasure();

-- Range opacity is shared by every HUD.
local IN_RANGE_ALPHA, OUT_OF_RANGE_ALPHA = 1, 0.75;

----
--  CreateHUD builds the real HUD and the Edit Mode preview. Each owns its textures, animations and state.
----
local function CreateHUD(frame)
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
  -- Keep pulse opacity on a frame: texture tint/atlas setup cannot overwrite this alpha.
  frame.flashHolder = CreateFrame("Frame", nil, frame);
  frame.flashHolder:SetAllPoints(frame);
  frame.flashHolder:SetFrameLevel(frame:GetFrameLevel());
  frame.flashHolder:SetAlpha(0);
  frame.flash = frame.flashHolder:CreateTexture(nil, "BORDER");
  frame.flash:SetBlendMode("ADD");
  ns.styles.Create(frame);
  frame.icon = frame:CreateTexture(nil, "ARTWORK");
  local NAME_FONT = _G.Game17Font_Shadow and "Game17Font_Shadow" or "GameFontNormalLarge";
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
  local function SetName(text)
    frame.name:SetText(text);
    frame.compactName:SetText(text);
  end
  frame.requirement = frame:CreateFontString(nil, "ARTWORK", NAME_FONT);
  frame.requirement:SetWordWrap(false);
  frame.requirement:SetJustifyH("CENTER");
  frame.requirement:SetTextColor(RED_FONT_COLOR:GetRGB()); --Blizzard's color for unmet requirements
  frame.requirement:Hide();
  frame.statusShadow = frame:CreateTexture(nil, "BACKGROUND", nil, -1);
  frame.statusShadow:SetTexture(SHADOW);
  frame.statusShadow:SetVertexColor(0, 0, 0, 0.35);
  frame.statusShadow:Hide();

  -- The shadow reaches SHADOW_PAD_X past both ends of the box and SHADOW_PAD_Y above and below it. The
  -- interact flash covers the box and 20 units past its ends. The icon glow follows the icon.
  local SHADOW_PAD_X, SHADOW_PAD_Y = ns.HUD_SHADOW_PADDING.x, ns.HUD_SHADOW_PADDING.y;
  frame.shadow:SetPoint("TOPLEFT", frame.box, "TOPLEFT", -SHADOW_PAD_X, SHADOW_PAD_Y);
  frame.shadow:SetPoint("BOTTOMRIGHT", frame.box, "BOTTOMRIGHT", SHADOW_PAD_X, -SHADOW_PAD_Y);
  frame.flash:SetPoint("TOPLEFT", frame.box, "TOPLEFT", -20, 0);
  frame.flash:SetPoint("BOTTOMRIGHT", frame.box, "BOTTOMRIGHT", 20, 0);
  frame.iconGlow:SetPoint("CENTER", frame.icon, "CENTER");

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

  -- A blocked interaction dims the input; the status line explains why. Press shading still applies.
  local WHITE = {1, 1, 1};
  local function PaintKeyCap()
    local shade = cap.pressShade or 1;
    local function Shaded(c) return c[1] * shade, c[2] * shade, c[3] * shade end
    local blocked = frame.outOfRange or frame.requirementText ~= nil;
    local neutral = blocked and {0.75, 0.75, 0.75};
    cap.icon:SetDesaturated(cap.isGlyph and blocked and true or false);
    if cap.isGlyph then
      cap.icon:SetVertexColor(Shaded(neutral or WHITE));
    else
      cap.icon:SetVertexColor(Shaded(blocked and {0.7, 0.7, 0.7} or WHITE));
      cap.text:SetTextColor(Shaded(neutral or cap.textColor));
    end
  end

  ----
  --  Animations
  ----

  local function AnimationGroup(steps)
    local group = frame:CreateAnimationGroup();
    for _, s in ipairs(steps) do
      local a = group:CreateAnimation(s[1]);
      a:SetTarget(s[2]);
      a:SetOrder(s[3]);
      a:SetDuration(s[4]);
      if s.smoothing then a:SetSmoothing(s.smoothing); end
      if s.alpha then a:SetFromAlpha(s.alpha[1]); a:SetToAlpha(s.alpha[2]); end
      if s.scale then a:SetScaleFrom(1, 1); a:SetScaleTo(s.scale, s.scale); a:SetOrigin(s.origin or "CENTER", 0, 0); end
      if s.offset then a:SetOffset(0, s.offset); end
      if s.name then group[s.name] = a; end
    end
    return group;
  end

  -- Interact feedback: an additive glow in the target type's color over the HUD and the icon scaling to POP
  -- and back. Only rendering changes; the layout stays. Scale steps in one group multiply, so step 2 scales
  -- by 1/scale to end at exactly the starting size. PULSE_TIME covers the longest part, the key's ripple; a
  -- fade-out waits for it (frame.pulseUntil).
  local PULSE_TIME = 0.35;
  local POP = 1.15;
  frame.pulseUntil = 0;
  local pulseSteps = {
    { "Alpha", frame.flashHolder, 1, 0.06, smoothing = "OUT", alpha = {0, 0.45} },
    { "Alpha", frame.flashHolder, 2, 0.24, smoothing = "IN", alpha = {0.45, 0} },
    { "Scale", frame.icon, 1, 0.08, smoothing = "OUT", scale = POP },
    { "Scale", frame.icon, 2, 0.2, smoothing = "IN_OUT", scale = 1 / POP },
  };
  for _, glow in ipairs(frame.stylePulseLayers) do
    pulseSteps[#pulseSteps + 1] = { "Alpha", glow, 1, 0.06, smoothing = "OUT", alpha = {0, 0.45} };
    pulseSteps[#pulseSteps + 1] = { "Alpha", glow, 2, 0.24, smoothing = "IN", alpha = {0.45, 0} };
  end
  frame.pulse = AnimationGroup(pulseSteps);
  -- Return every pulse layer to its idle opacity on completion, interruption or hide.
  local function ClearPulseLight()
    frame.flashHolder:SetAlpha(0);
    for _, glow in ipairs(frame.stylePulseLayers) do glow:SetAlpha(0); end
  end
  frame.pulse:SetScript("OnFinished", ClearPulseLight);
  frame.pulse:SetScript("OnStop", ClearPulseLight);

  ----
  --  The key cap follows the interact key itself (KeyWatcher): up, held down, and released.
  --  Down: the key cap or gamepad button shrinks PRESS_DEPTH units toward its center over PRESS_DOWN and
  --  darkens to PRESS_SHADE, and stays that way while the key is held. Released: it springs back over
  --  PRESS_UP. The interaction itself (PlayInteractPulse) adds the ripple: a white ring along the cap's
  --  outline (Media\PressRingKey for the key's face, Media\PressRingRound for a glyph) grows to RIPPLE_GROW of
  --  its size and fades from RIPPLE_ALPHA over RIPPLE_TIME. The ring textures' outline fills 1/RING_PAD of the
  --  image on each axis, which leaves it room to grow.
  --  An animation snaps back when it ends, so pressIn holds the pressed size with a second, KEY_HOLD_TIME long
  --  step that keeps it. pressOut starts from wherever the press got to, so a quick tap or a press during a
  --  release doesn't jump. cap.pressDepth (0 up, 1 fully down) drives both the darkening and that start.
  ----
  local PRESS_DEPTH, PRESS_DOWN, PRESS_UP, PRESS_SHADE = 2, 0.05, 0.15, 0.7;
  local RIPPLE_TIME, RIPPLE_GROW, RIPPLE_ALPHA = 0.35, 1.45, 0.55;
  local RING_PAD = 1.6;
  local RING_KEY, RING_ROUND = MEDIA .. "PressRingKey", MEDIA .. "PressRingRound";
  local KEY_HOLD_TIME = 3600;
  cap.ring = cap:CreateTexture(nil, "OVERLAY");
  cap.ring:SetBlendMode("ADD");
  cap.ring:SetPoint("CENTER");
  cap.ring:SetAlpha(0);
  cap.pressDepth = 0;
  frame.pressIn = AnimationGroup({
    { "Scale", cap.icon, 1, PRESS_DOWN, smoothing = "OUT", scale = 1, name = "icon" },
    { "Scale", cap.text, 1, PRESS_DOWN, smoothing = "OUT", scale = 1, name = "text" },
    { "Scale", cap.icon, 2, KEY_HOLD_TIME, scale = 1 },
    { "Scale", cap.text, 2, KEY_HOLD_TIME, scale = 1 },
  });
  frame.pressOut = AnimationGroup({
    { "Scale", cap.icon, 1, PRESS_UP, smoothing = "IN_OUT", scale = 1, name = "icon" },
    { "Scale", cap.text, 1, PRESS_UP, smoothing = "IN_OUT", scale = 1, name = "text" },
  });
  frame.ripple = AnimationGroup({
    { "Scale", cap.ring, 1, RIPPLE_TIME, smoothing = "OUT", scale = RIPPLE_GROW },
    { "Alpha", cap.ring, 1, RIPPLE_TIME, alpha = {RIPPLE_ALPHA, 0} },
  });

  -- The cap's size when fully pressed, as a share of its normal size.
  local function PressedScale()
    local size = cap.capHeight or 0;
    return size > PRESS_DEPTH and (size - PRESS_DEPTH) / size or 1;
  end

  -- Moves cap.pressDepth to depth over duration, and darkens the cap along with it.
  local depthTween = CreateTween();
  local function TweenDepth(depth, duration, ease)
    local from = cap.pressDepth;
    depthTween:Play(duration, function(t)
      cap.pressDepth = Clamp(from + (depth - from) * ease(t), 0, 1);
      cap.pressShade = 1 - (1 - PRESS_SHADE) * cap.pressDepth;
      PaintKeyCap();
    end);
  end
  local function EaseOut(t) return 1 - (1 - t) ^ 2 end
  local function EaseInOut(t) return t * t * (3 - 2 * t) end

  -- Both groups animate the icon and the text by the same scale.
  local function SetPressScale(group, from, to)
    for _, name in ipairs({ "icon", "text" }) do
      group[name]:SetScaleFrom(from, from);
      group[name]:SetScaleTo(to, to);
    end
  end

  local function KeyDown()
    if cap.isDown then return end
    cap.isDown = true;
    local k = PressedScale();
    SetPressScale(frame.pressIn, 1 - (1 - k) * cap.pressDepth, k);
    frame.pressOut:Stop();
    frame.pressIn:Stop();
    frame.pressIn:Play();
    TweenDepth(1, PRESS_DOWN, EaseOut);
  end

  local function PlayRipple()
    cap.ring:SetTexture(cap.isGlyph and RING_ROUND or RING_KEY);
    cap.ring:SetSize(cap.capWidth * RING_PAD, cap.capHeight * RING_PAD);
    frame.ripple:Stop();
    frame.ripple:Play();
  end

  -- withRipple is true when an interaction releases the key. A release without one sets cap.releasedAt, so an
  -- interaction that comes right after it adds the ripple (PlayInteractPulse).
  local function KeyUp(withRipple)
    if not cap.isDown then return end
    cap.isDown = false;
    cap.releasedAt = not withRipple and GetTime() or nil;
    SetPressScale(frame.pressOut, 1 - (1 - PressedScale()) * cap.pressDepth, 1);
    frame.pressIn:Stop();
    frame.pressOut:Stop();
    frame.pressOut:Play();
    TweenDepth(0, PRESS_UP, EaseInOut);
    if withRipple then PlayRipple(); end
  end

  -- A whole press at once: for an interaction KeyWatcher didn't see the key for (a tap shorter than a frame,
  -- another binding, the Edit Mode preview). KeyWatcher leaves the key alone until the tap is done.
  local tapToken = 0;
  local function TapKey()
    if not cap:IsShown() then return end
    tapToken = tapToken + 1;
    local token = tapToken;
    cap.tapping = true;
    KeyDown();
    C_Timer.After(PRESS_DOWN, function()
      if token ~= tapToken then return end
      cap.tapping = false;
      KeyUp(true);
    end);
  end
  -- When the frame changes to another target or another action (skinning, then looting the same corpse),
  -- the icon and name drop 5 units at once, then rise into place and fade in over SWITCH_TIME. Translation
  -- steps in one group add up. The icon glow fades in with them: it moves with the icon at once, so without
  -- the fade it would show the old color at the new spot before the icon arrives. The type color and the
  -- HUD's alpha blend over at the same time (SetTypeColor, FadeOver).
  local SWITCH_TIME = 0.2;
  local switchSteps = {};
  for _, region in ipairs({ frame.icon, frame.nameHolder }) do
    table.insert(switchSteps, { "Translation", region, 1, 0, offset = -5 });
    table.insert(switchSteps, { "Translation", region, 2, SWITCH_TIME, smoothing = "OUT", offset = 5 });
  end
  for _, region in ipairs({ frame.icon, frame.nameHolder, frame.iconGlow }) do
    table.insert(switchSteps, { "Alpha", region, 1, 0, alpha = {0, 0} });
    table.insert(switchSteps, { "Alpha", region, 2, SWITCH_TIME, smoothing = "OUT", alpha = {0, 1} });
  end
  frame.switchAnim = AnimationGroup(switchSteps);

  local function PlaySwitchAnim()
    frame.switchAnim:Stop();
    frame.switchAnim:Play();
  end

  -- The interaction itself: the flash and icon pop, and the key cap's release with the ripple.
  --  Held key: the cap comes up now, while the key is still down. Holding the key long enough interacts
  --  without a key-up, and the cap stays up (cap.consumed) until the key is let go and pressed again.
  --  Just released (within RELEASE_GRACE): the game interacted on the key-up, so the ripple joins the
  --  spring-back that's already running.
  --  Otherwise a whole tap: a press KeyWatcher didn't see, another binding, the Edit Mode preview, or the
  --  game interacting again while the key stays held.
  local RELEASE_GRACE = 0.15;
  local samplePulseAt;
  local function PlayInteractPulse(source)
    if not EnhancedSoftInteractDB.animationsEnabled then return end
    -- A sample can animate key-up before the game sends its interaction event in the same frame.
    -- Keep that pulse instead of restarting it and pressing the key cap a second time.
    if source == "game" and samplePulseAt and GetTime() - samplePulseAt < RELEASE_GRACE then
      samplePulseAt = nil;
      return;
    end
    samplePulseAt = source == "sample_release" and GetTime() or nil;
    frame.pulse:Stop();
    frame.pulse:Play();
    frame.pulseUntil = GetTime() + PULSE_TIME;
    if cap.isDown and not cap.tapping then
      KeyUp(true);
      cap.consumed = true;
    elseif not cap.isDown and cap.releasedAt and GetTime() - cap.releasedAt < RELEASE_GRACE then
      cap.releasedAt = nil;
      PlayRipple();
    else
      TapKey();
      if cap.key and IsChordDown(cap.key) then cap.consumed = true; end
    end
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
    if not EnhancedSoftInteractDB.animationsEnabled then return 0, 0 end
    return FADE_IN_TIME, FADE_OUT_TIME;
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
    if duration <= 0 then
      if hideWhenDone then frame.fadingOut = false; frame:Hide(); else frame:Show(); end
      return;
    end
    frame:Show();
    frame.fadeAnim:SetFromAlpha(fromAlpha);
    frame.fadeAnim:SetToAlpha(toAlpha);
    frame.fadeAnim:SetDuration(duration);
    frame.fader:Play();
  end

  local function FadeTo(toAlpha, fullDuration, hideWhenDone)
    FadeOver(toAlpha, fullDuration * math.abs(toAlpha - CurrentAlpha()), hideWhenDone);
  end

  -- Range changes share the status timing, without a native fade restoring child opacity.
  local rangeFade = CreateTween();
  local function FadeRange(toAlpha, fromAlpha)
    rangeFade:Stop();
    frame:SetAlpha(fromAlpha);
    rangeFade:Play(0.25, function(t)
      t = t * t * (3 - 2 * t);
      frame:SetAlpha(fromAlpha + (toAlpha - fromAlpha) * t);
    end);
  end

  ----
  --  Layout
  ----

  -- The icon and the key cap sit at opposite ends of the box, EDGE_INSET from the edge. "Swap Icon and
  -- Key" (swapIconAndKey) swaps their ends. The name sits between them (UpdateLayout).
  local EDGE_INSET = 7;
  local function Inset(side) return side == "LEFT" and EDGE_INSET or -EDGE_INSET end

  -- Most cursor art isn't centered in its image. ns.iconArtOffsets (Helpers\Cursors.lua) has how far each
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
    local size = EnhancedSoftInteractDB.iconSize * Clamp(frame.glowScale or 1, GLOW_OUT_OF_RANGE_SCALE, 1);
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
    local style = ns.styles.Get();
    frame.iconGlow:SetShown(db.showIcon and style.layers and style.layers.iconGlow or false);
    SizeGlow();
    AnchorIcon(); --the nudge scales with the icon size
  end

  -- SetKeyCapText moves the key text off the cap's center. A font string centers its whole line, including
  -- the room for descenders, so capitals sit high. An "R" sat about 0.7 units high at font size 18, so the
  -- text moves down 0.04 font sizes. On screenshots, letters also sat 0.8 to 1.3 units left after InkOffset
  -- ("O", "R", "T"), so the text moves right by KEY_TEXT_NUDGE_X font sizes. WoW snaps text to whole pixels,
  -- so a letter can still land half a pixel off.
  local KEY_TEXT_NUDGE_X = 0.06;

  -- At 100%, the whole key art is max(24, fontSize + 9) x 1.3 tall and keeps its proportions. The cap frame
  -- (capWidth x capHeight, what the layout uses) is the key's face, and the art hangs past it by its
  -- margins. A label too wide for the face widens it to the text plus KEY_TEXT_PAD and stretches the art.
  -- A gamepad button comes from GetBindingText as one atlas markup ("|A:Gamepad_Gen_1_32:14:14|a"); the
  -- cap then draws that button's 64px glyph, which fills its square, in place of the key art. The glyph is
  -- GLYPH_SHARE of the key art's height: at the default font and key size that is 26 units, between the
  -- lines (30 units apart) and a little larger than the key face (23), because a round button looks smaller
  -- than a square key of the same height.
  local KEY_TEXT_PAD = 10;
  local GLYPH_SHARE = 0.77;
  local function SetKeyCapText(text)
    local db = EnhancedSoftInteractDB;
    local scale = db.keyScale / 100 * 1.3;
    local height = math.max(24, db.fontSize + 9) * scale;
    local glyph = text:match("^|A:([^:|]+):[^|]*|a$");
    glyph = glyph and glyph:gsub("_32$", "_64");
    if glyph and C_Texture.GetAtlasInfo(glyph) then
      cap.icon:SetAtlas(glyph);
      cap.icon:ClearAllPoints();
      cap.icon:SetAllPoints();
      cap.text:SetText("");
      cap.isGlyph = true;
      local size = height * GLYPH_SHARE;
      cap.capWidth, cap.capHeight = size, size;
      cap:SetSize(size, size);
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
    local text, key;
    if EnhancedSoftInteractDB.showKey then
      text, key = GetInteractKeyText();
      if not text and frame.sampleName then text = "F"; end --the Edit Mode sample shows "F" when the key is unbound
    end
    cap.key = key;
    cap:SetShown(text and true or false);
    if text then SetKeyCapText(text); end
  end

  -- Watches the interact key every frame while the key cap is showing, and presses the cap with it. Letting
  -- go comes up without a ripple; the interaction adds that (PlayInteractPulse). A key whose hold already
  -- interacted (cap.consumed) stays up until it's let go. While a text box has the keyboard (typing in
  -- chat), the key types instead, so the cap stays up. With animations off, or when the HUD goes away, a
  -- held cap comes up. An Edit Mode sample has no target for the game to interact with, so letting go of
  -- the key plays the whole interaction there, ripple, flash and icon pop included.
  local keyWatcher = CreateFrame("Frame");
  keyWatcher:SetScript("OnUpdate", function()
    local watching = cap.key and frame:IsShown() and not frame.fadingOut and cap:IsShown()
      and EnhancedSoftInteractDB.animationsEnabled
      and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus());
    if not watching then
      if cap.isDown and not cap.tapping then KeyUp(false); end
      cap.consumed = false;
      return;
    end
    if cap.tapping then return end
    local isDown = IsChordDown(cap.key);
    if cap.consumed then
      if not isDown then cap.consumed = false; end
    elseif isDown and not cap.isDown then
      KeyDown();
    elseif not isDown and cap.isDown then
      if frame.sampleName then PlayInteractPulse("sample_release"); else KeyUp(false); end
    end
  end);

  ----
  --  Name, requirement line and columns
  ----

  -- Range and profession messages share the compact name layout. Availability fades the message and
  -- restores the name's size and position without changing the HUD's height or measuring a secret region.
  local REQ_NAME_SCALE, REQ_TEXT_SCALE = 0.82, 0.65;
  local REQ_NAME_Y, REQ_TEXT_Y = 0.26, -0.41;
  local REQ_NAME_GREY = 0.8;
  local statusTween = CreateTween();
  local function PaintStatus(amount)
    local db = EnhancedSoftInteractDB;
    frame.statusAmount = amount;
    local c = frame.nameColor;
    frame.name:SetTextColor(c[1], c[2], c[3]);
    frame.compactName:SetTextColor(REQ_NAME_GREY, REQ_NAME_GREY, REQ_NAME_GREY);
    frame.nameOffsetY = db.fontSize * REQ_NAME_Y * amount;
    frame.name:SetPoint("CENTER", frame.box, "LEFT",
      frame.nameLeft + frame.nameWidth * 0.5, frame.nameOffsetY);
    frame.compactName:SetPoint("CENTER", frame.name, "CENTER");
    frame.name:SetAlpha(1 - amount);
    frame.compactName:SetAlpha(amount);
    frame.requirement:SetAlpha(amount);
    frame.requirement:SetShown(amount > 0);
    frame.statusShadow:SetAlpha(0.35 * amount);
    frame.statusShadow:SetShown(amount > 0);
  end

  local function StyleName(animate)
    local text = frame.outOfRange and "Move closer" or frame.requirementText;
    frame.showRequirement = text ~= nil;
    local to = text and 1 or 0;
    if not (animate and EnhancedSoftInteractDB.animationsEnabled and frame.statusAmount ~= nil) then
      statusTween:Stop();
      frame.statusTarget = to;
      PaintStatus(to);
    elseif frame.statusTarget ~= to then
      statusTween:Stop();
      frame.statusTarget = to;
      local from = frame.statusAmount;
      statusTween:Play(0.25, function(t)
        t = t * t * (3 - 2 * t);
        PaintStatus(from + (to - from) * t);
      end);
      PaintStatus(from);
    else
      PaintStatus(frame.statusAmount);
    end
  end

  -- The box is a table of three columns: icon | name | key cap (swapIconAndKey swaps the outer two). The icon
  -- and key columns are as wide as their contents plus COLUMN_GAP; an empty column takes no room. The name
  -- column fits the name (and the requirement line) between nameMinWidth and nameMaxWidth, and cuts a longer
  -- name short with "...". A secret name has a secret width; its column then takes nameMaxWidth.
  local COLUMN_GAP = 8;
  local function UpdateLayout(animate)
    local db = EnhancedSoftInteractDB;
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
    local nameWidth = FitWidth(frame.sampleName or UnitName("softInteract") or "", db.fontSize, minName);
    local text = frame.outOfRange and "Move closer" or frame.requirementText;
    local statusWidth = minName;
    if text then
      statusWidth = FitWidth(text, db.fontSize * REQ_TEXT_SCALE, 0);
      nameWidth = math.max(nameWidth, statusWidth);
    end
    -- Prepare the text and a full line before showing it, including the first target after /reload.
    if text then
      frame.requirement:SetText(text);
      if frame.outOfRange then
        frame.requirement:SetTextColor(1, 0.82, 0.35);
      else
        frame.requirement:SetTextColor(RED_FONT_COLOR:GetRGB());
      end
    end
    frame.requirement:SetFont(media:Fetch("font", db.font), db.fontSize * REQ_TEXT_SCALE);
    frame.requirement:ClearAllPoints();
    frame.requirement:SetPoint("LEFT", frame.box, "LEFT", EDGE_INSET + left, db.fontSize * REQ_TEXT_Y);
    frame.requirement:SetWidth(nameWidth);
    frame.requirement:SetHeight(math.ceil(db.fontSize * REQ_TEXT_SCALE * 1.5));
    frame.statusShadow:ClearAllPoints();
    frame.statusShadow:SetPoint("CENTER", frame.box, "LEFT", EDGE_INSET + left + nameWidth * 0.5, db.fontSize * REQ_TEXT_Y);
    frame.statusShadow:SetSize(statusWidth + 32, db.fontSize * REQ_TEXT_SCALE + 11);
    frame.name:ClearAllPoints();
    frame.name:SetFont(media:Fetch("font", db.font), db.fontSize);
    frame.name:SetWidth(nameWidth);
    frame.compactName:SetFont(media:Fetch("font", db.font), db.fontSize * REQ_NAME_SCALE);
    frame.compactName:SetWidth(nameWidth);
    local width = EDGE_INSET + left + nameWidth + right + EDGE_INSET;
    frame.box:SetWidth(width);
    frame.boxWidth, frame.nameWidth = width, nameWidth; --for /esi debug; reading them back could be secret
    frame.nameLeft = EDGE_INSET + left;
    StyleName(animate);
    ns.styles.Layout(frame);
    if frame.onLayout then frame.onLayout(width); end --the preview widens its window to fit the HUD
  end

  -- After a font or font size change, the name, key cap, columns and lines follow.
  local function UpdateFont()
    SetName(frame.sampleName or UnitName("softInteract"));
    UpdateKeyCap();
    UpdateLayout();
  end

  local function UpdateHeight()
    frame.box:SetHeight(EnhancedSoftInteractDB.hudHeight);
  end

  ----
  --  Colors
  ----

  -- Only a target you can interact with gets its type's color. In range but unable (such as a herb without
  -- Herbalism) is UNABLE_COLOR. Out of range is OUT_OF_RANGE_COLOR, the frame fades to OUT_OF_RANGE_ALPHA,
  -- and a shared status line explains why the interaction is unavailable.
  -- A texture's vertex alpha and its own alpha are one value, so an Alpha animation overwrites the
  -- vertex alpha set here. The switch animation fades the icon glow in to alpha 1, which left it at full
  -- strength instead of 0.6 until the next repaint (seen in game as a glow that's too strong after a
  -- target switch). The additive layers keep alpha 1 and carry their strength in the color instead;
  -- with ADD blending, color times strength at alpha 1 draws the same as color at that alpha. The flash
  -- uses a separate holder for animation alpha, so repainting cannot change its pulse opacity.
  local ICON_GLOW_STRENGTH, LINE_GLOW_STRENGTH = 0.6, 0.35;
  local function PaintColor(r, g, b)
    r, g, b = Clamp(r, 0, 1), Clamp(g, 0, 1), Clamp(b, 0, 1);
    local s = ICON_GLOW_STRENGTH;
    frame.iconGlow:SetVertexColor(r * s, g * s, b * s, 1);
    frame.lineLow:SetVertexColor(r, g, b, 1);
    s = LINE_GLOW_STRENGTH;
    frame.lineLowGlow:SetVertexColor(r * s, g * s, b * s, 1);
    ns.styles.Paint(frame, r, g, b);
  end

  -- Sets the colors, the key label and the glow size from frame.colorKey and frame.outOfRange. With blend
  -- (the HUD is visible), the glow animates, and with animations on the color blends over SWITCH_TIME from
  -- wherever it is now, also from the middle of a running blend.
  local colorTween = CreateTween();
  local function SetTypeColor(blend)
    blend = blend and EnhancedSoftInteractDB.animationsEnabled;
    PaintKeyCap();
    SetGlowScale(frame.outOfRange and GLOW_OUT_OF_RANGE_SCALE or 1, blend);
    local to = { GetTypeColor(frame.colorKey, frame.outOfRange) };
    if not (blend and EnhancedSoftInteractDB.animationsEnabled and frame.rgb) then
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

  local function UpdateShadow()
    frame.shadow:SetVertexColor(0, 0, 0, Clamp(EnhancedSoftInteractDB.shadowStrength / 100, 0, 1));
    frame.shadow:SetShown(ns.styles.Get().shadow == true);
  end

  -- Each style owns its appearance; targeting, columns and animations stay shared.
  local function ApplyTextures()
    frame.shadow:SetTexture(SHADOW);
    UpdateShadow();
    frame.iconGlow:SetTexture(GLOW);
    ns.styles.Apply(frame);
  end

  local function UpdateStyle()
    ApplyTextures();
    UpdateLayout();
    UpdateColors();
  end

  ----
  --  Showing a cursor and the soft target handler
  ----

  -- Shows a cursor by name ("Skin", "UnableSpeak") on the icon and returns its key in the type-color
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

  local function OnSoftTargetCleared()
    frame.lastTarget, frame.lastSignature, frame.lastAction = nil, nil, nil;
    -- A running interact pulse finishes before the fade-out (looting clears the target at once).
    local wait = frame.pulseUntil - GetTime();
    local token = frame.fadeToken;
    local function FadeOut()
      if token == frame.fadeToken and frame:IsShown() and not frame.fadingOut then
        rangeFade:Stop();
        FadeTo(0, select(2, GetFadeTimes()), true);
      end
    end
    if wait > 0 then C_Timer.After(wait, FadeOut); else FadeOut(); end
  end

  local function OnSoftTargetChanged(newTarget)
    local target = ns.ResolveTarget(frame.icon, newTarget, frame.inRangeTarget);
    frame.targetState = target;
    frame.iconSource, frame.iconFromFileID = target.iconSource, target.iconFromFileID;
    frame.inRangeTarget = target.inRangeTarget;
    if target.overrideCursor then ShowCursor(target.overrideCursor); end
    SetName(target.name);
    local knownTarget, iconKey, outOfRange = target.knownTarget, target.iconKey, target.outOfRange;
    local signature = target.signature;
    if knownTarget and knownTarget == frame.lastTarget and signature == frame.lastSignature
        and frame:IsShown() and not frame.fadingOut then return target, false; end
    UpdateKeyCap(); --bindings and text measurement are unchanged during repeat range checks
    -- It's a switch when the visible frame changes to another target or another action, not only its range.
    local action = target.action;
    local visible = frame:IsShown() and not frame.fadingOut;
    local switched = visible and (action ~= frame.lastAction or not knownTarget or knownTarget ~= frame.lastTarget);
    frame.lastTarget, frame.lastSignature, frame.lastAction = knownTarget, signature, action;

    -- A visible HUD dims or brightens with its status transition. A short fade-in time
    -- would otherwise drop it from 1 to 0.75 in about 0.02 seconds while the colors still blend.
    local toAlpha = outOfRange and OUT_OF_RANGE_ALPHA or IN_RANGE_ALPHA;
    local fromAlpha = CurrentAlpha();
    rangeFade:Stop();
    frame.fader:Stop(); --settle native animation state before painting the new status
    frame.fadingOut = false;
    frame.colorKey, frame.outOfRange = iconKey, outOfRange;
    frame.requirementText = target.requirementText;
    UpdateLayout(visible and not switched);
    AnchorIcon();
    SetTypeColor(visible); --blend while the frame is up, set at once when it fades in
    -- Prepare child opacity before the HUD fade starts. Otherwise its completion can restore
    -- the hidden status opacity from before this target was laid out.
    if visible and EnhancedSoftInteractDB.animationsEnabled then
      FadeRange(toAlpha, fromAlpha);
    else
      FadeTo(toAlpha, (GetFadeTimes()), false);
    end
    if switched and EnhancedSoftInteractDB.animationsEnabled then PlaySwitchAnim(); end

    return target, true;
  end

  -- When the HUD hides, every animation stops and its values go back to rest, so nothing half-finished
  -- carries over to the next target. Without a stored glow size and color, the next target sets both at
  -- once instead of animating from stale values.
  local function ResetAnimations()
    for _, group in ipairs({ frame.pulse, frame.switchAnim, frame.ripple, frame.pressIn, frame.pressOut }) do
      group:Stop();
    end
    glowTween:Stop();
    colorTween:Stop();
    depthTween:Stop();
    statusTween:Stop();
    rangeFade:Stop();
    tapToken = tapToken + 1; --cancels a pending tap release
    ClearPulseLight();
    frame.pulseUntil = 0;
    samplePulseAt = nil;
    frame.glowScale, frame.rgb, glowTarget = nil, nil, nil;
    cap.isDown, cap.tapping, cap.consumed, cap.releasedAt = false, false, false, nil;
    cap.pressDepth, cap.pressShade = 0, 1; --the key cap repaints with the next target (SetTypeColor)
    frame.statusAmount, frame.statusTarget = nil, nil;
  end
  frame:HookScript("OnHide", ResetAnimations);

  -- Native animations can finish after the range has changed. Restore the current appearance,
  -- rather than leaving a previously captured opacity on the icon or name.
  local function SettleAppearance()
    if not frame:IsShown() or frame.fadingOut or not frame.nameLeft then return end
    frame.icon:SetAlpha(1);
    frame.nameHolder:SetAlpha(1);
    SetTypeColor(false);
    if not statusTween:GetScript("OnUpdate") then PaintStatus(frame.statusAmount or 0); end
    if not rangeFade:GetScript("OnUpdate") and not frame.fader:IsPlaying() then
      frame:SetAlpha(frame.sampleName and 1 or (frame.outOfRange and OUT_OF_RANGE_ALPHA or IN_RANGE_ALPHA));
    end
  end
  frame.pulse:SetScript("OnFinished", function()
    ClearPulseLight();
    SettleAppearance();
  end);
  frame.switchAnim:SetScript("OnFinished", SettleAppearance);
  local fadeFinished = frame.fader:GetScript("OnFinished");
  frame.fader:SetScript("OnFinished", function()
    fadeFinished();
    SettleAppearance();
  end);

  -- Turning animations off also settles effects that are already playing on either HUD.
  local function UpdateAnimations()
    if EnhancedSoftInteractDB.animationsEnabled then return end
    local hiding = frame.fadingOut or (not frame.sampleName and not frame.targetState);
    frame.fadeToken = (frame.fadeToken or 0) + 1;
    ResetAnimations();
    frame.fader:Stop();
    frame.fadingOut = false;
    if hiding then
      frame:Hide();
    else
      frame:SetAlpha(frame.sampleName and 1 or (frame.outOfRange and OUT_OF_RANGE_ALPHA or IN_RANGE_ALPHA));
      SetTypeColor(false);
      UpdateLayout();
    end
  end

  -- Shows a made-up target in Edit Mode: a name, a cursor by name ("Skin", "UnableGatherHerbs") and an
  -- optional requirement line, fully visible and in range.
  local function ShowSample(name, cursor, requirementText)
    rangeFade:Stop();
    frame.fader:Stop();
    frame.fadingOut = false;
    frame:SetAlpha(1);
    frame:Show();
    frame.sampleName = name;
    SetName(name);
    frame.requirementText = requirementText;
    frame.colorKey, frame.outOfRange = ShowCursor(cursor), false;
    SetTypeColor(true);
    if EnhancedSoftInteractDB.animationsEnabled then PlaySwitchAnim(); end
    AnchorIcon();
    UpdateKeyCap();
    UpdateLayout();
  end

  -- Applies every setting to the HUD (on load, and when the preview is built).
  local function ApplyAllSettings()
    ApplyTextures();
    StyleKeyCap();
    SetIconSide();
    UpdateIcon();
    UpdateFont();
    UpdateHeight();
    UpdateColors();
  end

  return {
    frame = frame, ApplyAllSettings = ApplyAllSettings, ShowSample = ShowSample,
    OnSoftTargetChanged = OnSoftTargetChanged, OnSoftTargetCleared = OnSoftTargetCleared,
    PlayInteractPulse = PlayInteractPulse, UpdateColors = UpdateColors, UpdateAnimations = UpdateAnimations,
    SetIconSide = SetIconSide, UpdateIcon = UpdateIcon, UpdateFont = UpdateFont, UpdateHeight = UpdateHeight,
    UpdateKeyCap = UpdateKeyCap, UpdateLayout = UpdateLayout, UpdateStyle = UpdateStyle, UpdateShadow = UpdateShadow,
  };
end

----
--  The HUD frame. Edit Mode moves it (LibEditMode, Feat\EditMode.lua), and each Edit Mode layout keeps
--  its own position in EnhancedSoftInteractDB.layouts. Outside Edit Mode it ignores the mouse.
----
local HUD_DEFAULT_POSITION = { point = "CENTER", x = 200, y = -100 };
local frame = CreateFrame("Frame", "EnhancedSoftInteractHUD", UIParent);
local hud = CreateHUD(frame);
local huds = { hud }; --the real HUD and, once Edit Mode builds it, the preview
frame:SetSize(200, 40);
frame:SetPoint(HUD_DEFAULT_POSITION.point, UIParent, HUD_DEFAULT_POSITION.point, HUD_DEFAULT_POSITION.x, HUD_DEFAULT_POSITION.y);
frame:SetMovable(true);
frame:SetDontSavePosition(true); --Edit Mode layouts hold the position, not WoW's layout-local.txt
frame:EnableMouse(false);
frame:Hide();
frame.editModeName = "Enhanced Soft Interact";

-- With the addon disabled (Enabled in Edit Mode), every target counts as none.
local function OnSoftInteractChanged(oldTarget, newTarget)
  if frame.inEditMode then
    if ns.DebugSoftTarget then ns.DebugSoftTarget(oldTarget, newTarget, nil, "edit_mode"); end
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
  -- Always retain game events, including clears and repeats; unchanged range polls stay silent.
  if ns.DebugSoftTarget and (not frame.fromRangeCheck or changed) then
    ns.DebugSoftTarget(oldTarget, newTarget, target, EnhancedSoftInteractDB.enabled and "active" or "disabled");
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

-- Runs one of the HUD functions on every HUD, so a setting changes the real HUD and the preview alike.
local function OnEveryHUD(name)
  return function(...)
    for _, h in ipairs(huds) do h[name](...); end
  end
end

-- Builds the Edit Mode preview's HUD on frame (Feat\EditMode.lua), once the settings are loaded.
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
  db.editModeSections = db.editModeSections or {};
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

-- /esi opens the HUD in Edit Mode (Feat\EditMode.lua); the Feat files add subcommands to ns.slashCommands.
SLASH_ENHANCEDSOFTINTERACT1 = "/esi";
function SlashCmdList.ENHANCEDSOFTINTERACT(msg)
  local command = ns.slashCommands[strtrim(msg or ""):lower()];
  if command then command(); elseif ns.OpenHUDInEditMode then ns.OpenHUDInEditMode(); end
end

-- Shared with the Feat files. The Update functions and ShowSample run on every HUD.
ns.frame, ns.media, ns.AddHUD = frame, media, AddHUD;
ns.DEFAULTS, ns.SLIDER_RANGES, ns.HUD_DEFAULT_POSITION = DEFAULTS, SLIDER_RANGES, HUD_DEFAULT_POSITION;
ns.Notify, ns.issecretvalue = Notify, issecretvalue;
ns.RefreshKeyCap = RefreshKeyCap;
for _, name in ipairs({ "ShowSample", "PlayInteractPulse", "UpdateColors", "SetIconSide", "UpdateIcon",
    "UpdateFont", "UpdateHeight", "UpdateKeyCap", "UpdateLayout", "UpdateAnimations", "UpdateStyle", "UpdateShadow" }) do
  ns[name] = OnEveryHUD(name);
end
