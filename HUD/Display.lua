local _, ns = ...;
local ColorKeyFor = ns.ColorKeyFor;

-- Range opacity is shared by every HUD.
local IN_RANGE_ALPHA, OUT_OF_RANGE_ALPHA = 1, 0.75;

-- What the HUD shows: the soft target (OnSoftTargetChanged and OnSoftTargetCleared), or a sample in
-- Edit Mode and the settings preview. This part also applies a style or setting change to everything
-- else (UpdateStyle, ApplyAllSettings) and puts the HUD back to rest when it hides.
function ns.SetupDisplay(hud)
  local frame = hud.frame;
  local cap = frame.keyCap;

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
    if frame == ns.frame then ns.RefreshInteractionCastBar();
    else ns.CastBar.Hide(frame); end
    -- A running interact pulse or cast outcome finishes before the fade-out (looting clears the target at once).
    local wait = math.max(frame.pulseUntil - GetTime(), ns.CastBar.OutcomeRemaining(frame));
    local token = frame.fadeToken;
    local function FadeOut()
      if token == frame.fadeToken and frame:IsShown() and not frame.fadingOut then
        hud.rangeFade:Stop();
        hud.FadeTo(0, select(2, hud.GetFadeTimes()), true);
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
    hud.SetName(target.name);
    local knownTarget, iconKey, outOfRange = target.knownTarget, target.iconKey, target.outOfRange;
    local signature = target.signature;
    if knownTarget and knownTarget == frame.lastTarget and signature == frame.lastSignature
        and frame:IsShown() and not frame.fadingOut then
      -- The same cursor can arrive as different artwork, with different centering offsets.
      hud.AnchorIcon();
      return target, false;
    end
    hud.UpdateKeyCap(); --bindings and text measurement are unchanged during repeat range checks
    -- It's a switch when the visible frame changes to another target or another action, not only its range.
    local action = target.action;
    local visible = frame:IsShown() and not frame.fadingOut;
    local switched = visible and (action ~= frame.lastAction or not knownTarget or knownTarget ~= frame.lastTarget);
    frame.lastTarget, frame.lastSignature, frame.lastAction = knownTarget, signature, action;

    -- A visible HUD dims or brightens with its status transition. A short fade-in time
    -- would otherwise drop it from 1 to 0.75 in about 0.02 seconds while the colors still blend.
    local toAlpha = outOfRange and OUT_OF_RANGE_ALPHA or IN_RANGE_ALPHA;
    local fromAlpha = hud.CurrentAlpha();
    hud.rangeFade:Stop();
    frame.fader:Stop(); --settle native animation state before painting the new status
    hud.StopSwitchAnim();
    frame.fadingOut = false;
    frame.colorKey, frame.outOfRange = iconKey, outOfRange;
    frame.requirementText = target.requirementText;
    hud.UpdateLayout(visible and not switched);
    hud.AnchorIcon();
    hud.SetTypeColor(visible); --blend while the frame is up, set at once when it fades in
    -- Prepare child opacity before the HUD fade starts. Otherwise its completion can restore
    -- the hidden status opacity from before this target was laid out.
    if visible and EnhancedSoftInteractDB.animationsEnabled then
      hud.FadeRange(toAlpha, fromAlpha);
    else
      hud.FadeTo(toAlpha, (hud.GetFadeTimes()), false);
    end
    if switched and EnhancedSoftInteractDB.animationsEnabled then hud.PlaySwitchAnim(); end

    return target, true;
  end

  -- When the HUD hides, every animation stops and its values go back to rest, so nothing half-finished
  -- carries over to the next target. Without a stored glow size and color, the next target sets both at
  -- once instead of animating from stale values.
  local function ResetAnimations()
    hud.ResetAppearance();
    hud.ResetInteraction();
    hud.ResetLayout();
    hud.rangeFade:Stop();
    ns.ModifierKey.Reset(frame);
  end
  frame:HookScript("OnHide", ResetAnimations);

  -- Native animations can finish after the range has changed. Restore the current appearance,
  -- rather than leaving a previously captured opacity on the icon or name.
  local function SettleAppearance()
    if not frame:IsShown() or frame.fadingOut or not frame.nameLeft then return end
    frame.icon:SetAlpha(1);
    frame.nameHolder:SetAlpha(1);
    hud.SetTypeColor(false);
    if not hud.statusTween:GetScript("OnUpdate") then hud.PaintStatus(frame.statusAmount or 0); end
    if not hud.rangeFade:GetScript("OnUpdate") and not frame.fader:IsPlaying() then
      frame:SetAlpha(frame.outOfRange and OUT_OF_RANGE_ALPHA or IN_RANGE_ALPHA);
    end
  end
  frame.switchAnim:SetScript("OnFinished", SettleAppearance);

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
      hud.SetTypeColor(false);
      hud.UpdateLayout();
    end
  end

  local function UpdateStyle()
    local size = ns.styles.Size(EnhancedSoftInteractDB);
    local buttonScale, iconScale = ns.styles.ButtonScale(EnhancedSoftInteractDB), ns.styles.IconScale(EnhancedSoftInteractDB);
    local changed = cap.styleArt ~= ns.styles.Get() or cap.keyStyle ~= EnhancedSoftInteractDB.keyStyle
      or frame.appliedSize ~= size or frame.appliedButtonScale ~= buttonScale or frame.appliedIconScale ~= iconScale;
    -- Native effects retain their old targets and starting appearance. Stop them before changing art.
    if changed then ResetAnimations(); end
    hud.ApplyTextures();
    frame.appliedSize = size;
    frame.appliedButtonScale, frame.appliedIconScale = buttonScale, iconScale;
    hud.UpdateHeight();
    hud.UpdateIcon();
    hud.StyleKeyCap();
    hud.UpdateKeyCap();
    hud.UpdateLayout();
    hud.UpdateColors();
    if changed then SettleAppearance(); end
  end

  -- Shows a preview target in Edit Mode: a name, a cursor by name ("Skin", "UnableGatherHerbs") and an
  -- optional requirement line, fully visible and in range.
  local function ShowSample(name, cursor, requirementText)
    ns.CastBar.Hide(frame);
    hud.rangeFade:Stop();
    frame.fader:Stop();
    hud.StopSwitchAnim();
    frame.fadingOut = false;
    frame:SetAlpha(1);
    frame:Show();
    frame.sampleName, frame.sampleCursor = name, cursor;
    hud.SetName(name);
    frame.requirementText = requirementText;
    frame.colorKey, frame.outOfRange = ShowCursor(cursor), false;
    hud.SetTypeColor(true);
    hud.AnchorIcon();
    hud.UpdateKeyCap();
    hud.UpdateLayout();
    if EnhancedSoftInteractDB.animationsEnabled then hud.PlaySwitchAnim(); end
  end

  -- The settings preview's checkboxes: shows the current sample out of range or with an unmet
  -- requirement, using the same status transition, dimming and colors as a real target.
  local function SetSampleState(cursor, outOfRange, requirementText)
    if not frame.sampleName then return end
    local visible = frame:IsShown();
    local fromAlpha = hud.CurrentAlpha();
    frame.sampleCursor, frame.outOfRange, frame.requirementText = cursor, outOfRange, requirementText;
    frame.colorKey = ShowCursor(cursor);
    hud.UpdateLayout(visible);
    hud.AnchorIcon();
    hud.SetTypeColor(visible);
    local toAlpha = outOfRange and OUT_OF_RANGE_ALPHA or IN_RANGE_ALPHA;
    if visible and EnhancedSoftInteractDB.animationsEnabled then hud.FadeRange(toAlpha, fromAlpha);
    else frame:SetAlpha(toAlpha); end
  end

  -- Applies every setting to the HUD (on load, and when the preview is built).
  local function ApplyAllSettings()
    hud.ApplyTextures();
    hud.StyleKeyCap();
    hud.SetIconSide();
    hud.UpdateIcon();
    hud.UpdateFont();
    hud.UpdateHeight();
    hud.UpdateColors();
  end

  hud.ApplyAllSettings, hud.UpdateStyle, hud.UpdateAnimations = ApplyAllSettings, UpdateStyle, UpdateAnimations;
  hud.ShowSample, hud.SetSampleState = ShowSample, SetSampleState;
  hud.OnSoftTargetChanged, hud.OnSoftTargetCleared = OnSoftTargetChanged, OnSoftTargetCleared;
  hud.SettleAppearance = SettleAppearance;
end
