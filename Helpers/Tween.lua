local _, ns = ...;

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

-- Keeps an animated value inside its range, so no tween or blend can push a glow, color or press depth
-- past its limits.
local function Clamp(value, low, high) return math.max(low, math.min(high, value)) end

-- Builds a native animation group on frame from steps. Each step is { type, target, order, duration } plus
-- smoothing, alpha = {from, to}, scale (with origin), offset (a Y translation) and name (the group keeps
-- that step as group[name]).
local function CreateAnimationGroup(frame, steps)
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

ns.CreateTween, ns.Clamp, ns.CreateAnimationGroup = CreateTween, Clamp, CreateAnimationGroup;
