local ADDON_NAME, ns = ...;
local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];
local Clamp, CreateTween, IsChordDown = ns.Clamp, ns.CreateTween, ns.IsChordDown;

-- What the interact key does to the HUD: the glow and icon pop on an interaction, the key cap pressing
-- down and springing back with the real key, and the watcher that follows the key. hud.PlayInteractPulse
-- starts an interaction, and hud.ResetInteraction puts everything back to rest when the HUD hides.
function ns.SetupInteraction(hud)
  local frame = hud.frame;
  local cap = frame.keyCap;

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
  -- A style's pulse layer can set its own peak opacity (pulsePeak; Elv's border light is fully lit).
  for _, glow in ipairs(frame.stylePulseLayers) do
    local peak = glow.pulsePeak or 0.45;
    pulseSteps[#pulseSteps + 1] = { "Alpha", glow, 1, 0.06, smoothing = "OUT", alpha = {0, peak} };
    pulseSteps[#pulseSteps + 1] = { "Alpha", glow, 2, 0.24, smoothing = "IN", alpha = {peak, 0} };
  end
  frame.pulse = ns.CreateAnimationGroup(frame, pulseSteps);
  -- Return every pulse layer to its idle opacity on completion, interruption or hide.
  local function ClearPulseLight()
    frame.flashHolder:SetAlpha(0);
    for _, glow in ipairs(frame.stylePulseLayers) do glow:SetAlpha(0); end
  end
  frame.pulse:SetScript("OnFinished", function()
    ClearPulseLight();
    hud.SettleAppearance();
  end);
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
  frame.pressIn = ns.CreateAnimationGroup(frame, {
    { "Scale", cap.icon, 1, PRESS_DOWN, smoothing = "OUT", scale = 1, name = "icon" },
    { "Scale", cap.text, 1, PRESS_DOWN, smoothing = "OUT", scale = 1, name = "text" },
    { "Scale", cap.icon, 2, KEY_HOLD_TIME, scale = 1 },
    { "Scale", cap.text, 2, KEY_HOLD_TIME, scale = 1 },
  });
  frame.pressOut = ns.CreateAnimationGroup(frame, {
    { "Scale", cap.icon, 1, PRESS_UP, smoothing = "IN_OUT", scale = 1, name = "icon" },
    { "Scale", cap.text, 1, PRESS_UP, smoothing = "IN_OUT", scale = 1, name = "text" },
  });
  frame.ripple = ns.CreateAnimationGroup(frame, {
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
      hud.PaintKeyCap();
    end);
  end
  local function EaseOut(t) return 1 - (1 - t) ^ 2 end
  local function EaseInOut(t) return t * t * (3 - 2 * t) end

  -- Finish with explicit idle values rather than relying on a native effect's captured starting state.
  frame.pressOut:SetScript("OnFinished", function()
    if cap.isDown or cap.tapping then return end
    depthTween:Stop();
    cap.pressDepth, cap.pressShade = 0, 1;
    hud.PaintKeyCap();
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

  -- Watches the interact key every frame while the key cap is showing, and presses the cap with it. Letting
  -- go comes up without a ripple; the interaction adds that (PlayInteractPulse). A key whose hold already
  -- interacted (cap.consumed) stays up until it's let go. While a text box has the keyboard (typing in
  -- chat), the key types instead, so the cap stays up. When the HUD goes away, a held cap comes up. An Edit Mode sample has no target for the game to interact with, so letting go of
  -- the key plays the whole interaction there, ripple, flash and icon pop included.
  local keyWatcher = CreateFrame("Frame", nil, frame);
  keyWatcher:SetScript("OnUpdate", function(_, elapsed)
    local watching = cap.key and frame:IsShown() and not frame.fadingOut
      and cap:IsShown()
      and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus());
    ns.ModifierKey.Poll(frame, watching, elapsed);
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

  -- Everything above goes back to rest when the HUD hides.
  function hud.ResetInteraction()
    for _, group in ipairs({ frame.pulse, frame.ripple, frame.pressIn, frame.pressOut }) do
      group:Stop();
    end
    depthTween:Stop();
    tapToken = tapToken + 1; --cancels a pending tap release
    ClearPulseLight();
    cap.ring:SetAlpha(0);
    frame.pulseUntil = 0;
    samplePulseAt = nil;
    cap.isDown, cap.tapping, cap.consumed, cap.releasedAt = false, false, false, nil;
    cap.pressDepth, cap.pressShade = 0, 1; --the key cap repaints with the next target (SetTypeColor)
  end

  hud.PlayInteractPulse, hud.ClearPulseLight = PlayInteractPulse, ClearPulseLight;
end
