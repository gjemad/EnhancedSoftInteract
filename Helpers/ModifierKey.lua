local _, ns = ...;
local ModifierKey = {};
ns.ModifierKey = ModifierKey;

local WHITE = [[Interface\Buttons\WHITE8X8]];
local GLOW_ALPHA = 0.14;
local GLOW_PERIOD = 3;
local GLOW_FLOOR = 0.72;
local MODIFIERS = {
  ALT = function() if IsAltKeyDown then return IsAltKeyDown(); end return IsKeyDown("ALT"); end,
  CTRL = function() if IsControlKeyDown then return IsControlKeyDown(); end return IsKeyDown("CTRL"); end,
  SHIFT = function() if IsShiftKeyDown then return IsShiftKeyDown(); end return IsKeyDown("SHIFT"); end,
  META = function() if IsMetaKeyDown then return IsMetaKeyDown(); end return IsKeyDown("META"); end,
};
local function Secret(value) return ns.issecretvalue and ns.issecretvalue(value) end
local Clamp = ns.Clamp;
local function Hide(data)
  data.holder:Hide();
  data.glowHolder:Hide();
  data.divider:Hide();
  for _, label in ipairs(data.labels) do label:Hide(); end
  for _, glow in ipairs(data.glows) do glow:Hide(); end
end

local function Create(cap)
  local data = { labels = {}, glows = {}, levels = {}, transitions = {}, active = 0,
    glowPulseElapsed = 0, glowPulse = 1 };
  local level = cap:GetFrameLevel();
  data.glowHolder = CreateFrame("Frame", nil, cap);
  data.glowHolder:SetPoint("CENTER");
  data.glowHolder:SetFrameLevel(level + 1);
  data.holder = CreateFrame("Frame", nil, cap);
  data.holder:SetPoint("CENTER");
  data.holder:SetFrameLevel(level + 2);
  data.divider = data.holder:CreateTexture(nil, "OVERLAY", nil, -1);
  data.divider:SetTexture(WHITE);
  for i = 1, 4 do
    local glow = data.glowHolder:CreateTexture(nil, "ARTWORK");
    glow:SetTexture(WHITE);
    glow:SetBlendMode("BLEND");
    ns.styles.Snap(glow, false);
    data.glows[i] = glow;
  end
  cap.modifierKey = data;
  Hide(data);
  return data;
end
-- The core creates these frames with the key cap. Forever's gamepad navigation hooks CreateFrame, and
-- a frame created later inside the open settings page taints it (see Feat\Settings.lua).
ModifierKey.Create = Create;

-- These inputs are public binding strings, never target-name text. Read only canonical leading
-- modifiers; a remaining literal '-' is the base key in SHIFT--, rather than another separator.
local function Parse(raw, text)
  if type(text) ~= "string" or Secret(text) or text == "" or text:find("|[AT]") then return end
  if raw and (type(raw) ~= "string" or Secret(raw) or raw:find("^PAD") or raw:find("%-PAD")) then return end
  local modifiers, rest = {}, raw or "";
  while true do
    local modifier, following = rest:match("^([A-Z]+)%-(.+)$");
    if not MODIFIERS[modifier] then break end
    modifiers[#modifiers + 1] = modifier;
    rest = following;
  end
  local tokens, remaining = {}, text;
  for _ = 1, #modifiers do
    local prefix, following = remaining:match("^([^%-]+)%-(.*)$");
    if not prefix or following == "" then
      -- An unusual native provider can use a different separator. Keep its complete localized label
      -- fitted as supplied, rather than guessing labels or silently dropping part of the binding.
      return modifiers, { text }, text, true;
    end
    tokens[#tokens + 1] = prefix;
    remaining = following;
  end
  return modifiers, tokens, remaining, false;
end

function ModifierKey.Reset(frame)
  local data = frame.keyCap.modifierKey;
  if not data then return end
  data.levels, data.transitions, data.active, data.activeTransition = {}, {}, 0, nil;
  data.glowPulseElapsed, data.glowPulse = 0, 1;
  data.watching = false;
  for _, glow in ipairs(data.glows) do glow:SetAlpha(0); glow:Hide(); end
  if data.managed and data.layout then ModifierKey.Paint(frame); end
end

function ModifierKey.Prepare(frame, raw, text)
  local cap = frame.keyCap;
  local modifiers, tokens, base, fallback = Parse(raw, text);
  local data = cap.modifierKey;
  if not modifiers then
    if data then
      data.managed = false;
      ModifierKey.Reset(frame);
      Hide(data);
    end
    cap.text:SetAlpha(1);
    return false;
  end
  data = data or Create(cap);
  local style = ns.styles.Get();
  if not data.managed or data.raw ~= raw or data.text ~= text or data.style ~= style or data.keyStyle ~= cap.keyStyle then
    data.managed = true;
    data.raw, data.text, data.style, data.keyStyle = raw, text, style, cap.keyStyle;
    data.modifiers, data.tokens, data.base, data.fallback = modifiers, tokens, base, fallback;
    data.layout = nil;
    ModifierKey.Reset(frame);
  end
  cap.text:SetAlpha(0); --keep its complete native text for input identity and existing integrations
  return true;
end

local measure;
local function Width(text, path, size)
  measure = measure or ns.CreateMeasure();
  measure:SetFont(path, size, "");
  measure:SetText(text);
  local width = measure:GetStringWidth();
  return Secret(width) and size * #text * 0.7 or width;
end

-- Latin cap/x-height bounds measured from the packaged Friz/PT Sans families. Unknown fonts and
-- non-Latin labels reserve their complete font box. Only public key text is measured here.
local function HeightRatio(text, path)
  path = path:lower();
  if not (path:find("frizqt__", 1, true) or path:find("ptsans", 1, true)) then return 1 end
  local ratio = 0.22;
  for letter in text:gmatch(".") do
    if letter:byte() > 127 then return 1 end
    local height = letter:match("[gjpqy]") and 0.98 or letter:match("[A-Z0-9bdfhiklt]") and 0.78
      or letter:match("[ace mnorsuvwxz]") and 0.58 or letter == "-" and 0.22 or 0.9;
    ratio = math.max(ratio, height);
  end
  return ratio;
end

local function Fit(text, path, maximum, width, height, shadow)
  local low, high = 0.5, maximum;
  local ratio = HeightRatio(text, path);
  if Width(text, path, maximum) + shadow <= width and maximum * ratio + shadow <= height then return maximum end
  for _ = 1, 16 do
    local middle = (low + high) * 0.5;
    if Width(text, path, middle) + shadow <= width and middle * ratio + shadow <= height then
      low = middle;
    else
      high = middle;
    end
  end
  return math.max(0.5, math.floor(low * 100) / 100);
end

local function Label(data, index)
  if not data.labels[index] then
    local label = data.holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    label:SetWordWrap(false);
    label:SetJustifyH("CENTER");
    data.labels[index] = label;
  end
  return data.labels[index];
end

function ModifierKey.Layout(frame, db)
  local cap, style = frame.keyCap, ns.styles.Get();
  local data = cap.modifierKey;
  if not data or not data.managed or cap.isGlyph then return end
  local size = ns.styles.Size(db);
  local scale = ns.styles.ButtonScale(db);
  local width, height = cap.capWidth, cap.capHeight;
  local pixel = ns.styles.Pixel(frame);
  local path, maximum = ns.styles.Font(db), size.keyFontSize * scale;
  local shadow = style.flatKey and 0 or math.min(1, scale);
  local top, bottom = height * 0.5, -height * 0.5;
  local padding = math.min(2 * size.inputScale * scale, width * 0.12, height * 0.12);
  local left, right = -width * 0.5 + padding, width * 0.5 - padding;
  local slots, fields = {}, {};
  local function Add(text, fontSize, x, y, modifier)
    slots[#slots + 1] = { text = text, size = fontSize, x = x, y = y, modifier = modifier };
  end
  local function Group(parts, fontSize, y, prefixCount, neutralHyphen)
    local total = 0;
    for _, part in ipairs(parts) do total = total + Width(part, path, fontSize); end
    local nudge = style.flatKey and 0 or fontSize * (0.06 - ns.InkOffset(table.concat(parts), path));
    local x, modifierIndex = -total * 0.5 + nudge, 0;
    for _, part in ipairs(parts) do
      local advance = Width(part, path, fontSize);
      local modifier;
      if part ~= "-" and modifierIndex < prefixCount then
        modifierIndex = modifierIndex + 1;
        modifier = modifierIndex;
      end
      Add(part, fontSize, x + advance * 0.5, y, modifier);
      if part == "-" and neutralHyphen then slots[#slots].neutral = true; end
      x = x + advance;
    end
  end
  local divider;
  if #data.modifiers >= 2 and not data.fallback then
    local ratio = (top - bottom) / 21.76;
    local split = bottom + 9 * ratio;
    local offset = not style.ownKey and not cap.classic and cap.keyStyle ~= "classic" and -pixel or 0;
    local mainBottom, mainTop = split + 0.75 * ratio, top - padding;
    local lowerBottom, lowerTop = bottom + padding + offset, split - 0.75 * ratio + offset;
    fields.main = { left, mainBottom, right, mainTop };
    fields.lower = { left, lowerBottom, right, lowerTop };
    local mainSize = Fit(data.base, path, math.min(maximum, 13.5 * ratio), right - left, mainTop - mainBottom, shadow);
    local nudge = style.flatKey and 0 or mainSize * (0.06 - ns.InkOffset(data.base, path));
    Add(data.base, mainSize, nudge, (mainBottom + mainTop) * 0.5 - mainSize * 0.04);
    local lowerText = table.concat(data.tokens, "-");
    local lowerMaximum = style.flatKey and math.min(maximum * 0.7, 9.5 * ratio) or 9.5 * ratio;
    local lowerSize = Fit(lowerText, path, lowerMaximum, right - left, lowerTop - lowerBottom, shadow);
    local parts = {};
    for i, token in ipairs(data.tokens) do
      if i > 1 then parts[#parts + 1] = "-"; end
      parts[#parts + 1] = token;
    end
    Group(parts, lowerSize, (lowerBottom + lowerTop) * 0.5 + lowerSize * 0.12, #data.modifiers, true);
    divider = split;
    data.secondaryOffset = offset;
  else
    fields.inline = { left, bottom + padding, right, top - padding };
    local fontSize = Fit(data.text, path, maximum, right - left, top - bottom - padding * 2, shadow);
    if #data.modifiers == 1 and not data.fallback then
      Group({data.tokens[1], "-", data.base}, fontSize, -fontSize * 0.04, 1, false);
    else
      local nudge = style.flatKey and 0 or fontSize * (0.06 - ns.InkOffset(data.text, path));
      Add(data.text, fontSize, nudge, -fontSize * 0.04);
    end
    data.secondaryOffset = 0;
  end
  data.holder:SetSize(width, height);
  data.glowHolder:SetSize(width, height);
  data.layout = { width = width, height = height, pixel = pixel, path = path, slots = slots,
    divider = divider, flat = style.flatKey, classic = cap.classic, shadow = shadow, fields = fields,
    top = top, bottom = bottom };
  for i, slot in ipairs(slots) do
    local label = Label(data, i);
    label:SetFont(path, slot.size, "");
    label:SetShadowOffset(shadow, -shadow);
    label:SetText(slot.text);
    label:ClearAllPoints();
    label:SetPoint("CENTER", data.holder, "CENTER", slot.x, slot.y);
  end
  for i = #slots + 1, #data.labels do data.labels[i]:Hide(); end
  -- Feather inward from an inset inside the visible face; no light or sharp outline is drawn outside.
  local inset = 1.5 * pixel;
  if not style.ownKey and not cap.classic and cap.icon:GetAtlas() == "plunderstorm-icon-key" then
    -- The native face's chamfer needs six of its 65 source pixels to keep light out of the cutouts.
    inset = math.max(inset, 6 * height / 65);
  end
  inset = math.min(inset, width * 0.1, (top - bottom) * 0.1);
  local glow = { left = -width * 0.5 + inset, right = width * 0.5 - inset,
    bottom = bottom + inset, top = top - inset, inset = inset,
    peakAlpha = GLOW_ALPHA, blendMode = "BLEND", pulsePeriod = GLOW_PERIOD, pulseFloor = GLOW_FLOOR };
  local w, h = glow.right - glow.left, glow.top - glow.bottom;
  local thickness = math.min(3 * pixel, w * 0.25, h * 0.25);
  glow.thickness = thickness;
  glow.edges = {
    { edge = "left", x = glow.left, y = glow.bottom, width = thickness, height = h,
      orientation = "HORIZONTAL", startAlpha = GLOW_ALPHA, endAlpha = 0 },
    { edge = "right", x = glow.right - thickness, y = glow.bottom, width = thickness, height = h,
      orientation = "HORIZONTAL", startAlpha = 0, endAlpha = GLOW_ALPHA },
    { edge = "bottom", x = glow.left, y = glow.bottom, width = w, height = thickness,
      orientation = "VERTICAL", startAlpha = GLOW_ALPHA, endAlpha = 0 },
    { edge = "top", x = glow.left, y = glow.top - thickness, width = w, height = thickness,
      orientation = "VERTICAL", startAlpha = 0, endAlpha = GLOW_ALPHA },
  };
  data.layout.glow = glow;
  for i, edge in ipairs(glow.edges) do
    local texture = data.glows[i];
    texture:ClearAllPoints();
    texture:SetPoint("BOTTOMLEFT", data.glowHolder, "CENTER", edge.x, edge.y);
    texture:SetSize(edge.width, edge.height);
  end
  data.glowShade = nil;
  if divider then
    data.divider:ClearAllPoints();
    data.divider:SetPoint("CENTER", data.holder, "CENTER", 0, divider);
    data.divider:SetSize(math.max(pixel, width - padding * 2), 0.45 * size.inputScale * scale);
  end
  ModifierKey.Paint(frame);
end

function ModifierKey.Paint(frame)
  local cap = frame.keyCap;
  local data = cap.modifierKey;
  if not data or not data.managed or not data.layout or cap.isGlyph or not cap:IsShown() then
    if data then Hide(data); end
    return;
  end
  local layout = data.layout;
  local depth = cap.pressDepth or 0;
  local scale = layout.flat and 1 or math.max(0.1, 1 - 2 * depth / layout.height);
  local shade = ((frame.outOfRange or frame.requirementText ~= nil) and 0.75 or 1)
    * (layout.flat and 1 or (cap.pressShade or 1));
  cap.text:SetAlpha(0);
  data.holder:Show(); data.glowHolder:Show();
  data.holder:SetScale(scale);
  data.holder:SetPoint("CENTER", cap, "CENTER", 0, layout.classic and -depth or 0);
  data.glowHolder:SetScale((layout.flat or layout.classic) and 1 or scale);
  for i, slot in ipairs(layout.slots) do
    local label = data.labels[i];
    local level = slot.modifier and (data.levels[slot.modifier] or 0);
    local value = (level and (0.55 + 0.45 * level) or slot.neutral and 0.55 or 1) * shade;
    label:SetTextColor(value, value, value);
    label:Show();
  end
  data.divider:SetVertexColor(0.4 * shade, 0.4 * shade, 0.4 * shade, 0.65);
  data.divider:SetShown(layout.divider ~= nil);
  for i, glow in ipairs(data.glows) do
    if data.glowShade ~= shade then
      local edge = layout.glow.edges[i];
      glow:SetGradient(edge.orientation, CreateColor(shade, shade, shade, edge.startAlpha), CreateColor(shade, shade, shade, edge.endAlpha));
    end
    glow:SetAlpha(data.active * data.glowPulse);
    glow:SetShown(#data.modifiers > 0 and data.active > 0);
  end
  data.glowShade = shade;
end

local function Step(current, transition, target, elapsed)
  if current == target and (not transition or transition.target == target) then return current, nil end
  if not transition or transition.target ~= target then
    transition = { from = current, target = target, elapsed = 0, duration = target == 1 and 0.05 or 0.15 };
  end
  transition.elapsed = transition.elapsed + elapsed;
  local t = Clamp(transition.elapsed / transition.duration, 0, 1);
  local eased = target == 1 and 1 - (1 - t) * (1 - t) or t * t * (3 - 2 * t);
  return transition.from + (target - transition.from) * eased, transition;
end

function ModifierKey.Poll(frame, watching, elapsed)
  local data = frame.keyCap.modifierKey;
  if not data or not data.managed then return end
  if not watching then
    if data.watching or data.active > 0 then ModifierKey.Reset(frame); end
    return;
  end
  data.watching = true;
  if #data.modifiers == 0 then return end
  elapsed = math.max(0, elapsed or 0);
  local complete, changed = true, false;
  for i, modifier in ipairs(data.modifiers) do
    local down = MODIFIERS[modifier]();
    down = not Secret(down) and down and true or false;
    complete = complete and down;
    local from = data.levels[i] or 0;
    data.levels[i], data.transitions[i] = Step(from, data.transitions[i], down and 1 or 0, elapsed);
    changed = changed or data.levels[i] ~= from;
  end
  local from = data.active;
  data.active, data.activeTransition = Step(data.active, data.activeTransition, complete and 1 or 0, elapsed);
  if data.active > 0 then
    data.glowPulseElapsed = (data.glowPulseElapsed + elapsed) % GLOW_PERIOD;
    data.glowPulse = GLOW_FLOOR + (1 - GLOW_FLOOR) * (0.5 + 0.5 * math.cos(2 * math.pi * data.glowPulseElapsed / GLOW_PERIOD));
  else
    data.glowPulseElapsed, data.glowPulse = 0, 1;
  end
  if changed or data.active ~= from then ModifierKey.Paint(frame);
  elseif data.active > 0 then
    -- A settled hold only changes four glow alphas; text, gradients and geometry remain untouched.
    for _, glow in ipairs(data.glows) do glow:SetAlpha(data.active * data.glowPulse); end
  end
end
