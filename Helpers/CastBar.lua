local ADDON_NAME, ns = ...;
local bar = {};
ns.CastBar = bar;
local WHITE = [[Interface\Buttons\WHITE8X8]];

-- Castbars use the cached name column, never measurements of a secret-anchored region.
function bar.Create(frame)
  local holder = CreateFrame("Frame", nil, frame);
  holder:SetAllPoints(frame);
  holder:SetFrameLevel(frame:GetFrameLevel() + 1);
  for _, name in ipairs({ "backing1", "backing2", "track1", "track2", "fill1", "fill2", "end1", "end2" }) do
    local layer = name:match("^backing") and "BACKGROUND" or "ARTWORK";
    local texture = holder:CreateTexture(nil, layer);
    texture:SetTexture(WHITE);
    holder[name] = texture;
  end
  holder.progress = 0;
  holder.runeGlow = holder:CreateTexture(nil, "BACKGROUND");
  holder.runeGlow:SetTexture([[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\SoftGlow]]);
  holder.runeGlow:SetBlendMode("ADD");
  holder.runeGlow:SetVertexColor(0, 0, 0, 1);
  holder.runeGlow:Hide();
  holder:Hide();
  frame.castBar = holder;
  frame:HookScript("OnHide", function() bar.Hide(frame); end);
end

local function PaintRuneGlow(holder, amount)
  holder.runeAmount = amount;
  local strength = 0.24 * amount;
  holder.runeGlow:SetVertexColor((holder.red or 0) * strength,
    (holder.green or 0) * strength, (holder.blue or 0) * strength, 1);
  holder.runeGlow:SetShown(holder.split and amount > 0);
end

local function PaintFill(holder, first, second)
  if not holder.centerBright then return end
  local r, g, b = holder.red or 0, holder.green or 0, holder.blue or 0;
  local half = holder.width * 0.5;
  local function Color(strength) return CreateColor(r * strength, g * strength, b * strength, 1); end
  -- Keep the gradient fixed along the complete track, even while only part is filled.
  holder.fill1:SetGradient("HORIZONTAL", Color(0.45), Color(0.45 + 0.55 * first / half));
  holder.fill2:SetGradient("HORIZONTAL", Color(1), Color(1 - 0.55 * second / half));
end

local function Place(frame, texture, left, width, height)
  texture:ClearAllPoints();
  texture:SetPoint("LEFT", frame.box, "LEFT", left, frame.castBar.y);
  texture:SetSize(width, height);
end

function bar.SetProgress(frame, progress)
  local holder = frame.castBar;
  if not holder.width then return end
  holder.progress = math.max(0, math.min(1, progress));
  local tip = holder.width * holder.progress;
  local half = holder.width * 0.5;
  local firstWidth = holder.split and half - 5 or (holder.centerBright and half or holder.width);
  local secondLeft = half + (holder.split and 5 or 0);
  local filled = math.min(firstWidth, tip);
  if filled > 0 then
    holder.fill1:SetWidth(filled);
    holder.fill1:Show();
  else
    holder.fill1:Hide();
  end
  local first = filled;
  filled = (holder.split or holder.centerBright) and math.max(0, tip - secondLeft) or 0;
  if filled > 0 then
    holder.fill2:SetWidth(filled);
    holder.fill2:Show();
  else
    holder.fill2:Hide();
  end
  PaintFill(holder, first, filled);
  local light = holder.split and math.max(0, math.min(1, (holder.progress - 0.5) / 0.05)) or 0;
  PaintRuneGlow(holder, light * light * (3 - 2 * light));
  holder:Show();
end

function bar.Layout(frame)
  local holder, style = frame.castBar, ns.styles.Get();
  local config = style.castBar;
  if not config then holder.width = nil; holder:Hide(); return end
  local shown = holder:IsShown();
  holder.width, holder.left = frame.nameWidth, frame.nameLeft;
  -- Styles with an underline keep the track on it; the others use their line offset.
  holder.y = style.underline and ns.styles.UnderlineY(frame, EnhancedSoftInteractDB)
    or -(EnhancedSoftInteractDB.fontSize * 0.5 + config.offset);
  holder.height, holder.split, holder.centerBright = config.height, config.split == true, config.centerBright == true;
  local half = holder.width * 0.5;
  local firstWidth = holder.split and half - 5 or (holder.centerBright and half or holder.width);
  Place(frame, holder.fill1, holder.left, 0.1, holder.height);
  Place(frame, holder.fill2, holder.left + half + (holder.split and 5 or 0), 0.1, holder.height);
  for _, prefix in ipairs({ "backing", "track" }) do
    local height = holder.height + (prefix == "backing" and 1.2 or 0);
    Place(frame, holder[prefix .. "1"], holder.left, holder.split and firstWidth or holder.width, height);
    holder[prefix .. "1"]:Show();
    if holder.split then
      Place(frame, holder[prefix .. "2"], holder.left + half + 5, half - 5, height);
      holder[prefix .. "2"]:Show();
    else
      holder[prefix .. "2"]:Hide();
    end
  end
  Place(frame, holder.end1, holder.left - 0.45, 0.9, 4.5);
  Place(frame, holder.end2, holder.left + holder.width - 0.45, 0.9, 4.5);
  holder.end1:Show();
  holder.end2:Show();
  holder.runeGlow:ClearAllPoints();
  holder.runeGlow:SetPoint("CENTER", frame.box, "LEFT", holder.left + half, holder.y);
  holder.runeGlow:SetSize(16, 14);
  bar.Paint(frame, holder.red or 0, holder.green or 0, holder.blue or 0);
  bar.SetProgress(frame, holder.progress);
  if not shown then holder:Hide(); end
end

function bar.Paint(frame, r, g, b)
  local holder = frame.castBar;
  if holder.red == r and holder.green == g and holder.blue == b
      and holder.paintedCenterBright == holder.centerBright then return end
  holder.red, holder.green, holder.blue = r, g, b;
  holder.paintedCenterBright = holder.centerBright;
  for i = 1, 2 do
    holder["backing" .. i]:SetVertexColor(0, 0, 0, 0.8);
    holder["track" .. i]:SetVertexColor(r * 0.28, g * 0.28, b * 0.28, 1);
    local fill = holder["fill" .. i];
    fill:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1));
    if holder.centerBright then fill:SetVertexColor(1, 1, 1, 1);
    else fill:SetVertexColor(r * 0.95, g * 0.95, b * 0.95, 1); end
    holder["end" .. i]:SetVertexColor(r * 0.85, g * 0.85, b * 0.85, 1);
  end
  if holder.centerBright and holder.width then
    local tip, half = holder.width * holder.progress, holder.width * 0.5;
    PaintFill(holder, math.min(half, tip), math.max(0, tip - half));
  end
  PaintRuneGlow(holder, holder.runeAmount or 0);
end

function bar.Hide(frame)
  frame.castBar:Hide();
  frame.castBar.progress = 0;
  PaintRuneGlow(frame.castBar, 0);
end
