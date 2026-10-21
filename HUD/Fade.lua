local _, ns = ...;
local CreateTween = ns.CreateTween;

local FADE_IN_TIME, FADE_OUT_TIME = 0.12, 0.15;

-- How the HUD fades in and out, and dims or brightens when the range changes. Other parts call
-- hud.FadeTo, hud.FadeRange, hud.CurrentAlpha and hud.GetFadeTimes, and stop a running range fade
-- through hud.rangeFade.
function ns.SetupFade(hud)
  local frame = hud.frame;

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
    hud.SettleAppearance();
  end);

  local function GetFadeTimes()
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

  hud.rangeFade = rangeFade;
  hud.GetFadeTimes, hud.CurrentAlpha, hud.FadeTo, hud.FadeRange = GetFadeTimes, CurrentAlpha, FadeTo, FadeRange;
end
