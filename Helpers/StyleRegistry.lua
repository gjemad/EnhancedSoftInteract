local ADDON_NAME, ns = ...;
local styles, order = {}, {};
local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];
local commonLayers = { "iconGlow", "lineLowGlow", "lineLow", "lineHigh" };
ns.HUD_STYLES = {};
ns.styles = {};

-- A style supplies its label, visible common layers and optional Create/Apply/Layout/Paint hooks.
-- Create returns its extra regions; the registry hides them when another style is selected.
-- Layout uses cached numeric columns, never measurements of the target's secret name.
function ns.styles.Register(id, style)
  assert(not styles[id], "Duplicate HUD style: " .. id);
  styles[id] = style;
  order[#order + 1] = id;
  ns.HUD_STYLES[#ns.HUD_STYLES + 1] = { text = style.name, value = id };
end

function ns.styles.Get()
  return styles[EnhancedSoftInteractDB.hudStyle] or styles.levelup;
end

-- Y of a name underline (styles with underline = true): the center of the key's bottom border, so the
-- underline and the key end on one line. Without key art, the line sits fontSize * 0.5 + 6.5 below the
-- center, and it never rises closer than 2 units below the name's line box (a small key with large text).
function ns.styles.UnderlineY(frame, db)
  local y = -(db.fontSize * 0.5 + 6.5);
  local cap = frame.keyCap;
  if cap:IsShown() and cap.capHeight then
    local m = cap.art and cap.art.margins;
    local border = cap.art and cap.art.bottomBorder;
    if border and not cap.isGlyph then
      y = -(border - (1 + m[2] - m[4]) * 0.5) / (1 - m[2] - m[4]) * cap.capHeight;
    else
      y = -cap.capHeight * 0.5 + 0.5; --a gamepad glyph or plain box: its bottom edge
    end
  end
  return math.min(y, -(db.fontSize * 0.5 + 2));
end

-- How far the requirement line and its compact name rise so they keep their distance to an underline
-- that moved up to the key's border.
function ns.styles.StatusShift(frame, db)
  if not ns.styles.Get().underline then return 0 end
  return ns.styles.UnderlineY(frame, db) + db.fontSize * 0.5 + 6.5;
end

function ns.styles.Create(frame)
  frame.styleRegions = {};
  frame.stylePulseLayers = {};
  for _, id in ipairs(order) do
    local style = styles[id];
    local regions = style.Create and style.Create(frame, MEDIA) or {};
    frame.styleRegions[id] = regions;
    for _, region in ipairs(regions) do region:Hide(); end
  end
end

function ns.styles.Apply(frame)
  local style = ns.styles.Get();
  for _, region in ipairs(frame.stylePulseLayers) do region:SetAlpha(0); end
  for _, name in ipairs(commonLayers) do
    frame[name]:SetShown(style.layers and style.layers[name] and (name ~= "iconGlow" or EnhancedSoftInteractDB.showIcon) or false);
  end
  for id, regions in pairs(frame.styleRegions) do
    for _, region in ipairs(regions) do region:SetShown(styles[id] == style); end
  end
  -- Reset shared textures and anchors so switching styles cannot carry over another look.
  for _, name in ipairs({ "lineLow", "lineLowGlow", "lineHigh" }) do
    frame[name]:SetTexture([[Interface\Buttons\WHITE8X8]]);
    frame[name]:SetTexCoord(0, 1, 0, 1);
  end
  frame.flash:SetTexture(MEDIA .. "SoftGlow");
  frame.flash:SetDesaturated(false);
  frame.flash:SetGradient("VERTICAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1));
  frame.flash:ClearAllPoints();
  frame.flash:SetPoint("TOPLEFT", frame.box, "TOPLEFT", -20, 0);
  frame.flash:SetPoint("BOTTOMRIGHT", frame.box, "BOTTOMRIGHT", 20, 0);
  if style.Apply then style.Apply(frame); end
  frame.flashHolder:SetAlpha(0);
end

-- Bloom layers join the core pulse so timing, repeat presses and cancellation stay shared.
function ns.styles.CreatePulseGlow(frame)
  local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 0);
  glow:SetTexture(MEDIA .. "SoftGlow");
  glow:SetBlendMode("ADD");
  glow:SetAlpha(0);
  frame.stylePulseLayers[#frame.stylePulseLayers + 1] = glow;
  return glow;
end

function ns.styles.CreateBloom(frame)
  local regions = { ns.styles.CreatePulseGlow(frame), ns.styles.CreatePulseGlow(frame) };
  return regions;
end

function ns.styles.NameBloom(frame, texture, db)
  texture:ClearAllPoints();
  texture:SetPoint("CENTER", frame.name, "CENTER");
  texture:SetSize(frame.nameWidth + 24, db.fontSize + 16);
end

function ns.styles.BloomSegment(frame, texture, left, width, y)
  texture:ClearAllPoints();
  texture:SetPoint("CENTER", frame.box, "LEFT", left + width * 0.5, y);
  texture:SetSize(width + 24, 26);
end

function ns.styles.Layout(frame)
  local style = ns.styles.Get();
  if style.Layout then style.Layout(frame, EnhancedSoftInteractDB); end
end

function ns.styles.Paint(frame, r, g, b)
  local style = ns.styles.Get();
  frame.lineHigh:SetVertexColor(r, g, b, style.highLineAlpha or 0.5);
  local strength = style.flashStrength or 1;
  -- The holder owns animation opacity; texture alpha stays opaque while its RGB changes.
  frame.flash:SetVertexColor(r * strength, g * strength, b * strength, 1);
  if style.Paint then style.Paint(frame, r, g, b); end
end

-- Shared geometry for styles that decorate only the name column.
function ns.styles.NameSegment(frame, texture, x, width, y)
  texture:ClearAllPoints();
  texture:SetPoint("LEFT", frame.box, "LEFT", x, y);
  texture:SetSize(width, 1);
end
