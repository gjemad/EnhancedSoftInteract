local _, ns = ...;
local log = ns.debugLog;
local PAGE_SIZE, INTERVAL = 50, log.interval;
local window, dirty, lastRevision;
local sources = log.sources;
local sections = log.sections;
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
  -- The base template avoids Classic's extra legacy portrait and border textures.
  local w = CreateFrame("Frame", "EnhancedSoftInteractDebug", UIParent, "ButtonFrameBaseTemplate");
  w:Hide();
  w:SetSize(1000, 710);
  w:SetPoint("CENTER");
  w:SetFrameStrata("DIALOG");
  w:SetToplevel(true);
  w:SetMovable(true);
  w:EnableMouse(true);
  w:RegisterForDrag("LeftButton");
  w:SetClampedToScreen(true);
  w:SetScript("OnDragStart", w.StartMoving);
  w:SetScript("OnDragStop", w.StopMovingOrSizing);
  -- Every client defines this border layout; HeldBagLayout is missing on Era, TBC and MoP.
  w:SetBorder("ButtonFrameTemplateNoPortrait");
  w:SetPortraitShown(false);
  -- The base template omits the title fill. This native texture template selects each client's art.
  w.TitleBg = w:CreateTexture(nil, "BACKGROUND", "_UI-Frame-TitleTileBg", -6);
  w.TitleBg:SetHeight(17);
  w.TitleBg:SetPoint("TOPLEFT", 2, -3);
  w.TitleBg:SetPoint("TOPRIGHT", -2, -3);
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
    button:SetSize(width, 27);
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
  local function Check(value, x, y, enabled, callback, tooltip, viewOnly)
    local button = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate");
    button:SetSize(24, 24);
    button:SetPoint("TOPLEFT", x, y);
    button.Text:SetText(value);
    button.Text:SetFontObject("GameFontHighlightSmall");
    button:SetChecked(enabled);
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
      GameTooltip:SetText(tooltip, 1, 1, 1, 1, true);
      GameTooltip:Show();
    end);
    button:SetScript("OnLeave", function() GameTooltip:Hide(); end);
    button:SetScript("OnClick", function(self)
      callback(self:GetChecked() and true or false);
      if not viewOnly then log.Configure(w:IsShown()); end
      Changed();
    end);
    return button;
  end
  -- These native marble insets and their NineSlice layout exist in both UI families.
  local function Panel(x, y, width, height)
    local panel = CreateFrame("Frame", nil, w, "InsetFrameTemplate");
    panel:SetPoint("TOPLEFT", x, y);
    panel:SetSize(width, height);
    panel.Bg:SetVertexColor(0.55, 0.55, 0.55);
    return panel;
  end
  w.dataPanel = Panel(18, -77, 162, 208);
  w.sourcePanel = Panel(192, -77, 457, 208);
  w.timePanel = Panel(661, -77, 320, 208);
  local version, _, _, interface = GetBuildInfo();
  local client = Label(("Client %s | Interface %s"):format(version, interface), 22, -45);
  client:SetTextColor(0.7, 0.7, 0.7);
  local scope = Label("Recording selected sources while open", 661, -45);
  scope:SetTextColor(1, 0.82, 0);
  -- Three separate capture groups leave the log its full width.
  local DATA_X, SOURCE_X, TIME_X = 32, 206, 675;
  local function Heading(value, x, y)
    local label = Label(value, x, y or -91);
    label:SetFontObject("GameFontNormal");
  end
  Heading("Capture data", DATA_X);
  Heading("Capture sources", SOURCE_X);
  Heading("Time range", TIME_X);
  w.eventFilter = Check("Events", DATA_X, -120, true, function(v) sections.event = v; end,
    "Includes event names and details in new records.");
  w.animationsFilter = Check("Animations", DATA_X, -148, false, function(v) sections.animations = v; end,
    "Includes HUD layers, colors and animation state. Uses more memory.");
  w.rangeFilter = Check("Range", DATA_X, -176, false, function(v) sections.range = v; end,
    "Includes target range and tracked cast details.");
  for i, option in ipairs(log.sourceOptions) do
    local source = option[1];
    local column, row = math.floor((i - 1) / 5), (i - 1) % 5;
    w[option[3]] = Check(option[2], SOURCE_X + column * 219, -120 - row * 28,
      sources[source], function(v) sources[source] = v; end, option[4]);
  end
  local hint = Label("Sources are off by default. Live snapshots need Animations or Range data.", 22, -297);
  hint:SetTextColor(0.7, 0.7, 0.7);
  w.presets = {};
  for i, preset in ipairs(PRESETS) do
    local duration = preset[2];
    local button = Button(preset[1], 68, TIME_X + (i - 1) * 74, -120);
    button:SetScript("OnClick", function()
      w.custom, w.duration = false, duration;
      Changed();
    end);
    w.presets[i] = button;
  end
  w.freeze = Check("Freeze time", TIME_X, -247, false, function(v)
    w.frozenAt = v and log.Now() or nil;
  end, "Keeps the displayed time range fixed. Recording continues while the window is open.", true);
  local function Input(x)
    local input = CreateFrame("EditBox", nil, w, "InputBoxTemplate");
    input:SetSize(128, 24);
    input:SetPoint("TOPLEFT", x, -180);
    input:SetAutoFocus(false);
    input:SetMaxLetters(12);
    input:SetScript("OnEscapePressed", input.ClearFocus);
    return input;
  end
  Label("From", TIME_X, -161);
  w.from = Input(TIME_X + 5);
  Label("To", 829, -161);
  w.to = Input(834);
  w.apply = Button("Apply", 65, 901, -212);
  local seconds = Label("Session seconds", TIME_X, -219);
  seconds:SetTextColor(0.7, 0.7, 0.7);
  w.apply:SetScript("OnClick", function()
    local first, last = tonumber(w.from:GetText()), tonumber(w.to:GetText());
    local now = log.Now();
    if not first or not last or first < 0 or last < first or last > now + 0.001 then
      w.inputError = "Enter session seconds with 0 <= From <= To <= current time.";
      w.status:SetText(w.inputError);
      w.status:SetTextColor(1, 0.2, 0.2);
      return;
    end
    w.from:ClearFocus(); w.to:ClearFocus();
    w.custom, w.fromTime, w.toTime = true, first, last;
    Changed();
  end);
  w.from:SetScript("OnEnterPressed", function() w.apply:Click(); end);
  w.to:SetScript("OnEnterPressed", function() w.apply:Click(); end);
  Heading("Log output", 22, -326);
  w.status = Label("", 168, -329);
  w.status:SetWidth(808);
  w.status:SetJustifyH("RIGHT");

  w.logPanel = Panel(18, -350, 963, 278);
  w.logPanel.Bg:SetVertexColor(0.25, 0.25, 0.25);

  local scroll = CreateFrame("ScrollFrame", nil, w, "ScrollFrameTemplate");
  scroll:SetPoint("TOPLEFT", w.logPanel, "TOPLEFT", 12, -10);
  scroll:SetPoint("BOTTOMRIGHT", w.logPanel, "BOTTOMRIGHT", -28, 10);
  local text = CreateFrame("EditBox", nil, scroll);
  text:SetMultiLine(true);
  text:SetAutoFocus(false);
  text:SetMaxLetters(0);
  text:SetFontObject("GameFontHighlightSmall");
  text:SetTextInsets(0, 6, 0, 0);
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
  w.count = Label("", 22, -642);
  w.count:SetWidth(954);
  w.count:SetJustifyH("LEFT");
  w.count:SetTextColor(0.7, 0.7, 0.7);
  w.prev = Button("< Older", 83, 22, -672);
  w.next = Button("Newer >", 83, 112, -672);
  w.latest = Button("Latest", 83, 202, -672);
  w.copy = Button("Copy filtered", 130, 604, -672);
  w.copyAll = Button("Copy all retained", 143, 742, -672);
  w.clear = Button("Clear", 80, 900, -672);

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
    w.status:SetText(w.inputError or ("%s | Session %.3fs | UTC timestamps"):format(
      w.custom and "Custom range" or (w.frozenAt and "Frozen range" or "Following time"), log.Now()));
    if w.inputError then w.status:SetTextColor(1, 0.2, 0.2); else w.status:SetTextColor(0.7, 0.7, 0.7); end
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
  local elapsed = 0;
  w:SetScript("OnShow", function()
    PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN);
    log.Configure(true);
    w.viewKey, w.resetScroll = nil, true;
    text:ClearFocus(); dirty = true;
    Refresh();
  end);
  w:SetScript("OnHide", function()
    log.Configure(false);
    PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE);
    text:ClearFocus(); text:SetText(""); w.shownText = nil;
    w.viewKey, w.pageEnd, w.first, w.last, w.matches, w.inputError = nil, nil, nil, nil, nil, nil;
    w.custom, w.fromTime, w.toTime, w.frozenAt, w.resetScroll = nil, nil, nil, nil, nil;
    w.from:ClearFocus(); w.from:SetText("");
    w.to:ClearFocus(); w.to:SetText("");
    w.freeze:SetChecked(false);
    w.status:SetText(""); w.count:SetText("");
    scroll:SetVerticalScroll(0);
    dirty, lastRevision, elapsed = nil, nil, 0;
  end);
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
