local _, ns = ...;
local log = ns.debugLog;
local PAGE_SIZE, INTERVAL = 50, log.interval;
local window, dirty, lastRevision;
local sources = { game = true, range_check = true, snapshot = true };
local sections = { event = true, animations = true, range = true };
local PRESETS = { { "All", false }, { "30 sec", 30 }, { "2 min", 120 }, { "10 min", 600 } };

local function Bounds(w)
  if w.custom then return w.fromTime, w.toTime; end
  local finish = w.frozenAt or log.Now();
  return w.duration and math.max(0, finish - w.duration) or 0, finish;
end
local function Filters(w)
  local first, last = Bounds(w);
  return { sources = sources, sections = sections, from = first, to = last };
end
local function Matching(w, all) return log.Match(Filters(w), all); end
local function Export(w, list, first, last, all) return log.Export(list, first, last, Filters(w), all); end

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
    w.viewKey, w.resetScroll = nil, true;
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
    w.frozenAt = v and log.Now() or nil;
  end);
  w.capture = Check("Record live changes", 610, -145, true, function(v) log.liveCapture = v; log.ResetLive(); end);
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
    local now = log.Now();
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
  local function Show(value, reset)
    local position = reset and 0 or (scroll:GetVerticalScroll() or 0);
    w.shownText = value;
    text:SetText(value);
    text:SetCursorPosition(0);
    scroll:SetVerticalScroll(math.min(position, scroll:GetVerticalScrollRange() or position));
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
    local view = { tostring(sections.event), tostring(sections.animations), tostring(sections.range) };
    for i = first, last do view[#view + 1] = tostring(list[i].sequence); end
    local key = table.concat(view, "|");
    if key ~= w.viewKey then
      Show(Export(w, list, first, last), w.resetScroll);
      w.viewKey = key;
    end
    w.resetScroll = false;
    local count, dropped = log.Count();
    local lower, upper = Bounds(w);
    if not w.inputError and not w.from:HasFocus() and not w.to:HasFocus() then
      w.from:SetText(("%.3f"):format(lower));
      w.to:SetText(("%.3f"):format(upper));
    end
    w.status:SetText(w.inputError or ("%s | Session now %.3fs | UTC timestamps | Live changes captured only while this window is open"):format(
      w.custom and "Custom range" or (w.frozenAt and "Frozen range" or "Following time"), log.Now()));
    w.count:SetText(("Showing %d-%d of %d matches | %d / %d retained | %d evicted | 50 records per view"):format(
      last > 0 and first or 0, last, #list, count, log.limit, dropped));
    w.prev:SetEnabled(first > 1);
    w.next:SetEnabled(last < #list);
    w.copy:SetEnabled(#list > 0);
    w.copyAll:SetEnabled(count > 0);
    w.clear:SetEnabled(count > 0);
    dirty = false;
    lastRevision = log.revision;
  end
  w.Refresh = Refresh;
  w.prev:SetScript("OnClick", function()
    local list = Matching(w);
    local finish = math.max(1, (w.first or 1) - 1);
    if list[finish] then w.pageEnd = list[finish].sequence; end
    w.resetScroll = true;
    text:ClearFocus(); Refresh();
  end);
  w.next:SetScript("OnClick", function()
    local list = Matching(w);
    local finish = math.min(#list, (w.last or 0) + PAGE_SIZE);
    w.pageEnd = finish < #list and list[finish].sequence or nil;
    w.resetScroll = true;
    text:ClearFocus(); Refresh();
  end);
  w.latest:SetScript("OnClick", Changed);
  local function Copy(all)
    local list = Matching(w, all);
    Show(Export(w, list, 1, #list, all), true);
    w.viewKey = nil;
    w.count:SetText(("%d records selected. Press Ctrl+C to copy; Esc resumes the view."):format(#list));
    text:SetFocus(); text:HighlightText();
    dirty = true;
  end
  w.copy:SetScript("OnClick", function() Copy(false); end);
  w.copyAll:SetScript("OnClick", function() Copy(true); end);
  w.clear:SetScript("OnClick", function()
    log.Clear();
    Changed();
  end);
  w:SetScript("OnShow", function()
    PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN);
    log.ResetLive();
    w.viewKey, w.resetScroll = nil, true;
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
    log.Sample();
    if dirty or lastRevision ~= log.revision or (w.duration and not w.frozenAt and not w.custom) then Refresh(); end
  end);
  return w;
end

ns.slashCommands.debug = function()
  window = window or CreateWindow();
  window:SetShown(not window:IsShown());
end
