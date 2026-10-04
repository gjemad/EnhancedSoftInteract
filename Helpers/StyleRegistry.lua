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
