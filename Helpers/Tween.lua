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

ns.CreateTween, ns.Clamp = CreateTween, Clamp;
