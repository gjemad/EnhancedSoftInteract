local ADDON_NAME, ns = ...;
local bar = { END_HEIGHT = 4.5 };
ns.CastBar = bar;
local WHITE = [[Interface\Buttons\WHITE8X8]];
local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];
local PARTS = { "backing1", "backing2", "track1", "track2", "fill1", "fill2", "end1", "end2" };

-- Castbars use the cached name column, never measurements of a secret-anchored region.
local function CreateHolder(frame)
  local holder = CreateFrame("Frame", nil, frame);
  holder:SetAllPoints(frame);
  holder:SetFrameLevel(frame:GetFrameLevel() + 1);
  for _, name in ipairs(PARTS) do
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
  -- Optional native line art uncovered along the cast (Level-Up's glow reveal).
  holder.reveal = holder:CreateTexture(nil, "ARTWORK", nil, 2);
  holder.reveal:SetBlendMode("ADD");
  holder.reveal:Hide();
  holder.lights = {};
  for _, name in ipairs({ "halo", "core", "needle", "cross", "tail1", "tail2", "tail3", "tail4", "tail5", "tail6", "tail7", "tail8", "breath1", "breath2", "breathRune" }) do
    local light = holder:CreateTexture(nil, "OVERLAY");
    light:SetTexture(MEDIA .. "SoftGlow");
    light:SetBlendMode("ADD");
    light:Hide();
    holder.lights[name] = light;
  end
  holder:Hide();
  return holder;
end

function bar.Create(frame)
  local holder = CreateHolder(frame);
  frame.castBar = holder;
  frame.castFinish = CreateHolder(frame);
  bar.CreatePreviewDriver(frame);
  frame:HookScript("OnHide", function()
    if frame.previewCast then frame.previewCast:Hide(); end
    bar.Hide(frame);
  end);
end

local function Smooth(value)
  value = math.max(0, math.min(1, value));
  return value * value * (3 - 2 * value);
end

local function HideLights(holder)
  for _, light in pairs(holder.lights) do light:Hide(); end
end

-- Recipes belong to each style; this shared path only places and animates their reusable regions.
local function PaintTip(frame, holder)
  HideLights(holder);
  -- An outcome overlay draws its own effects instead of the travelling tip.
  local recipe = not holder.outcome and holder.glow;
  if not recipe then return end
  local scale, progress = holder.scale, holder.progress;
  local tip = holder.left + holder.width * progress;
  if recipe.spark then
    if progress <= 0 or progress >= 1 then return end
    local pixel = holder.pixel;
    local light = holder.lights.core;
    light:SetTexture(WHITE);
    ns.styles.Get().PlaceCast(frame, light, tip - pixel, pixel * 2, holder.height, holder.y);
    light:SetVertexColor(0.9, 0.9, 0.9, 0.6);
    light:Show();
    return;
  end
  local animated = EnhancedSoftInteractDB.animationsEnabled;
  local time = animated and GetTime() or 0;
  local approach = Smooth((progress - 0.85) / 0.15);
  local energy = Smooth(progress / 0.03);
  if holder.split then
    local distance = math.abs(holder.width * (progress - 0.5));
    energy = energy * math.max(0, math.min(1, (distance - holder.gap) / (3 * scale)));
  end
  local r, g, b = holder.red or 0, holder.green or 0, holder.blue or 0;
  local function Light(name, x, y, width, height, alpha, pale, texture)
    local light = holder.lights[name];
    light:SetTexture(texture or (MEDIA .. "SoftGlow"));
    light:ClearAllPoints();
    light:SetPoint("CENTER", frame.box, "LEFT", x, y);
    light:SetSize(math.max(0.01, width * scale), math.max(0.01, height * scale));
    light:SetVertexColor(pale and (0.82 + 0.18 * r) or r,
      pale and (0.82 + 0.18 * g) or g, pale and (0.82 + 0.18 * b) or b, alpha);
    light:SetShown(alpha > 0);
  end
  local pulse = 1;
  if animated and recipe.flicker then
    pulse = 1 + 0.055 * math.sin(time * 8) + 0.025 * math.sin(time * 13);
  elseif animated then pulse = 1 + 0.04 * math.sin(time * 5); end
  local tail = math.min(recipe.tail * scale, holder.width * progress);
  -- Overlapping soft segments make one continuous tapered trail, bounded by the filled track.
  for i = 1, 8 do
    local share = (i - 0.5) / 8;
    local x = tip - tail * (1 - share);
    Light("tail" .. i, x, holder.y, tail / scale / 4, recipe.tailHeight * (0.25 + 0.75 * share),
      recipe.tailAlpha * share ^ 1.6 * energy * pulse, false);
  end
  Light("halo", tip, holder.y, recipe.haloWidth, recipe.haloHeight * (1 - 0.6 * approach),
    recipe.haloAlpha * energy * pulse, false);
  Light("core", tip, holder.y, recipe.coreWidth + 5 * approach, recipe.coreHeight * (1 - 0.5 * approach),
    recipe.coreAlpha * energy, true, recipe.diamond and (MEDIA .. "RunicDiamond") or nil);
  if recipe.needle then
    Light("needle", tip, holder.y, 0.8 + 3 * approach, 6.2 - 4 * approach, 0.85 * energy, true);
    Light("cross", tip, holder.y, 3.5 + 4 * approach, 0.8, 0.5 * energy, true);
  end
  local breath = animated and 0.16 * approach or 0;
  if holder.split then
    local span = holder.width * 0.5 - holder.gap;
    Light("breath1", holder.left + span * 0.5, holder.y, span / scale + 6, recipe.breathHeight, breath, false);
    Light("breath2", holder.left + holder.width - span * 0.5, holder.y, span / scale + 6, recipe.breathHeight, breath, false);
    Light("breathRune", holder.left + holder.width * 0.5, holder.y, 12, 10, breath * 0.78, false);
  elseif recipe.lineTexture then
    Light("breath1", frame.boxWidth * 0.5, holder.y + 8 * scale * frame.lineStrokeShift,
      frame.boxWidth / scale + 10, 8, breath, false, recipe.lineTexture);
  else
    Light("breath1", holder.left + holder.width * 0.5, holder.y,
      holder.width / scale + 6, recipe.breathHeight, breath * (recipe.breathStrength or 1), false);
  end
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

-- Uncovers the style's native line art from the start of the cast to its tip, cropping the atlas to the
-- progress so its shape stays fixed instead of stretching. Without atlas coordinates it stretches.
local function PaintReveal(frame, holder)
  local reveal, config = holder.reveal, holder.revealConfig;
  local width = holder.width and holder.width * holder.progress or 0;
  if not config or holder.outcome or width <= 0 then reveal:Hide(); return end
  local info = C_Texture.GetAtlasInfo(config.atlas);
  if not info then reveal:Hide(); return end
  local file = info.file or info.filename;
  if file and info.leftTexCoord then
    if reveal.file ~= file then reveal:SetTexture(file); reveal.file = file; end
    local left, right = info.leftTexCoord, info.rightTexCoord;
    reveal:SetTexCoord(left, left + (right - left) * holder.progress, info.topTexCoord, info.bottomTexCoord);
  elseif reveal.file ~= config.atlas then
    reveal:SetAtlas(config.atlas);
    reveal.file = config.atlas;
  end
  reveal:SetDesaturated(true); --the artwork's gold gives way to the object color
  reveal:ClearAllPoints();
  reveal:SetPoint("LEFT", frame.box, "LEFT", holder.left, holder.y);
  reveal:SetSize(width, config.height * holder.scale);
  local r, g, b, strength = holder.red or 0, holder.green or 0, holder.blue or 0, config.strength;
  -- Normal blending tints the line in the object color. Additive light over the lit fill washed it out
  -- to white in game (user report 2026-10-18), so ADD stays available only as an explicit choice.
  reveal:SetBlendMode(config.blend or "BLEND");
  if config.blend == "ADD" then reveal:SetVertexColor(r * strength, g * strength, b * strength, 1);
  else reveal:SetVertexColor(r, g, b, strength); end
  reveal:Show();
end

local function Place(frame, texture, left, width, height, holder)
  local style = ns.styles.Get();
  if style.PlaceCast then style.PlaceCast(frame, texture, left, width, height, holder.y); return end
  ns.styles.Snap(texture, true);
  texture:ClearAllPoints();
  texture:SetPoint("LEFT", frame.box, "LEFT", left, holder.y);
  texture:SetSize(width, height);
end

function bar.SetProgress(frame, progress, holder)
  if not holder then frame.castFinish:Hide(); end
  holder = holder or frame.castBar;
  if not holder.width then return end
  holder.progress = math.max(0, math.min(1, progress));
  local tip = holder.width * holder.progress;
  local half = holder.width * 0.5;
  local firstWidth = holder.split and half - holder.gap or (holder.centerBright and half or holder.width);
  local secondLeft = half + (holder.split and holder.gap or 0);
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
  PaintTip(frame, holder);
  PaintReveal(frame, holder);
  holder:Show();
end

function bar.Layout(frame, holder)
  if not holder then frame.castFinish:Hide(); end
  holder = holder or frame.castBar;
  local style = ns.styles.Get();
  local config = style.castBar;
  if not config then holder.width = nil; holder:Hide(); return end
  local shown = holder:IsShown();
  local size = ns.styles.Size(EnhancedSoftInteractDB);
  holder.scale, holder.glow, holder.revealConfig = size.inputScale, config.glow, config.reveal;
  holder.endBright = config.endBright;
  holder.gap = 5 * size.inputScale;
  holder.pixel = config.pixel and style.Pixel(frame) or nil;
  holder.width, holder.left = frame.nameWidth, frame.nameLeft;
  -- Share the idle line or selected key baseline, including the style's text clearance.
  -- Only an outcome overlay sets yOffset, for an interrupted bar that sinks away.
  holder.y = ns.styles.LineY(frame, EnhancedSoftInteractDB, config.offset) + (holder.yOffset or 0);
  holder.height, holder.split, holder.centerBright = config.height * size.inputScale, config.split == true, config.centerBright == true;
  if config.pixel then holder.height = style.Pixel(frame) * 2; end
  for i = 1, 2 do holder["fill" .. i]:SetTexture(config.Texture and config.Texture() or WHITE); end
  local half = holder.width * 0.5;
  local firstWidth = holder.split and half - holder.gap or (holder.centerBright and half or holder.width);
  Place(frame, holder.fill1, holder.left, 0.1, holder.height, holder);
  Place(frame, holder.fill2, holder.left + half + (holder.split and holder.gap or 0), 0.1, holder.height, holder);
  for _, prefix in ipairs({ "backing", "track" }) do
    local backing = holder.pixel and holder.pixel * (config.backingPixels or 1) or 1.2;
    local height = holder.height + (prefix == "backing" and backing or 0);
    Place(frame, holder[prefix .. "1"], holder.left, holder.split and firstWidth or holder.width, height, holder);
    holder[prefix .. "1"]:Show();
    if holder.split then
      Place(frame, holder[prefix .. "2"], holder.left + half + holder.gap, half - holder.gap, height, holder);
      holder[prefix .. "2"]:Show();
    else
      holder[prefix .. "2"]:Hide();
    end
  end
  local endWidth = holder.pixel or (config.endWidth and config.endWidth * size.inputScale) or 0.9;
  local endHeight = holder.pixel and holder.pixel * (config.endPixels or 4) or (config.endHeight or bar.END_HEIGHT) * size.inputScale;
  Place(frame, holder.end1, holder.left - endWidth * 0.5, endWidth, endHeight, holder);
  Place(frame, holder.end2, holder.left + holder.width - endWidth * 0.5, endWidth, endHeight, holder);
  holder.end1:Show();
  holder.end2:Show();
  holder.runeGlow:ClearAllPoints();
  holder.runeGlow:SetPoint("CENTER", frame.box, "LEFT", holder.left + half, holder.y);
  holder.runeGlow:SetSize(16 * size.inputScale, 14 * size.inputScale);
  bar.Paint(frame, holder.sourceRed or 0, holder.sourceGreen or 0, holder.sourceBlue or 0, holder);
  bar.SetProgress(frame, holder.progress, holder);
  if not shown then holder:Hide(); end
end

function bar.Paint(frame, r, g, b, holder)
  holder = holder or frame.castBar;
  holder.sourceRed, holder.sourceGreen, holder.sourceBlue = r, g, b;
  if holder.red == r and holder.green == g and holder.blue == b
      and holder.paintedCenterBright == holder.centerBright and holder.paintedEndBright == holder.endBright then return end
  holder.red, holder.green, holder.blue = r, g, b;
  holder.paintedCenterBright, holder.paintedEndBright = holder.centerBright, holder.endBright;
  -- A style can lift its start and end markers toward white so they read clearly at the line's ends.
  local er, eg, eb = r * 0.85, g * 0.85, b * 0.85;
  if holder.endBright then
    local lift = holder.endBright;
    er, eg, eb = r + (1 - r) * lift, g + (1 - g) * lift, b + (1 - b) * lift;
  end
  for i = 1, 2 do
    holder["backing" .. i]:SetVertexColor(0, 0, 0, 0.8);
    holder["track" .. i]:SetVertexColor(r * 0.28, g * 0.28, b * 0.28, 1);
    local fill = holder["fill" .. i];
    fill:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1));
    if holder.centerBright then fill:SetVertexColor(1, 1, 1, 1);
    else fill:SetVertexColor(r * 0.95, g * 0.95, b * 0.95, 1); end
    holder["end" .. i]:SetVertexColor(er, eg, eb, 1);
  end
  if holder.centerBright and holder.width then
    local tip, half = holder.width * holder.progress, holder.width * 0.5;
    PaintFill(holder, math.min(half, tip), math.max(0, tip - half));
  end
  PaintRuneGlow(holder, holder.runeAmount or 0);
  PaintReveal(frame, holder);
end

function bar.Hide(frame, keepFinish)
  frame.castBar:Hide();
  frame.castBar.progress = 0;
  PaintRuneGlow(frame.castBar, 0);
  HideLights(frame.castBar);
  local finish = frame.castFinish;
  if keepFinish and finish:IsShown() then finish:GetScript("OnUpdate")(); else finish:Hide(); end
end

-- Cast outcomes. Styles name one success and one interrupt effect in their castBar recipe;
-- this shared code owns the reusable regions and timing. Interruptions use red, like the
-- native cast bar. Additive light keeps its strength in RGB with alpha 1.
local RED_R, RED_G, RED_B = 1, 0.24, 0.18;
local GLOW_LINE_ATLAS, LINE_ATLAS = "AftLevelup-GlowLine", "LevelUp-Bar-White";
local TEXTURES = { glow = MEDIA .. "SoftGlow", rune = MEDIA .. "RunicDiamond", solid = WHITE };

local function OutQuad(value)
  value = math.max(0, math.min(1, value));
  return 1 - (1 - value) * (1 - value);
end

local function Mix(r, g, b, r2, g2, b2, amount)
  return r + (r2 - r) * amount, g + (g2 - g) * amount, b + (b2 - b) * amount;
end

-- Reused overlay textures, placed in box coordinates like the travelling tip lights.
local function Effect(frame, holder, kind, x, y, width, height, r, g, b, strength, blend)
  if strength <= 0 or width <= 0 or height <= 0 then return end
  holder.fxUsed = holder.fxUsed + 1;
  local fx = holder.fx[holder.fxUsed];
  if not fx then
    fx = holder:CreateTexture(nil, "OVERLAY");
    holder.fx[holder.fxUsed] = fx;
  end
  if fx.kind ~= kind then
    fx.kind = kind;
    if kind == "glowLine" and C_Texture.GetAtlasInfo(GLOW_LINE_ATLAS) then
      fx:SetAtlas(GLOW_LINE_ATLAS);
      -- Remove the artwork's gold so the line follows the effect color.
      fx:SetDesaturated(true);
    elseif kind == "line" then
      -- The Level-Up line's own artwork, with the same Era fallback crop as Styles\LevelUpLine.lua.
      if C_Texture.GetAtlasInfo(LINE_ATLAS) then fx:SetAtlas(LINE_ATLAS);
      else
        fx:SetTexture(MEDIA .. "LevelUpBar");
        fx:SetTexCoord(0, 418 / 512, 0, 7 / 8);
      end
      fx:SetDesaturated(false);
    else
      fx:SetTexture(TEXTURES[kind] or TEXTURES.glow);
      fx:SetTexCoord(0, 1, 0, 1);
      fx:SetDesaturated(false);
    end
  end
  fx:SetBlendMode(blend or "ADD");
  fx:ClearAllPoints();
  fx:SetPoint("CENTER", frame.box, "LEFT", x, y);
  fx:SetSize(width, height);
  -- A uniform vertex color replaces any gradient the texture carried from an earlier frame.
  if blend == "BLEND" then fx:SetVertexColor(r, g, b, math.min(1, strength));
  else fx:SetVertexColor(r * strength, g * strength, b * strength, 1); end
  fx.wave = nil;
  fx:Show();
  return fx;
end

-- One half of a soft additive wave crest: full strength at the crest, black (no light) at the far end.
-- The half is clipped at `limit`; its far end keeps the strength the full half would have there.
local function WaveHalf(frame, holder, crest, direction, limit, y, half, height, r, g, b, strength)
  local length = math.min(half, (limit - crest) * direction);
  if length <= 0 then return end
  local fx = Effect(frame, holder, "solid", crest + direction * length * 0.5, y, length, height, r, g, b, strength);
  if not fx then return end
  local edge = strength * (1 - length / half);
  local near, far = CreateColor(r * strength, g * strength, b * strength, 1), CreateColor(r * edge, g * edge, b * edge, 1);
  if direction > 0 then fx:SetGradient("HORIZONTAL", near, far); else fx:SetGradient("HORIZONTAL", far, near); end
  fx.wave = true;
end

-- Colors the stopped or completed bar. A nil fill keeps the bar hidden.
local function PaintBar(holder, alpha, fr, fg, fb, tr, tg, tb, er, eg, eb)
  for i = 1, 2 do
    holder["backing" .. i]:SetVertexColor(0, 0, 0, 0.8 * alpha);
    holder["track" .. i]:SetVertexColor(tr, tg, tb, alpha);
    holder["fill" .. i]:SetVertexColor(fr, fg, fb, alpha);
    holder["end" .. i]:SetVertexColor(er, eg, eb, alpha);
  end
end

-- Each effect draws one frame; LENGTH holds how long it runs, in seconds.
local OUTCOMES = {};
local LENGTH = { afterglow = 0.8, redGlowLine = 0.5, runeIgnition = 0.65, tipSparks = 0.65, softBloom = 0.7, sink = 0.5, flashFill = 0.4, redBar = 0.65 };

-- Level-Up success: the bar warms slightly, lingers, then melts into the line while the upper line echoes it.
-- The lifted start and end markers, matching bar.Paint.
local function EndColor(h, r, g, b)
  if not h.endBright then return r * 0.85, g * 0.85, b * 0.85 end
  return Mix(r, g, b, 1, 1, 1, h.endBright);
end

function OUTCOMES.afterglow(frame, h, e, r, g, b)
  local s, middle = h.scale, frame.boxWidth * 0.5;
  local alpha = 1 - Smooth((e - 0.25) / 0.5);
  local warm = Smooth(e / 0.08);
  local fr, fg, fb = Mix(r, g, b, 1, 1, 1, 0.2 * warm);
  local er, eg, eb = EndColor(h, r, g, b);
  PaintBar(h, alpha, fr, fg, fb, r * 0.28, g * 0.28, b * 0.28, er, eg, eb);
  -- The warmth spreads over the whole lower line (user request), not just the cast bar: its own
  -- artwork brightens end to end, with the glow line and a soft glow along the full width.
  -- Everything sits on the line strokes, exactly like the Level-Up interaction flash. The upper
  -- line mirrors the lower one at -h.y, inset 20 units each side.
  Effect(frame, h, "line", middle, h.y + 4 * s * (frame.lineStrokeShift or 0), frame.boxWidth + 10 * s, 4 * s,
    r, g, b, 0.6 * warm * alpha);
  Effect(frame, h, "glowLine", middle, h.y, frame.boxWidth + 26 * s, 12 * s, r, g, b, 0.55 * alpha);
  Effect(frame, h, "glow", middle, h.y, frame.boxWidth + 20 * s, 8 * s, r, g, b, 0.3 * alpha);
  Effect(frame, h, "glowLine", middle, -h.y, frame.boxWidth - 30 * s, 9 * s, r, g, b,
    0.25 * Smooth(e / 0.1) * alpha);
end

-- Level-Up interruption: the success flare's glow line, in red.
function OUTCOMES.redGlowLine(frame, h, e, r, g, b)
  local s, stopped = h.scale, h.width * h.progress;
  local flash = Smooth(e / 0.05) * (1 - Smooth((e - 0.05) / 0.4));
  local fr, fg, fb = Mix(r, g, b, RED_R, RED_G, RED_B, Smooth(e / 0.05));
  local er, eg, eb = EndColor(h, r, g, b);
  PaintBar(h, 1 - Smooth(e / 0.3), fr, fg, fb, r * 0.28, g * 0.28, b * 0.28, er, eg, eb);
  Effect(frame, h, "glowLine", frame.boxWidth * 0.5, h.y, frame.boxWidth + 26 * s, 12 * s, RED_R, RED_G, RED_B, 0.8 * flash);
  Effect(frame, h, "glow", h.left + stopped * 0.5, h.y, stopped + 20 * s, 12 * s, RED_R, RED_G, RED_B, 0.35 * flash);
end

-- Runic success: the center rune flares while four rune points spread outward.
function OUTCOMES.runeIgnition(frame, h, e, r, g, b)
  local s, center = h.scale, h.left + h.width * 0.5;
  local pr, pg, pb = Mix(r, g, b, 1, 1, 1, 0.7);
  local flare = Smooth(e / 0.06) * (1 - Smooth((e - 0.08) / 0.5));
  PaintBar(h, 1 - Smooth(e / 0.4), r * 0.95, g * 0.95, b * 0.95, r * 0.28, g * 0.28, b * 0.28, r * 0.85, g * 0.85, b * 0.85);
  Effect(frame, h, "glow", center, h.y, 26 * s, 22 * s, r, g, b, 0.8 * flare);
  -- The pale rune and points stay translucent so the interaction color shows through (user request).
  Effect(frame, h, "rune", center, h.y, (6 + 7 * flare) * s, (6 + 7 * flare) * s, pr, pg, pb, 0.65 * flare);
  local spread = OutQuad(e / 0.55);
  local size, points = (8 + 26 * spread) * s, 0.6 * (1 - spread);
  for _, offset in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 0.8 }, { 0, -0.8 } }) do
    local x, y = center + offset[1] * size * 0.5, h.y + offset[2] * size * 0.5;
    Effect(frame, h, "rune", x, y, 3.5 * s, 3.5 * s, pr, pg, pb, points);
    Effect(frame, h, "glow", x, y, 9 * s, 8 * s, r, g, b, 0.5 * points);
  end
  -- A wave in the interaction color rolls from the rune to each end, fading on both sides of its crest.
  local wr, wg, wb = Mix(r, g, b, 1, 1, 1, 0.25);
  local span, half = h.width * 0.5 - h.gap, 14 * s;
  local travel = OutQuad(e / 0.5);
  local wave = Smooth(e / 0.05) * (1 - Smooth((e - 0.3) / 0.3));
  for side = -1, 1, 2 do
    local inner, outer = center + side * h.gap, center + side * (h.gap + span);
    local crest = inner + side * span * travel;
    WaveHalf(frame, h, crest, side, outer, h.y, half, h.height, wr, wg, wb, 0.9 * wave);
    WaveHalf(frame, h, crest, -side, inner, h.y, half, h.height, wr, wg, wb, 0.9 * wave);
    -- A soft halo rides each crest, so the wave stays visible over the lit bar.
    Effect(frame, h, "glow", crest, h.y, 2 * half, 7 * s, r, g, b, 0.75 * wave);
  end
end

-- Runic interruption: the bar, end points and rune turn red while sparks fall from the tip.
function OUTCOMES.tipSparks(frame, h, e)
  local s, stopped = h.scale, h.width * h.progress;
  local tip = h.left + stopped;
  PaintBar(h, 1 - Smooth(e / 0.35), RED_R, RED_G, RED_B, RED_R * 0.28, RED_G * 0.28, RED_B * 0.28,
    RED_R * 0.85, RED_G * 0.85, RED_B * 0.85);
  Effect(frame, h, "glow", h.left + stopped * 0.5, h.y, stopped + 12 * s, 8 * s, RED_R, RED_G, RED_B, 0.4 * (1 - Smooth(e / 0.3)));
  Effect(frame, h, "glow", tip, h.y, 12 * s, 10 * s, RED_R, RED_G, RED_B, 0.8 * (1 - Smooth(e / 0.2)));
  for i = 0, 4 do
    local q = math.max(0, math.min(1, (e - 0.02 * i) / 0.5));
    local x = tip + (i - 2) * 2.5 * s * q + 3 * s * q;
    local y = h.y + (4 + (i % 2) * 2) * s * q - 14 * s * q * q;
    Effect(frame, h, "rune", x, y, 2.2 * s, 2.2 * s, RED_R, RED_G, RED_B, 1 - Smooth((q - 0.3) / 0.7));
  end
  -- Cover the style's rune with a red copy, so it fades back to its own color.
  Effect(frame, h, "rune", h.left + h.width * 0.5, h.y, 6 * s, 6 * s, RED_R, RED_G, RED_B,
    1 - Smooth((e - 0.1) / 0.35), "BLEND");
end

-- Plain Text success: a soft glow blooms behind the name.
function OUTCOMES.softBloom(frame, h, e, r, g, b)
  local s, center = h.scale, h.left + h.width * 0.5;
  local bloom = Smooth(e / 0.1) * (1 - Smooth((e - 0.1) / 0.55));
  local fr, fg, fb = Mix(r, g, b, 1, 1, 1, 0.35 * bloom);
  PaintBar(h, 1 - Smooth(e / 0.4), fr, fg, fb, r * 0.28, g * 0.28, b * 0.28, r * 0.85, g * 0.85, b * 0.85);
  Effect(frame, h, "glow", center, h.y, h.width + 20 * s, 10 * s, r, g, b, 0.6 * bloom);
  Effect(frame, h, "glow", center, frame.nameOffsetY or 0, h.width + 50 * s, 34 * s, r, g, b, 0.28 * bloom);
end

-- Plain Text interruption: the bar dims to red and sinks away.
function OUTCOMES.sink(frame, h, e, r, g, b)
  local s, stopped = h.scale, h.width * h.progress;
  local base = h.y - (h.yOffset or 0);
  local q = Smooth(e / 0.45);
  Effect(frame, h, "glow", h.left + stopped * 0.5, base, stopped + 12 * s, 9 * s, RED_R, RED_G, RED_B, 0.5 * (1 - Smooth(e / 0.35)));
  Effect(frame, h, "glow", h.left + stopped, base, 12 * s, 10 * s, RED_R, RED_G, RED_B, 0.8 * (1 - Smooth(e / 0.3)));
  if h.yOffset ~= -4 * s * q then
    h.yOffset = -4 * s * q;
    bar.Layout(frame, h);
  end
  local rr, rg, rb = Mix(r, g, b, RED_R, RED_G, RED_B, 0.75);
  local fr, fg, fb = Mix(r, g, b, rr, rg, rb, Smooth(e / 0.08));
  PaintBar(h, 1 - q, fr, fg, fb, r * 0.28, g * 0.28, b * 0.28, r * 0.85, g * 0.85, b * 0.85);
end

-- Elv success: the bar flashes white, then fades. Flat, with no glow.
function OUTCOMES.flashFill(frame, h, e, r, g, b)
  local fr, fg, fb = Mix(r, g, b, 1, 1, 1, 1 - Smooth(e / 0.12));
  PaintBar(h, 1 - Smooth((e - 0.06) / 0.3), fr, fg, fb, r * 0.28, g * 0.28, b * 0.28, r * 0.85, g * 0.85, b * 0.85);
end

-- Elv interruption: the stopped bar turns red, holds, then fades.
function OUTCOMES.redBar(frame, h, e, r, g, b)
  PaintBar(h, 1 - Smooth((e - 0.3) / 0.3), 0.78, 0.17, 0.14, r * 0.28, g * 0.28, b * 0.28, r * 0.85, g * 0.85, b * 0.85);
end
bar.OUTCOMES = OUTCOMES;

-- A separate overlay lets tracking clear immediately while the outcome plays on the same object.
-- Stale casts, target changes, settings and layout changes never keep an outcome overlay.
-- A preview outcome passes the sample name instead of an object GUID and stays on that sample.
function bar.Outcome(frame, objectGUID, kind, progress, sample)
  local style, db = ns.styles.Get(), EnhancedSoftInteractDB;
  local name = style.castBar and style.castBar[kind];
  local effect, length = OUTCOMES[name], LENGTH[name];
  if not db.animationsEnabled or not effect then return end
  local holder = frame.castFinish;
  holder.sourceRed, holder.sourceGreen, holder.sourceBlue = frame.castBar.sourceRed, frame.castBar.sourceGreen, frame.castBar.sourceBlue;
  holder.progress = kind == "success" and 1 or math.max(0, math.min(1, progress or 0));
  holder.outcome, holder.yOffset, holder.fx = true, nil, holder.fx or {};
  bar.Layout(frame, holder);
  -- Outcomes paint solid fills; the next normal Paint restores gradients and colors.
  for i = 1, 2 do holder["fill" .. i]:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1)); end
  holder.red = nil;
  holder.runeGlow:Hide();
  holder:Show();
  local started, size = GetTime(), ns.styles.Size(db);
  holder.endsAt = started + length;
  local r, g, b = holder.sourceRed or 0, holder.sourceGreen or 0, holder.sourceBlue or 0;
  local function Eligible()
    if not db.castBarEnabled or not db.animationsEnabled or not frame:IsShown()
        or ns.styles.Get() ~= style or ns.styles.Size(db) ~= size then return false end
    if sample then return frame.sampleName == sample end
    if not db.enabled or frame.inEditMode or frame.sampleName then return false end
    -- Follow what the HUD shows: target updates wait for the outcome (OnSoftInteractChanged), and a
    -- target that simply went away (a looted node) keeps its outcome while the HUD fades.
    if frame.lastTarget == nil then return true end
    return not frame.fadingOut and frame.lastTarget == objectGUID;
  end
  local function Update()
    holder.fxUsed = 0;
    local elapsed = GetTime() - started;
    local running = elapsed < length and Eligible();
    if running then effect(frame, holder, elapsed, r, g, b); end
    for i = holder.fxUsed + 1, #holder.fx do holder.fx[i]:Hide(); end
    if not running then holder:Hide(); end
  end
  holder:SetScript("OnUpdate", Update);
  Update();
end

-- Seconds left on a playing outcome, so the HUD can finish it before fading out.
function bar.OutcomeRemaining(frame)
  local holder = frame.castFinish;
  if not holder:IsShown() or not holder.endsAt then return 0 end
  return math.max(0, holder.endsAt - GetTime());
end

-- Settings preview cast: a pretend cast on the sample, drawing only this addon's bar and outcomes.
-- "loop" plays a full cast with its success, then a cast interrupted at HOLD, and repeats.
-- "hold" keeps the bar still at HOLD. nil stops it. onStart runs as each looped cast begins.
local PREVIEW_CAST, PREVIEW_HOLD, PREVIEW_PAUSE = 2, 0.6, 1;

local function PreviewStep(driver)
  local frame, db = driver.frame, EnhancedSoftInteractDB;
  if frame.sampleName ~= driver.name or ns.styles.Get() ~= driver.style or not db.castBarEnabled then
    driver:Hide();
    bar.Hide(frame);
    return;
  end
  if driver.mode == "hold" then
    if not frame.castBar:IsShown() then
      bar.Paint(frame, ns.GetTypeColor(frame.colorKey, false));
      bar.SetProgress(frame, PREVIEW_HOLD);
    end
    return;
  end
  local now = GetTime();
  if not driver.started then
    driver.started, driver.endedAt, driver.count = now, nil, driver.count + 1;
    bar.Paint(frame, ns.GetTypeColor(frame.colorKey, false));
    bar.SetProgress(frame, 0);
    if driver.onStart then driver.onStart(); end
    return;
  end
  local interrupt = driver.count % 2 == 0;
  local stop = interrupt and PREVIEW_HOLD or 1;
  if not driver.endedAt then
    local progress = (now - driver.started) / PREVIEW_CAST;
    if progress < stop then bar.SetProgress(frame, progress); return end
    driver.endedAt = now;
    bar.Hide(frame);
    bar.Outcome(frame, nil, interrupt and "interrupt" or "success", stop, driver.name);
  elseif now - driver.endedAt >= PREVIEW_PAUSE and bar.OutcomeRemaining(frame) == 0 then
    driver.started = nil;
  end
end

-- Created with the HUD, never later: Forever's gamepad navigation hooks CreateFrame, and a frame
-- created inside the open settings page taints it (see Feat\Settings.lua).
function bar.CreatePreviewDriver(frame)
  local driver = CreateFrame("Frame", nil, frame);
  driver:Hide();
  driver.frame = frame;
  driver:SetScript("OnUpdate", PreviewStep);
  frame.previewCast = driver;
end

function bar.Preview(frame, mode, onStart)
  local driver = frame.previewCast;
  local style = ns.styles.Get();
  if not (mode and frame.sampleName and EnhancedSoftInteractDB.castBarEnabled and style.castBar) then
    if driver and driver:IsShown() then
      driver:Hide();
      bar.Hide(frame);
    end
    return;
  end
  driver.onStart = onStart;
  if driver:IsShown() and driver.mode == mode and driver.name == frame.sampleName and driver.style == style then return end
  bar.Hide(frame);
  driver.mode, driver.name, driver.style = mode, frame.sampleName, style;
  driver.started, driver.endedAt, driver.count = nil, nil, 0;
  driver:Show();
  PreviewStep(driver);
end
