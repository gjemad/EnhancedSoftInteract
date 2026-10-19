local ADDON_NAME, ns = ...; --the addon folder name, and the table this addon's files share
local media = LibStub:GetLibrary("LibSharedMedia-3.0", true);
media:Register("font", "PT Sans Narrow", [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\Fonts\PTSansNarrow-Regular.ttf]]);

-- Fallbacks for APIs that some clients lack.
local issecretvalue = issecretvalue or function() return false end;

-- The Feat files add functions to run once the saved settings are ready, and /esi subcommands.
ns.onLoad = {};
ns.slashCommands = {};

local NormalizeCursorKey, ColorKeyFor = ns.NormalizeCursorKey, ns.ColorKeyFor;
local GetTypeColor = ns.GetTypeColor;

-- Every chat message of the addon starts with "Enhanced Soft Interact:".
local function Notify(msg) print("|cffffd100Enhanced Soft Interact:|r " .. msg) end

-- Saved-setting defaults. LoadSettings fills in unset keys from here.
local DEFAULTS = {
  enabled = true, showBlizzardTooltip = false, showBlizzardIcons = true,
  forceInteractKey = true, forceInteractIcons = true,
  showIcon = true, elvShowIcon = false, swapIconAndKey = false, showKey = true, hudSize = "normal", colorBrightness = 100,
  animationsEnabled = true, castBarEnabled = true, castBarHideGame = true, castBarClicked = false, hudStyle = "levelup", shadowStrength = 90,
  -- Retail defaults to Plunderstorm keys; Forever and the Classic clients default to the Classic keys.
  elvFont = "PT Sans Narrow", keyStyle = select(4, GetBuildInfo()) >= 100000 and "plunderstorm" or "classic",
  buttonSizePercent = 100, interactionIconSizePercent = 100,
};
-- Each settings slider's {min, max, step}.
local SLIDER_RANGES = {
  colorBrightness = {30, 100, 5}, shadowStrength = {0, 100, 5},
  buttonSizePercent = {75, 125, 5}, interactionIconSizePercent = {75, 125, 5},
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
--  spaces the visible key like the icon, and the art's margins hang outside the frame. bottomBorder is the
--  center of the face's bottom border line as a share of the art's height (rows 79-80 of 96, the same art
--  on Forever and Era); fitted input sizes and their text fields use this reference.
----
local KEYCAP_STYLES = { --in order of preference
  { atlas = "plunderstorm-icon-key", textColor = {1, 1, 1}, shadow = true,
    margins = {16 / 108, 16 / 96, 15 / 108, 15 / 96}, topBorder = 16 / 96, bottomBorder = 80 / 96 },
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
--  CreateHUD builds the real HUD and UI previews. Each owns its textures, animations and state.
----
local function CreateHUD(frame)
  -- frame.box is the layout box (icon | name | key, hudHeight tall) that everything anchors to. It draws
  -- nothing itself.
  frame.box = frame:CreateTexture(nil, "BACKGROUND");
  frame.box:SetPoint("CENTER"); --layout keeps the name column centered on the HUD
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
  local function SetName(text)
    frame.name:SetText(text);
    frame.compactName:SetText(text);
  end
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
  if ns.ModifierKey then ns.ModifierKey.Create(cap); end

  local function KeyboardArt()
    for _, style in ipairs(KEYCAP_STYLES) do
      local info = C_Texture.GetAtlasInfo(style.atlas);
      if info and info.width > 0 and info.height > 0 then
        return { aspect = info.width / info.height, margins = style.margins or NO_MARGINS,
          topBorder = style.topBorder, bottomBorder = style.bottomBorder }, style;
      end
    end
    return { aspect = 1, margins = NO_MARGINS };
  end

  -- Styles the cap with the first key art this client has, else a plain dark box. cap.art keeps the art's
  -- proportions and face margins for SetKeyCapText.
  local function StyleKeyCap()
    cap.isGlyph = false;
    cap.styleArt = ns.styles.Get();
    cap.keyStyle = EnhancedSoftInteractDB.keyStyle;
    cap.classic = not cap.styleArt.ownKey and cap.keyStyle == "classic";
    cap.classicCanvasWidth, cap.classicCanvasHeight, cap.classicCanvasOffsetY = nil, nil, nil;
    for _, slices in ipairs(cap.classicButton or {}) do
      for _, texture in ipairs(slices) do texture:Hide(); end
    end
    if cap.classic then
      -- Both keyboard choices share the selected native reference's logical face and border anchors.
      -- Classic's transparent source padding belongs to its drawing canvas, not to that layout face.
      local reference = KeyboardArt();
      local m = reference.margins;
      local faceShareX, faceShareY = 1 - m[1] - m[3], 1 - m[2] - m[4];
      cap.art = { aspect = reference.aspect * faceShareX / faceShareY, margins = NO_MARGINS };
      if reference.bottomBorder then
        cap.art.topBorder = ((reference.topBorder or m[2]) - m[2]) / faceShareY;
        cap.art.bottomBorder = (reference.bottomBorder - m[2]) / faceShareY;
      end
      cap.icon:SetColorTexture(0, 0, 0, 0);
      cap.icon:SetTexCoord(0, 1, 0, 1);
      cap.textColor = {1, 1, 1};
      cap.text:SetShadowOffset(1, -1);
      if not cap.classicButton then
        cap.classicButton = {};
        for state, file in ipairs({[[Interface\Buttons\UI-Panel-Button-Up]], [[Interface\Buttons\UI-Panel-Button-Down]]}) do
          local slices = {};
          cap.classicButton[state] = slices;
          for i, coords in ipairs({{0, 0.09375}, {0.09375, 0.53125}, {0.53125, 0.625}}) do
            -- Down draws above Up; textures sharing a sublevel have no guaranteed order.
            local texture = cap:CreateTexture(nil, "ARTWORK", nil, state);
            texture:SetTexture(file);
            texture:SetTexCoord(coords[1], coords[2], 0, 0.6875);
            texture:SetDesaturated(true);
            slices[i] = texture;
          end
        end
      end
      return;
    end
    if ns.styles.Get().flatKey then
      cap.art = { aspect = 1, margins = NO_MARGINS };
      local data = ns.ElvTheme.Media();
      local background = data and data.backdropcolor or {0.1, 0.1, 0.1};
      cap.icon:SetColorTexture(background[1] * 0.6, background[2] * 0.6, background[3] * 0.6, 1);
      cap.icon:SetTexCoord(0, 1, 0, 1);
      cap.textColor = {1, 1, 1};
      cap.text:SetShadowOffset(0, 0);
      if cap.icon.SetRoundLayoutToNearestPixel then cap.icon:SetRoundLayoutToNearestPixel(false); end
      if cap.icon.SetSnapToPixelGrid then cap.icon:SetSnapToPixelGrid(false); end
      if cap.icon.SetTexelSnappingBias then cap.icon:SetTexelSnappingBias(0); end
      return;
    end
    if cap.icon.SetRoundLayoutToNearestPixel then cap.icon:SetRoundLayoutToNearestPixel(false); end
    if cap.icon.SetSnapToPixelGrid then cap.icon:SetSnapToPixelGrid(true); end
    if cap.icon.SetTexelSnappingBias then cap.icon:SetTexelSnappingBias(0.5); end
    local art, style = KeyboardArt();
    cap.art = art;
    if style then
      cap.icon:SetAtlas(style.atlas);
      cap.textColor = style.textColor;
      cap.text:SetShadowOffset(style.shadow and 1 or 0, style.shadow and -1 or 0);
      return;
    end
    cap.icon:SetColorTexture(0, 0, 0, 0.6);
    cap.textColor = {1, 1, 1};
    cap.text:SetShadowOffset(1, -1);
  end

  -- A blocked interaction dims the input; the status line explains why. Press shading still applies.
  local WHITE = {1, 1, 1};
  local function PaintKeyCap()
    for state, slices in ipairs(cap.classicButton or {}) do
      for _, texture in ipairs(slices) do
        local tint = (cap.pressShade or 1) * ((frame.outOfRange or frame.requirementText ~= nil) and 0.7 or 1);
        texture:SetVertexColor(tint, tint * 0.98, tint * 0.93, 1);
        texture:SetAlpha(state == 1 and 1 or (cap.pressDepth or 0));
        texture:SetShown(cap.classic and cap:IsShown() and not cap.isGlyph and (texture.classicWidth or 0) > 0);
      end
    end
    if cap.classic and not cap.isGlyph and cap.textX then
      cap.text:SetPoint("CENTER", cap.textX, cap.textY - (cap.pressDepth or 0));
    end
    if ns.styles.Get().flatKey and not cap.isGlyph then
      local data = ns.ElvTheme.Media();
      local bg = data and data.backdropcolor or {0.1, 0.1, 0.1};
      cap.icon:SetColorTexture(bg[1] * 0.6, bg[2] * 0.6, bg[3] * 0.6, 1);
      cap.icon:SetVertexColor(1, 1, 1, 1);
      local shade = (frame.outOfRange or frame.requirementText) and 0.75 or 1;
      cap.text:SetTextColor(shade, shade, shade);
      local style = ns.styles.Get();
      if style.PaintKeyCap then style.PaintKeyCap(frame, cap); end
      if ns.ModifierKey then ns.ModifierKey.Paint(frame); end
      return;
    end
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
    local style = ns.styles.Get();
    if style.PaintKeyCap then style.PaintKeyCap(frame, cap, shade, blocked); end
    if ns.ModifierKey then ns.ModifierKey.Paint(frame); end
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
    if ns.styles.Get().flatKey then return 1 end
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

  -- Finish with explicit idle values rather than relying on a native effect's captured starting state.
  frame.pressOut:SetScript("OnFinished", function()
    if cap.isDown or cap.tapping then return end
    depthTween:Stop();
    cap.pressDepth, cap.pressShade = 0, 1;
    PaintKeyCap();
  end);
  local function ClearKeyRipple() cap.ring:SetAlpha(0); end
  frame.ripple:SetScript("OnFinished", ClearKeyRipple);
  frame.ripple:SetScript("OnStop", ClearKeyRipple);

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
    if ns.styles.Get().flatKey then return end
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

  -- Stop before changing status opacity: native animation restoration can otherwise bring back
  -- the previous target's normal/compact text. Start only after the new layout is ready.
  local function StopSwitchAnim()
    frame.switchAnim:Stop();
    frame.icon:SetAlpha(1);
    frame.nameHolder:SetAlpha(1);
    frame.iconGlow:SetAlpha(1);
  end

  local function PlaySwitchAnim()
    if not EnhancedSoftInteractDB.animationsEnabled then return end
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

  -- Invisible fixed-size side cells center the icon and key independently of their artwork.
  -- Swap Icon and Key swaps the complete cells. A hidden cell becomes the shared edge padding.
  local function Inset(side)
    local half = ns.styles.CellCenter(EnhancedSoftInteractDB);
    return side == "LEFT" and half or -half;
  end

  -- Most cursor art isn't centered in its image. IconArtOffset picks the measurements for the actual
  -- mouse or crosshair artwork, in 64px units; the icon moves the other way. AnchorIcon
  -- rounds the nudge to whole units, because the renderer may snap a fractional nudge away. Every client
  -- keeps a full iconSize column and centers the visible art in it: Forever's crosshair art and Era's
  -- native mouse cursors (Cursors.lua, triangle included).
  local function AnchorIcon()
    local side = EnhancedSoftInteractDB.swapIconAndKey and "RIGHT" or "LEFT";
    local key = frame.colorKey and NormalizeCursorKey(frame.colorKey);
    local offset = key and ns.IconArtOffset(frame.icon, key, frame.iconFromFileID);
    local nudgeX, nudgeY = 0, 0;
    local width, height = ns.styles.IconDimensions(frame, EnhancedSoftInteractDB);
    if offset then
      local function Round(v) return v >= 0 and math.floor(v + 0.5) or -math.floor(-v + 0.5) end
      nudgeX, nudgeY = Round(-offset[1] * width / 64), Round(offset[2] * height / 64);
    end
    frame.iconNudgeX, frame.iconNudgeY = nudgeX, nudgeY; --for /esi debug
    local centerY = ns.styles.ContentCenterY(frame, EnhancedSoftInteractDB);
    frame.iconCenterY = centerY;
    frame.icon:SetSize(width, height);
    frame.iconColumnWidth = width;
    frame.icon:ClearAllPoints();
    frame.icon:SetPoint("CENTER", frame.box, side, Inset(side) + nudgeX, centerY + nudgeY);
  end

  local function SetIconSide()
    local keySide = EnhancedSoftInteractDB.swapIconAndKey and "LEFT" or "RIGHT";
    AnchorIcon();
    cap:ClearAllPoints();
    local style = ns.styles.Get();
    cap:SetPoint("CENTER", frame.box, keySide, Inset(keySide), style.KeyOffsetY and style.KeyOffsetY(frame, EnhancedSoftInteractDB) or 0);
  end

  -- The glow behind the icon is GLOW_W x GLOW_H icon sizes in range and shrinks to GLOW_OUT_OF_RANGE_SCALE
  -- of that out of range. While the HUD is visible it gets there over GLOW_TIME, easing out from its
  -- current size, so a range change halfway reverses smoothly. It resizes the texture instead of using a
  -- Scale animation, so repeated changes can't add up.
  local GLOW_W, GLOW_H = 2.2, 1.9;
  local GLOW_OUT_OF_RANGE_SCALE = 0.55;
  local GLOW_TIME = 0.25;
  local function SizeGlow()
    local width, height = ns.styles.IconDimensions(frame, EnhancedSoftInteractDB);
    local scale = Clamp(frame.glowScale or 1, GLOW_OUT_OF_RANGE_SCALE, 1);
    frame.iconGlow:SetSize(width * scale * GLOW_W, height * scale * GLOW_H);
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
    frame.icon:SetShown(ns.styles.ShowIcon(db));
    local style = ns.styles.Get();
    frame.iconGlow:SetShown(ns.styles.ShowIcon(db) and style.layers and style.layers.iconGlow or false);
    SizeGlow();
    AnchorIcon(); --the nudge scales with the icon size
  end

  -- SetKeyCapText moves the key text off the cap's center. A font string centers its whole line, including
  -- the room for descenders, so capitals sit high. The text moves down 0.04 font sizes
  -- and right by KEY_TEXT_NUDGE_X font sizes to center the visible letters. WoW snaps text to whole pixels,
  -- so a letter can still land half a pixel off.
  local KEY_TEXT_NUDGE_X = 0.06;

  -- Each style's size profile owns the key face, glyph and lettering heights. Keyboard labels fit
  -- their natural F face; controller chords retain room to widen without moving vertical anchors.
  local KEY_TEXT_PAD = 10;
  -- Composite glyphs stay inside the shared keycap. Their explicit atlas sizes do not follow SetFont.
  local function ScaleGamepadText(text, scale, limit)
    local tallest = 0;
    for height in text:gmatch("|A:Gamepad_[^:|]+:([^:|]*)") do
      tallest = math.max(tallest, (tonumber(height) or 0) * scale);
    end
    if tallest > limit then scale = scale * limit / tallest; end
    text = text:gsub("(|A:Gamepad_[^:|]+:)([^:|]*):([^:|]*)([^|]*|a)", function(prefix, height, width, suffix)
      local h, w = tonumber(height), tonumber(width);
      -- Zero or omitted dimensions let the font choose the size. Preserve atlas offsets and artwork.
      if h and h > 0 then height = h * scale; end
      if w and w > 0 then width = w * scale; end
      return prefix .. height .. ":" .. width .. suffix;
    end);
    return text;
  end
  local function SetKeyCapText(text)
    local db = EnhancedSoftInteractDB;
    local style = ns.styles.Get();
    local size = ns.styles.Size(db);
    local buttonScale = ns.styles.ButtonScale(db);
    if style.KeyText then text = style.KeyText(frame, text); end
    if cap.isGlyph or cap.styleArt ~= style or cap.keyStyle ~= db.keyStyle then StyleKeyCap(); end
    local managed = ns.ModifierKey and ns.ModifierKey.Prepare(frame, cap.key, text) or false;
    local glyph = text:match("^|A:([^:|]+):[^|]*|a$");
    glyph = glyph and glyph:gsub("_32$", "_64");
    if glyph and C_Texture.GetAtlasInfo(glyph) then
      cap.icon:SetAtlas(glyph);
      cap.icon:ClearAllPoints();
      cap.icon:SetAllPoints();
      cap.text:SetText("");
      cap.isGlyph = true;
      local height = ns.styles.KeyFaceHeight(frame, db, true);
      cap.capWidth, cap.capHeight = height, height;
      cap:SetSize(height, height);
      cap.cellScale = math.min(1, ns.styles.CellSize(db) / height);
      cap:SetScale(cap.cellScale);
      PaintKeyCap();
      return;
    end
    local m = cap.art.margins;
    local faceShareX, faceShareY = 1 - m[1] - m[3], 1 - m[2] - m[4];
    local faceHeight = ns.styles.KeyFaceHeight(frame, db, false);
    local height = faceHeight / faceShareY;
    local gamepadText = text:find("|A:Gamepad_", 1, true);
    if gamepadText then text = ScaleGamepadText(text, size.inputScale * buttonScale, faceHeight - 2 * size.inputScale * buttonScale); end
    local fontPath = ns.styles.Font(db);
    local fontSize = size.keyFontSize * buttonScale;
    cap.text:SetFont(fontPath, fontSize, ns.styles.FontFlags());
    local textNudge = style.flatKey and 0 or KEY_TEXT_NUDGE_X;
    cap.textX = gamepadText and 0 or fontSize * (textNudge - InkOffset(text, fontPath));
    cap.textY = gamepadText and 0 or -fontSize * 0.04;
    cap.text:SetPoint("CENTER", cap.textX, cap.textY);
    cap.text:SetText(text);
    keyTextMeasure:SetFont(fontPath, fontSize, ns.styles.FontFlags());
    keyTextMeasure:SetText(managed and "F" or text);
    local textWidth = keyTextMeasure:GetStringWidth();
    if issecretvalue(textWidth) then textWidth = fontSize * #(managed and "F" or text) * 0.6; end --rough estimate; not seen yet
    if style.KeyWidth and not managed then textWidth = math.max(textWidth, style.KeyWidth(frame, height)); end
    local naturalWidth = height * cap.art.aspect * faceShareX;
    cap.capWidth = managed and naturalWidth or math.max(naturalWidth,
      textWidth + (style.keyTextPadding or KEY_TEXT_PAD) * 1.3 * size.inputScale * buttonScale);
    cap.capHeight = faceHeight;
    if style.Pixel then
      local pixel = style.Pixel(frame);
      cap.capWidth = math.floor(cap.capWidth / pixel + 0.5) * pixel;
      cap.capHeight = math.floor(cap.capHeight / pixel + 0.5) * pixel;
      height = cap.capHeight / faceShareY;
    end
    cap:SetSize(cap.capWidth, cap.capHeight);
    -- Fit the visible input face uniformly inside its fixed cell. Native shadow margins do not alter
    -- the matched keyboard face size. Press effects animate children and retain this base scale.
    local cell = ns.styles.CellSize(db);
    cap.cellScale = math.min(1, cell / cap.capWidth, cell / cap.capHeight);
    if style.flatKey then cap.cellScale = 1; end --Elv fits its owned input before physical-pixel snapping
    cap:SetScale(cap.cellScale);
    local artWidth = cap.capWidth / faceShareX;
    cap.icon:ClearAllPoints();
    cap.icon:SetPoint("TOPLEFT", -m[1] * artWidth, m[2] * height);
    cap.icon:SetPoint("BOTTOMRIGHT", m[3] * artWidth, -m[4] * height);
    if cap.classic then
      local canvasWidth, canvasHeight = cap.capWidth + 4 * cap.capHeight / 19, cap.capHeight * 22 / 19;
      -- Very narrow plain fallbacks meet at their center; keep the two native end pieces proportional.
      if cap.capWidth < 20 * cap.capHeight / 19 then canvasWidth = cap.capWidth * 6 / 5; end
      local offsetY, edge = cap.capHeight / 38, math.min(canvasWidth * 0.5, cap.capHeight * 12 / 19);
      cap.classicCanvasWidth, cap.classicCanvasHeight, cap.classicCanvasOffsetY = canvasWidth, canvasHeight, offsetY;
      local widths = {edge, math.max(0, canvasWidth - edge * 2), edge};
      local lefts = {0, edge, canvasWidth - edge};
      for _, slices in ipairs(cap.classicButton) do
        for i, texture in ipairs(slices) do
          texture:ClearAllPoints();
          texture:SetPoint("LEFT", cap, "CENTER", -canvasWidth * 0.5 + lefts[i], offsetY);
          texture:SetSize(math.max(0.01, widths[i]), canvasHeight);
          texture.classicWidth = widths[i];
        end
      end
    end
    if ns.ModifierKey then ns.ModifierKey.Layout(frame, db); end
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
    if text then SetKeyCapText(text);
    else
      if ns.ModifierKey then ns.ModifierKey.Prepare(frame, nil, nil); end
      PaintKeyCap();
    end
  end

  -- Watches the interact key every frame while the key cap is showing, and presses the cap with it. Letting
  -- go comes up without a ripple; the interaction adds that (PlayInteractPulse). A key whose hold already
  -- interacted (cap.consumed) stays up until it's let go. While a text box has the keyboard (typing in
  -- chat), the key types instead, so the cap stays up. With animations off, or when the HUD goes away, a
  -- held cap comes up. An Edit Mode sample has no target for the game to interact with, so letting go of
  -- the key plays the whole interaction there, ripple, flash and icon pop included.
  local keyWatcher = CreateFrame("Frame", nil, frame);
  keyWatcher:SetScript("OnUpdate", function(_, elapsed)
    local watching = cap.key and frame:IsShown() and not frame.fadingOut
      and cap:IsShown()
      and EnhancedSoftInteractDB.animationsEnabled
      and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus());
    if ns.ModifierKey then ns.ModifierKey.Poll(frame, watching, elapsed); end
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
  -- blends fixed-size labels on one moving anchor without changing the HUD's height or measuring
  -- a secret region. Keep font sizes fixed so glyph rasterization cannot step during the transition.
  local REQ_NAME_SCALE, REQ_TEXT_SCALE = 0.82, 0.65;
  local REQ_TEXT_Y = -0.41;
  local REQ_NAME_GREY = 0.8;
  local statusTween = CreateTween();
  local function PaintStatus(amount)
    local db = EnhancedSoftInteractDB;
    frame.statusAmount = amount;
    local c = frame.nameColor;
    frame.name:SetTextColor(c[1], c[2], c[3]);
    frame.compactName:SetTextColor(REQ_NAME_GREY, REQ_NAME_GREY, REQ_NAME_GREY);
    frame.nameOffsetY = ns.styles.NameOffset(frame, db, amount);
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
    local text = frame.requirementText or (frame.outOfRange and "Move closer");
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
  local function UpdateLayout(animate)
    local db = EnhancedSoftInteractDB;
    local minName = ns.styles.NameMinWidth(db);
    local maxName = math.max(minName, ns.styles.Size(db).nameMaxWidth);
    AnchorIcon();
    local cell = ns.styles.CellSize(db);
    local padding = ns.styles.SidePadding(db);
    local left = ns.styles.ShowIcon(db) and cell or padding;
    local right = cap:IsShown() and cell or padding;
    if db.swapIconAndKey then left, right = right, left; end
    local style = ns.styles.Get();
    local edgeLeft, edgeRight = 0, 0;
    frame.cellSize, frame.sidePadding = cell, padding;
    frame.leftCellWidth, frame.rightCellWidth = left, right;
    local function FitWidth(text, size, width)
      nameMeasure:SetFont(ns.styles.Font(db), size, ns.styles.FontFlags());
      nameMeasure:SetText(text);
      local textWidth = nameMeasure:GetStringWidth();
      if issecretvalue(textWidth) then return maxName end
      return math.min(maxName, math.max(width, math.ceil(textWidth) + 1)); --+1: no "..." on an exact fit
    end
    local textScale = REQ_TEXT_SCALE;
    local nameWidth = FitWidth(frame.sampleName or UnitName("softInteract") or "", ns.styles.Size(db).fontSize, minName);
    local text = frame.requirementText or (frame.outOfRange and "Move closer");
    local statusWidth = minName;
    if text then
      statusWidth = FitWidth(text, ns.styles.Size(db).fontSize * textScale, 0);
      nameWidth = math.max(nameWidth, statusWidth);
    end
    -- Prepare the text and a full line before showing it, including the first target after /reload.
    if text then
      frame.requirement:SetText(text);
      if frame.outOfRange and not frame.requirementText then
        frame.requirement:SetTextColor(1, 0.82, 0.35);
      else
        frame.requirement:SetTextColor(RED_FONT_COLOR:GetRGB());
      end
    end
    frame.requirement:SetFont(ns.styles.Font(db), ns.styles.Size(db).fontSize * textScale, ns.styles.FontFlags());
    frame.requirement:ClearAllPoints();
    local requirementY = style.RequirementY and style.RequirementY(frame, db)
      or (style.nameOffsetY or 0) * ns.styles.Size(db).inputScale
      + ns.styles.Size(db).fontSize * REQ_TEXT_Y + ns.styles.StatusOffset(frame, db);
    frame.requirement:SetPoint("LEFT", frame.box, "LEFT", edgeLeft + left, requirementY);
    frame.requirement:SetWidth(nameWidth);
    frame.requirement:SetHeight(math.ceil(ns.styles.Size(db).fontSize * textScale * 1.5));
    frame.statusShadow:ClearAllPoints();
    frame.statusShadow:SetPoint("CENTER", frame.box, "LEFT", edgeLeft + left + nameWidth * 0.5, requirementY);
    frame.statusShadow:SetSize(statusWidth + 32, ns.styles.Size(db).fontSize * textScale + 11);
    frame.name:ClearAllPoints();
    frame.name:SetFont(ns.styles.Font(db), ns.styles.Size(db).fontSize, ns.styles.FontFlags());
    frame.name:SetWidth(nameWidth);
    frame.compactName:SetFont(ns.styles.Font(db), ns.styles.Size(db).fontSize * REQ_NAME_SCALE, ns.styles.FontFlags());
    -- An outlined style draws no drop shadow (ElvUI's convention); others keep the font's own shadow.
    for _, label in ipairs({ frame.name, frame.compactName, frame.requirement }) do
      if style.noTextShadow then label:SetShadowOffset(0, 0); else label:SetShadowOffset(unpack(label.baseShadow)); end
    end
    frame.compactName:SetWidth(nameWidth);
    frame.name:SetJustifyH("CENTER");
    frame.compactName:SetJustifyH("CENTER");
    frame.requirement:SetJustifyH("CENTER");
    local width = edgeLeft + left + nameWidth + right + edgeRight;
    frame.box:SetWidth(width);
    frame.boxWidth, frame.nameWidth = width, nameWidth; --for /esi debug; reading them back could be secret
    frame.nameLeft = edgeLeft + left;
    -- Center the name column, rather than the combined icon/name/key width. Resizing an outer column
    -- must not slide the name and status sideways. The cached offset also informs pixel snapping.
    frame.boxOffsetX = width * 0.5 - frame.nameLeft - nameWidth * 0.5;
    frame.box:SetPoint("CENTER", frame, "CENTER", frame.boxOffsetX, 0);
    StyleName(animate);
    SetIconSide(); --center the artwork in its reserved side cells
    ns.styles.Layout(frame);
    ns.CastBar.Layout(frame);
    if frame.onLayout then frame.onLayout(width); end --the preview widens its window to fit the HUD
  end

  -- After a font or font size change, the name, key cap, columns and lines follow.
  local function UpdateFont()
    SetName(frame.sampleName or UnitName("softInteract"));
    UpdateKeyCap();
    UpdateLayout();
    -- Invalidate native glyph caches after applying the new face, including an unchanged target.
    -- Forward text as-is: a target name may be secret, so never inspect or transform it here.
    for _, label in ipairs({ frame.name, frame.compactName, frame.requirement, cap.text }) do
      local text = label:GetText();
      label:SetText(nil);
      label:SetText(text);
    end
  end

  local function UpdateHeight()
    frame.box:SetHeight(ns.styles.Size(EnhancedSoftInteractDB).hudHeight);
  end

  ----
  --  Colors
  ----

  -- Only a target you can interact with gets its type's color. In range but unable (such as a herb without
  -- Herbalism) is UNABLE_COLOR. Out of range is OUT_OF_RANGE_COLOR, the frame fades to OUT_OF_RANGE_ALPHA,
  -- and a shared status line explains why the interaction is unavailable.
  -- A texture's vertex alpha and its own alpha are one value, so an Alpha animation overwrites the
  -- vertex alpha set here. The switch animation fades the icon glow in to alpha 1, which left it at full
  -- strength instead of 0.6 until the next repaint. The additive layers keep alpha 1
  -- and carry their strength in the color instead;
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

  local ResetAnimations, SettleAppearance;
  local function UpdateStyle()
    local size = ns.styles.Size(EnhancedSoftInteractDB);
    local buttonScale, iconScale = ns.styles.ButtonScale(EnhancedSoftInteractDB), ns.styles.IconScale(EnhancedSoftInteractDB);
    local changed = cap.styleArt ~= ns.styles.Get() or cap.keyStyle ~= EnhancedSoftInteractDB.keyStyle
      or frame.appliedSize ~= size or frame.appliedButtonScale ~= buttonScale or frame.appliedIconScale ~= iconScale;
    -- Native effects retain their old targets and starting appearance. Stop them before changing art.
    if changed and ResetAnimations then ResetAnimations(); end
    ApplyTextures();
    frame.appliedSize = size;
    frame.appliedButtonScale, frame.appliedIconScale = buttonScale, iconScale;
    UpdateHeight();
    UpdateIcon();
    StyleKeyCap();
    UpdateKeyCap();
    UpdateLayout();
    UpdateColors();
    if changed and SettleAppearance then SettleAppearance(); end
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
    -- A live cast keeps animating through the fade-out, and a finished cast keeps its outcome.
    if frame == ns.frame and ns.RefreshInteractionCastBar then ns.RefreshInteractionCastBar();
    else ns.CastBar.Hide(frame); end
    -- A running interact pulse or cast outcome finishes before the fade-out (looting clears the target at once).
    local wait = math.max(frame.pulseUntil - GetTime(), ns.CastBar.OutcomeRemaining(frame));
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
    -- Cursor refreshes supply the artwork; the current style and option own its visibility.
    frame.icon:SetShown(ns.styles.ShowIcon(EnhancedSoftInteractDB));
    SetName(target.name);
    local knownTarget, iconKey, outOfRange = target.knownTarget, target.iconKey, target.outOfRange;
    local signature = target.signature;
    if knownTarget and knownTarget == frame.lastTarget and signature == frame.lastSignature
        and frame:IsShown() and not frame.fadingOut then
      -- The same cursor can arrive as different artwork, with different centering offsets.
      AnchorIcon();
      return target, false;
    end
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
    StopSwitchAnim();
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
  ResetAnimations = function()
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
    cap.ring:SetAlpha(0);
    frame.pulseUntil = 0;
    samplePulseAt = nil;
    frame.glowScale, frame.rgb, glowTarget = nil, nil, nil;
    cap.isDown, cap.tapping, cap.consumed, cap.releasedAt = false, false, false, nil;
    cap.pressDepth, cap.pressShade = 0, 1; --the key cap repaints with the next target (SetTypeColor)
    frame.statusAmount, frame.statusTarget = nil, nil;
    if ns.ModifierKey then ns.ModifierKey.Reset(frame); end
  end
  frame:HookScript("OnHide", ResetAnimations);

  -- Native animations can finish after the range has changed. Restore the current appearance,
  -- rather than leaving a previously captured opacity on the icon or name.
  SettleAppearance = function()
    if not frame:IsShown() or frame.fadingOut or not frame.nameLeft then return end
    frame.icon:SetAlpha(1);
    frame.nameHolder:SetAlpha(1);
    SetTypeColor(false);
    if not statusTween:GetScript("OnUpdate") then PaintStatus(frame.statusAmount or 0); end
    if not rangeFade:GetScript("OnUpdate") and not frame.fader:IsPlaying() then
      frame:SetAlpha(frame.outOfRange and OUT_OF_RANGE_ALPHA or IN_RANGE_ALPHA);
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
      frame:SetAlpha(frame.outOfRange and OUT_OF_RANGE_ALPHA or IN_RANGE_ALPHA);
      SetTypeColor(false);
      UpdateLayout();
    end
  end

  -- Shows a preview target in Edit Mode: a name, a cursor by name ("Skin", "UnableGatherHerbs") and an
  -- optional requirement line, fully visible and in range.
  local function ShowSample(name, cursor, requirementText)
    ns.CastBar.Hide(frame);
    rangeFade:Stop();
    frame.fader:Stop();
    StopSwitchAnim();
    frame.fadingOut = false;
    frame:SetAlpha(1);
    frame:Show();
    frame.sampleName, frame.sampleCursor = name, cursor;
    SetName(name);
    frame.requirementText = requirementText;
    frame.colorKey, frame.outOfRange = ShowCursor(cursor), false;
    SetTypeColor(true);
    AnchorIcon();
    UpdateKeyCap();
    UpdateLayout();
    if EnhancedSoftInteractDB.animationsEnabled then PlaySwitchAnim(); end
  end

  -- The settings preview's checkboxes: shows the current sample out of range or with an unmet
  -- requirement, using the same status transition, dimming and colors as a real target.
  local function SetSampleState(cursor, outOfRange, requirementText)
    if not frame.sampleName then return end
    local visible = frame:IsShown();
    local fromAlpha = CurrentAlpha();
    frame.sampleCursor, frame.outOfRange, frame.requirementText = cursor, outOfRange, requirementText;
    frame.colorKey = ShowCursor(cursor);
    UpdateLayout(visible);
    AnchorIcon();
    SetTypeColor(visible);
    local toAlpha = outOfRange and OUT_OF_RANGE_ALPHA or IN_RANGE_ALPHA;
    if visible and EnhancedSoftInteractDB.animationsEnabled then FadeRange(toAlpha, fromAlpha);
    else frame:SetAlpha(toAlpha); end
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
    frame = frame, ApplyAllSettings = ApplyAllSettings, ShowSample = ShowSample, SetSampleState = SetSampleState,
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
local huds = { hud }; --the real HUD and any UI previews
frame:SetSize(200, 40);
frame:SetPoint(HUD_DEFAULT_POSITION.point, UIParent, HUD_DEFAULT_POSITION.point, HUD_DEFAULT_POSITION.x, HUD_DEFAULT_POSITION.y);
frame:SetMovable(true);
frame:SetDontSavePosition(true); --Edit Mode layouts hold the position, not WoW's layout-local.txt
frame:EnableMouse(false);
frame:Hide();
frame.editModeName = "Enhanced Soft Interact";

-- With the addon disabled, every target counts as none.
-- A success or interrupt outcome finishes before the HUD follows new target state (user request).
-- Right after a cast the game re-sends the corpse or node as Unable, can clear it and returns it as
-- LootAll within a few frames. Only the latest state matters, so it is applied once the outcome ends.
local targetQueued = false;
local function OnSoftInteractChanged(oldTarget, newTarget)
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
    if ns.DebugSoftTarget and not frame.fromRangeCheck then ns.DebugSoftTarget(oldTarget, newTarget, nil, "queued"); end
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
  if ns.RefreshInteractionCastBar then ns.RefreshInteractionCastBar(); end
  -- Selected debug sources retain clears/repeats while open; unchanged range polls stay silent.
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
local rangeWatcher = CreateFrame("Frame", nil, frame);
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

-- Shared with the Feat files. The Update functions and ShowSample run on every HUD.
ns.frame, ns.media, ns.AddHUD = frame, media, AddHUD;
ns.DEFAULTS, ns.SLIDER_RANGES, ns.HUD_DEFAULT_POSITION = DEFAULTS, SLIDER_RANGES, HUD_DEFAULT_POSITION;
ns.Notify, ns.issecretvalue = Notify, issecretvalue;
ns.RefreshKeyCap = RefreshKeyCap;
for _, name in ipairs({ "ShowSample", "PlayInteractPulse", "UpdateColors", "SetIconSide", "UpdateIcon",
    "UpdateFont", "UpdateHeight", "UpdateKeyCap", "UpdateLayout", "UpdateAnimations", "UpdateStyle", "UpdateShadow" }) do
  ns[name] = OnEveryHUD(name);
end
