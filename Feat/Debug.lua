local _, ns = ...;
local frame, issecretvalue = ns.frame, ns.issecretvalue;

-- Session-only structured diagnostics. The ring owns at most 2000 records, including live snapshots.
-- Filters never change capture. JSON lines are escaped before display and contain no secret values.
local LIMIT, PAGE_SIZE, INTERVAL = 2000, 50, 0.25;
local started = GetTime();
local session = date("!%Y-%m-%dT%H:%M:%SZ");
local records, head, count, sequence, dropped = {}, 1, 0, 0, 0;
local lastGUID, window, dirty, lastSnapshot;
local sources = { game = true, range_check = true, snapshot = true };
local sections = { event = true, animations = true, range = true };

local function Safe(v)
  if issecretvalue(v) then return "<secret>" end
  if v == nil then return "<nil>" end
  return v;
end

local function Number(v)
  if issecretvalue(v) then return "<secret>" end
  if type(v) ~= "number" then return "<nil>" end
  return math.floor(v * 1000 + 0.5) / 1000;
end

local function Quote(s)
  -- Escape pipes too, so names and atlas markup cannot become WoW color/texture escapes in the edit box.
  return '"' .. s:gsub('[%z\1-\31\\"|]', function(c)
    if c == '"' then return '\\"' end
    if c == '\\' then return '\\\\' end
    return ("\\u%04x"):format(c:byte());
  end) .. '"';
end

local function JSON(v)
  v = Safe(v);
  local kind = type(v);
  if kind == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return '"<nonfinite>"' end
    return ("%.3f"):format(v):gsub(",", ".");
  end
  if kind == "boolean" then return v and "true" or "false" end
  if kind ~= "table" then return Quote(tostring(v)); end
  local keys, fields = {}, {};
  for key in pairs(v) do keys[#keys + 1] = key; end
  table.sort(keys);
  for _, key in ipairs(keys) do fields[#fields + 1] = Quote(key) .. ":" .. JSON(v[key]); end
  return "{" .. table.concat(fields, ",") .. "}";
end

local function Layer(tex)
  local r, g, b, a = tex:GetVertexColor();
  local w, h = tex:GetSize();
  return { shown = Safe(tex:IsVisible()), width = Number(w), height = Number(h),
    red = Number(r), green = Number(g), blue = Number(b), vertex_alpha = Number(a),
    alpha = Number(tex:GetAlpha()), blend = Safe(tex:GetBlendMode()) };
end

local function Animations()
  local rgb = frame.rgb or {};
  local layers = {};
  for _, name in ipairs({ "iconGlow", "lineLow", "lineLowGlow", "lineHigh", "flash", "shadow" }) do
    layers[name] = Layer(frame[name]);
  end
  return { shown = Safe(frame:IsVisible()), alpha = Number(frame:GetAlpha()),
    scale = Number(frame:GetEffectiveScale()), glow_scale = Number(frame.glowScale),
    color = { red = Number(rgb[1]), green = Number(rgb[2]), blue = Number(rgb[3]) },
    press_depth = Number(frame.keyCap.pressDepth), layers = layers,
    playing = { fade = Safe(frame.fader:IsPlaying()), pulse = Safe(frame.pulse:IsPlaying()),
      switch = Safe(frame.switchAnim:IsPlaying()), ripple = Safe(frame.ripple:IsPlaying()),
      press_in = Safe(frame.pressIn:IsPlaying()), press_out = Safe(frame.pressOut:IsPlaying()) } };
end

local function Range()
  local unit, guid = "softinteract", UnitGUID("softinteract");
  local same = "<nil>";
  if issecretvalue(guid) or issecretvalue(frame.inRangeTarget) then
    same = "<secret>";
  elseif guid and frame.inRangeTarget then
    same = guid == frame.inRangeTarget;
  end
  local key = frame.colorKey;
  local cursor = key and (key:match("^Cursor Unable(.+)$") or key:match("^Cursor (.+)$"));
  return { name = Safe(UnitName(unit)), guid = Safe(guid), drawn = Safe(frame.iconSource),
    shown = Safe(key), cursor = Safe(cursor),
    interact_range = Safe(UnitIsInInteractRange and UnitIsInInteractRange(unit)),
    spell_range = Safe(cursor and ns.SpellRangeCheck and ns.SpellRangeCheck(cursor, unit)),
    casting = Safe(UnitCastingInfo("player")), channeling = Safe(UnitChannelInfo("player")),
    out_of_range = Safe(frame.outOfRange), last_in_range_target = same };
end

local function At(index) return records[(head + index - 2) % LIMIT + 1]; end

local function Append(source, event, animations, range)
  sequence = sequence + 1;
  local record = { sequence = sequence, timestamp = date("!%Y-%m-%dT%H:%M:%SZ"),
    elapsed = Number(GetTime() - started), source = source, event = event,
    animations = animations, range = range };
  if count == LIMIT then
    records[head] = record;
    head = head % LIMIT + 1;
    dropped = dropped + 1;
  else
    count = count + 1;
    records[(head + count - 2) % LIMIT + 1] = record;
  end
  dirty = true;
end

function ns.DebugSoftTarget(oldGUID, newGUID, hasCursor, resolvedKey, iconKey, talkBadge, outOfRange)
  local same = "<secret>";
  if not issecretvalue(newGUID) and not issecretvalue(lastGUID) then same = newGUID == lastGUID; end
  lastGUID = newGUID;
  local unit, cap = "softinteract", frame.keyCap;
  local r, g, b = ns.GetTypeColor(iconKey, outOfRange);
  local key1, key2 = GetBindingKey("INTERACTTARGET");
  local event = { name = "PLAYER_SOFT_INTERACT_CHANGED", old_guid = Safe(oldGUID), new_guid = Safe(newGUID),
    same_target = same,
    unit = { name = Safe(UnitName(unit)), player = Safe(UnitIsPlayer(unit)),
      object = Safe(UnitIsGameObject and UnitIsGameObject(unit)),
      interactable = Safe(UnitIsInteractable and UnitIsInteractable(unit)),
      attackable = Safe(UnitCanAttack("player", unit)) },
    icon = { has_cursor = Safe(hasCursor), source = Safe(frame.iconSource), resolved = Safe(resolvedKey),
      key = Safe(iconKey), red = Number(r), green = Number(g), blue = Number(b),
      default_color = not (outOfRange or ns.IsUnableKey(iconKey) or ns.typeColors[iconKey]) and true or false,
      talk_badge = Safe(talkBadge), nudge_x = Number(frame.iconNudgeX or 0), nudge_y = Number(frame.iconNudgeY or 0) },
    key = { binding1 = Safe(key1), binding2 = Safe(key2), gamepad_active = Safe(ns.gamepadActive),
      gamepad_ui = ns.IsGamepadUI and ns.IsGamepadUI() or false,
      glyph = Safe(ns.GamepadInteractGlyph and ns.GamepadInteractGlyph()) },
    layout = { width = Number(frame.boxWidth), name_width = Number(frame.nameWidth),
      height = Number(EnhancedSoftInteractDB.hudHeight), key_shown = Safe(cap:IsShown()),
      key_text = Safe(cap.text:GetText()), key_width = Number(cap.capWidth), key_height = Number(cap.capHeight) } };
  Append(frame.fromRangeCheck and "range_check" or "game", event, Animations(), Range());
end

-- Keep the triggers for short animations and changes to input/persistence, even with the window closed.
local watchedCVars = { softtargetinteract = true, softtargeticonenemy = true, softtargeticoninteract = true,
  softtargeticongameobject = true, softtargetlowpriorityicons = true, softtargettooltipinteract = true,
  softtargetnameplateinteract = true, softtargetnameplatesize = true, gamepadenable = true };
local watcher = CreateFrame("Frame");
watcher:SetScript("OnEvent", function(_, name, arg1, arg2)
  if name == "CVAR_UPDATE" and (issecretvalue(arg1) or type(arg1) ~= "string" or not watchedCVars[arg1:lower()]) then return end
  Append("game", { name = name, arg1 = Safe(arg1), arg2 = Safe(arg2) }, Animations(), Range());
end);
table.insert(ns.onLoad, function()
  for _, name in ipairs({ "PLAYER_SOFT_TARGET_INTERACTION", "UPDATE_BINDINGS", "GAME_PAD_ACTIVE_CHANGED", "CVAR_UPDATE" }) do
    watcher:RegisterEvent(name);
  end
  -- This event and gamepad UI belong to Forever; retail still logs GAME_PAD_ACTIVE_CHANGED.
  if ns.IsGamepadUI then watcher:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION"); end
end);

-- The time picker uses session seconds, which stay unambiguous across midnight and clock changes.
-- Recent ranges move with the clock. Freeze fixes their end; Custom uses inclusive From/To bounds.
local PRESETS = { { "All", false }, { "30 sec", 30 }, { "2 min", 120 }, { "10 min", 600 } };
local function Bounds(w)
  if w.custom then return w.fromTime, w.toTime; end
  local finish = Number(w.frozenAt or GetTime() - started);
  return w.duration and math.max(0, finish - w.duration) or 0, finish;
end

local function Matching(w, all)
  local list = {};
  local first, last = Bounds(w);
  for i = 1, count do
    local record = At(i);
    local hasSection = sections.animations or sections.range or (sections.event and record.event);
    if all or (hasSection and sources[record.source] and record.elapsed >= first and record.elapsed <= last) then
      list[#list + 1] = record;
    end
  end
  return list;
end

local function ExportRecord(record, all)
  local result = { sequence = record.sequence, timestamp = record.timestamp, elapsed = record.elapsed,
    source = record.source };
  for _, name in ipairs({ "event", "animations", "range" }) do
    if all or sections[name] then result[name] = record[name]; end
  end
  return JSON(result);
end

local function Export(w, list, first, last, all)
  local lower, upper = Bounds(w);
  local version, build, _, interface = GetBuildInfo();
  local lines = { JSON({ format = "esi-debug-jsonl", schema = 1, session_started = session,
    client_version = Safe(version), client_build = Safe(build), interface = Safe(interface),
    retained = count, limit = LIMIT, evicted = dropped, exported = math.max(0, last - first + 1),
    scope = all and "all_retained" or "filtered", from_elapsed = all and 0 or Number(lower),
    to_elapsed = all and Number(GetTime() - started) or Number(upper),
    sources = all and { game = true, range_check = true, snapshot = true } or sources,
    sections = all and { event = true, animations = true, range = true } or sections,
    live_capture = w.capture:GetChecked() and true or false,
    live_interval = INTERVAL, live_scope = "changed snapshots while debug window is open",
    missing_values = "<nil>", restricted_values = "<secret>", timestamps = "UTC; elapsed is session seconds" }) };
  for i = first, last do lines[#lines + 1] = ExportRecord(list[i], all); end
  return table.concat(lines, "\n");
end

local function CreateWindow()
  local w = CreateFrame("Frame", "EnhancedSoftInteractDebug", UIParent, "PortraitFrameTemplate");
  w:Hide();
  w:SetSize(940, 580);
  w:SetPoint("CENTER");
  w:SetFrameStrata("DIALOG");
  w:SetToplevel(true);
  w:SetMovable(true);
  w:EnableMouse(true);
  w:RegisterForDrag("LeftButton");
  w:SetClampedToScreen(true);
  w:SetScript("OnDragStart", w.StartMoving);
  w:SetScript("OnDragStop", w.StopMovingOrSizing);
  w:SetBorder("HeldBagLayout");
  local offset = ns.iconArtOffsets["cursor interact"] or {0, 0};
  w:SetPortraitAtlasRaw("Crosshair_interact_64");
  w:SetPortraitTextureSizeAndOffset(36, -4 - math.floor(offset[1] * 36 / 64 + 0.5),
    1 + math.floor(offset[2] * 36 / 64 + 0.5));
  w:SetTitle("Enhanced Soft Interact Debug Log");
  table.insert(UISpecialFrames, w:GetName());
  w.pageEnd = nil;

  local function Label(value, x, y)
    local label = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
    label:SetPoint("TOPLEFT", x, y);
    label:SetText(value);
    return label;
  end
  local function Button(value, width, x, y)
    local button = CreateFrame("Button", nil, w, "SharedButtonTemplate");
    button:SetSize(width, 24);
    button:SetPoint("TOPLEFT", x, y);
    button:SetText(value);
    return button;
  end
  local Refresh;
  local function Changed()
    w.inputError = nil;
    w.text:ClearFocus();
    w.pageEnd = nil;
    dirty = true;
    Refresh();
  end
  local function Check(value, x, y, enabled, callback)
    local button = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate");
    button:SetSize(24, 24);
    button:SetPoint("TOPLEFT", x, y);
    button.Text:SetText(value);
    button:SetChecked(enabled);
    button:SetScript("OnClick", function(self) callback(self:GetChecked() and true or false); Changed(); end);
    return button;
  end
  -- Three columns keep each group on its own alignment, with matching checkbox rows.
  local DATA_X, SOURCE_X, TIME_X = 18, 214, 430;
  local function Heading(value, x)
    local label = Label(value, x, -51);
    label:SetFontObject("GameFontNormal");
  end
  Heading("Include data", DATA_X);
  Heading("Include sources", SOURCE_X);
  Heading("Timespan", TIME_X);
  for _, x in ipairs({ 190, 406 }) do
    local divider = w:CreateTexture(nil, "ARTWORK");
    divider:SetTexture("Interface\\Buttons\\WHITE8X8");
    divider:SetVertexColor(1, 0.82, 0, 0.2);
    divider:SetSize(1, 123);
    divider:SetPoint("TOPLEFT", x, -48);
  end
  w.eventFilter = Check("Events", DATA_X, -73, true, function(v) sections.event = v; end);
  w.animationsFilter = Check("Animations", DATA_X, -101, true, function(v) sections.animations = v; end);
  w.rangeFilter = Check("Range", DATA_X, -129, true, function(v) sections.range = v; end);
  w.gameFilter = Check("Game events", SOURCE_X, -73, true, function(v) sources.game = v; end);
  w.checkFilter = Check("Range checks", SOURCE_X, -101, true, function(v) sources.range_check = v; end);
  w.liveFilter = Check("Live snapshots", SOURCE_X, -129, true, function(v) sources.snapshot = v; end);
  w.presets = {};
  for i, preset in ipairs(PRESETS) do
    local duration = preset[2];
    local button = Button(preset[1], 72, TIME_X + (i - 1) * 78, -73);
    button:SetScript("OnClick", function()
      w.custom, w.duration = false, duration;
      Changed();
    end);
    w.presets[i] = button;
  end
  w.freeze = Check("Freeze time", TIME_X, -145, false, function(v)
    w.frozenAt = v and GetTime() - started or nil;
  end);
  w.capture = Check("Record live changes", 610, -145, true, function() lastSnapshot = nil; end);
  local function Input(x)
    local input = CreateFrame("EditBox", nil, w, "InputBoxTemplate");
    input:SetSize(85, 22);
    input:SetPoint("TOPLEFT", x, -111);
    input:SetAutoFocus(false);
    input:SetMaxLetters(12);
    input:SetScript("OnEscapePressed", input.ClearFocus);
    return input;
  end
  Label("From", TIME_X, -119);
  w.from = Input(470);
  Label("To", 570, -119);
  w.to = Input(600);
  w.apply = Button("Apply", 72, 704, -111);
  Label("Session seconds", 788, -119);
  w.apply:SetScript("OnClick", function()
    local first, last = tonumber(w.from:GetText()), tonumber(w.to:GetText());
    local now = GetTime() - started;
    if not first or not last or first < 0 or last < first or last > now + 0.001 then
      w.inputError = "Enter session seconds with 0 <= From <= To <= current time.";
      w.status:SetText(w.inputError);
      return;
    end
    w.from:ClearFocus(); w.to:ClearFocus();
    w.custom, w.fromTime, w.toTime = true, first, last;
    Changed();
  end);
  w.from:SetScript("OnEnterPressed", function() w.apply:Click(); end);
  w.to:SetScript("OnEnterPressed", function() w.apply:Click(); end);
  w.status = Label("", 18, -183);
  w.status:SetWidth(900);
  w.status:SetJustifyH("LEFT");

  local scroll = CreateFrame("ScrollFrame", nil, w, "ScrollFrameTemplate");
  scroll:SetPoint("TOPLEFT", 18, -205);
  scroll:SetPoint("BOTTOMRIGHT", -32, 78);
  local text = CreateFrame("EditBox", nil, scroll);
  text:SetMultiLine(true);
  text:SetAutoFocus(false);
  text:SetMaxLetters(0);
  text:SetFontObject("GameFontHighlightSmall");
  text:SetWidth(scroll:GetWidth());
  text:SetScript("OnEscapePressed", function(self) self:ClearFocus(); dirty = true; end);
  text:SetScript("OnTextChanged", function(self, userInput)
    if userInput then self:SetText(w.shownText or ""); self:HighlightText(); end
  end);
  scroll:SetScrollChild(text);
  scroll:SetScript("OnSizeChanged", function(_, width) text:SetWidth(width); end);
  w.text = text;
  local function Show(value)
    w.shownText = value;
    text:SetText(value);
    text:SetCursorPosition(0);
    scroll:SetVerticalScroll(0);
  end
  w.count = Label("", 18, -513);
  w.prev = Button("< Older", 90, 18, -544);
  w.next = Button("Newer >", 90, 114, -544);
  w.latest = Button("Latest", 80, 210, -544);
  w.copy = Button("Copy filtered", 130, 440, -544);
  w.copyAll = Button("Copy all retained", 150, 576, -544);
  w.clear = Button("Clear", 90, 832, -544);

  function Refresh()
    if text:HasFocus() then return end
    local list = Matching(w);
    local last = #list;
    if w.pageEnd then
      last = 0;
      for i, record in ipairs(list) do if record.sequence <= w.pageEnd then last = i; end end
      if last == 0 and #list > 0 then last = math.min(PAGE_SIZE, #list); end
    end
    local first = math.max(1, last - PAGE_SIZE + 1);
    w.first, w.last, w.matches = first, last, #list;
    Show(Export(w, list, first, last));
    local lower, upper = Bounds(w);
    if not w.inputError and not w.from:HasFocus() and not w.to:HasFocus() then
      w.from:SetText(("%.3f"):format(lower));
      w.to:SetText(("%.3f"):format(upper));
    end
    w.status:SetText(w.inputError or ("%s | Session now %.3fs | UTC timestamps | Live changes captured only while this window is open"):format(
      w.custom and "Custom range" or (w.frozenAt and "Frozen range" or "Following time"), GetTime() - started));
    w.count:SetText(("Showing %d-%d of %d matches | %d / %d retained | %d evicted | 50 records per view"):format(
      last > 0 and first or 0, last, #list, count, LIMIT, dropped));
    w.prev:SetEnabled(first > 1);
    w.next:SetEnabled(last < #list);
    w.copy:SetEnabled(#list > 0);
    w.copyAll:SetEnabled(count > 0);
    w.clear:SetEnabled(count > 0);
    dirty = false;
  end
  w.Refresh = Refresh;
  w.prev:SetScript("OnClick", function()
    local list = Matching(w);
    local finish = math.max(1, (w.first or 1) - 1);
    if list[finish] then w.pageEnd = list[finish].sequence; end
    text:ClearFocus(); Refresh();
  end);
  w.next:SetScript("OnClick", function()
    local list = Matching(w);
    local finish = math.min(#list, (w.last or 0) + PAGE_SIZE);
    w.pageEnd = finish < #list and list[finish].sequence or nil;
    text:ClearFocus(); Refresh();
  end);
  w.latest:SetScript("OnClick", Changed);
  local function Copy(all)
    local list = Matching(w, all);
    Show(Export(w, list, 1, #list, all));
    w.count:SetText(("%d records selected. Press Ctrl+C to copy; Esc resumes the view."):format(#list));
    text:SetFocus(); text:HighlightText();
    dirty = true;
  end
  w.copy:SetScript("OnClick", function() Copy(false); end);
  w.copyAll:SetScript("OnClick", function() Copy(true); end);
  w.clear:SetScript("OnClick", function()
    wipe(records);
    head, count, dropped, lastSnapshot = 1, 0, 0, nil;
    Changed();
  end);
  w:SetScript("OnShow", function()
    PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN);
    lastSnapshot = nil;
    text:ClearFocus(); dirty = true;
    Refresh();
  end);
  w:SetScript("OnHide", function()
    PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE);
    text:ClearFocus(); text:SetText(""); w.shownText = nil;
  end);
  local elapsed = 0;
  w:SetScript("OnUpdate", function(_, dt)
    if not w:IsShown() then return end
    elapsed = elapsed + dt;
    if elapsed < INTERVAL then return end
    elapsed = 0;
    if w.capture:GetChecked() then
      local animations, range = Animations(), Range();
      local signature = JSON({ animations = animations, range = range });
      if signature ~= lastSnapshot then
        lastSnapshot = signature;
        Append("snapshot", nil, animations, range);
      end
    end
    if dirty or (w.duration and not w.frozenAt and not w.custom) then Refresh(); end
  end);
  return w;
end

ns.slashCommands.debug = function()
  window = window or CreateWindow();
  window:SetShown(not window:IsShown());
end
