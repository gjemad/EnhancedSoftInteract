local _, ns = ...;
local issecretvalue = ns.issecretvalue;
local frame = ns.frame;

----
--  Debug window (/esi debug). Every soft target event becomes a page, kept for the last MAX_PAGES events
--  of this session, and the window pages through them like BugSack. Each page holds three views, one per
--  tab:
--  Events: what the game sent and what the HUD did with it.
--  Animations: what each glow layer drew and which animations were playing.
--  Range: everything the range decision used.
--  On the Animations and Range tabs, one page past the newest event shows the same view live, refreshed
--  every LIVE_INTERVAL seconds, to catch what happens between events. Copy highlights the text so Ctrl+C
--  copies it, and while text is selected the window doesn't refresh.
----
local MAX_PAGES = 100;
local LIVE_INTERVAL = 0.25;
local TABS = { "Events", "Animations", "Range" };
local EVENTS_TAB = 1;
local pages = {}; --each page: { [tab] = text }
local eventCount, lastGUID = 0, nil;

-- Secret values (names and GUIDs in combat or instances) become "<secret>". Only tostring, concatenation
-- and string.format touch them, which secrets allow, so no page holds a secret.
local function Safe(v)
  if issecretvalue(v) then return "<secret>" end
  return tostring(v);
end

----
--  The Animations and Range views
----

-- One glow layer: shown, size, vertex color and alpha, the layer's own alpha and its blend mode.
local function LayerLine(name, tex)
  local r, g, b, a = tex:GetVertexColor();
  local w, h = tex:GetSize();
  return ("%s: shown=%s size=%.0fx%.0f color=%.2f,%.2f,%.2f vertexAlpha=%.2f alpha=%.2f blend=%s"):format(
    name, tostring(tex:IsVisible()), w or 0, h or 0, r or 0, g or 0, b or 0, a or 0, tex:GetAlpha(),
    tostring(tex:GetBlendMode()));
end

local function AnimationsText()
  local cap = frame.keyCap;
  return table.concat({
    ("hud: shown=%s alpha=%.2f scale=%.2f target=%s outOfRange=%s"):format(tostring(frame:IsVisible()),
      frame:GetAlpha(), frame:GetEffectiveScale(), tostring(frame.colorKey), tostring(frame.outOfRange)),
    ("values: glowScale=%s color=%s pressDepth=%.2f"):format(
      frame.glowScale and ("%.2f"):format(frame.glowScale) or "-",
      frame.rgb and ("%.2f,%.2f,%.2f"):format(frame.rgb[1], frame.rgb[2], frame.rgb[3]) or "-", cap.pressDepth or 0),
    ("playing: fade=%s pulse=%s switch=%s ripple=%s pressIn=%s pressOut=%s"):format(
      tostring(frame.fader:IsPlaying()), tostring(frame.pulse:IsPlaying()), tostring(frame.switchAnim:IsPlaying()),
      tostring(frame.ripple:IsPlaying()), tostring(frame.pressIn:IsPlaying()), tostring(frame.pressOut:IsPlaying())),
    "",
    LayerLine("iconGlow", frame.iconGlow),
    LayerLine("lineLow", frame.lineLow),
    LayerLine("lineLowGlow", frame.lineLowGlow),
    LayerLine("lineHigh", frame.lineHigh),
    LayerLine("flash", frame.flash),
    LayerLine("shadow", frame.shadow),
  }, "\n");
end

local function RangeText()
  local unit = "softinteract";
  local guid = UnitGUID(unit);
  local inRangeTarget = "-";
  if guid and frame.inRangeTarget then
    inRangeTarget = issecretvalue(guid) and "unknown (secret)" or tostring(guid == frame.inRangeTarget);
  end
  local unableName = frame.colorKey and frame.colorKey:match("^Cursor Unable(.+)$");
  local cursorName = unableName or (frame.colorKey and frame.colorKey:match("^Cursor (.+)$"));
  local spellRange = cursorName and ns.SpellRangeCheck and ns.SpellRangeCheck(cursorName, unit);
  return table.concat({
    ("target: name=%s guid=%s"):format(Safe(UnitName(unit)), Safe(guid)),
    ("cursor: drawn=%s shown=%s"):format(Safe(frame.iconSource), tostring(frame.colorKey)),
    ("game: inInteractRange=%s"):format(Safe(UnitIsInInteractRange and UnitIsInInteractRange(unit))),
    ("spell: rangeCheck=%s (for %s)"):format(tostring(spellRange), tostring(cursorName)),
    ("you: casting=%s channeling=%s"):format(tostring(UnitCastingInfo("player") ~= nil),
      tostring(UnitChannelInfo("player") ~= nil)),
    ("hud: outOfRange=%s alpha=%.2f lastInRangeTargetIsThis=%s"):format(tostring(frame.outOfRange),
      frame:GetAlpha(), inRangeTarget),
  }, "\n");
end

local LIVE_TEXT = { [2] = AnimationsText, [3] = RangeText };

----
--  The event log
----
local window;
local ShowPage, PageCount;

function ns.DebugSoftTarget(oldGUID, newGUID, hasCursor, resolvedKey, iconKey, talkBadge, outOfRange)
  eventCount = eventCount + 1;
  local same = "unknown";
  if not issecretvalue(newGUID) then
    same = (newGUID == lastGUID) and "yes (repeat event)" or "no";
    lastGUID = newGUID;
  end
  local unit = "softinteract";
  local r, g, b = ns.GetTypeColor(iconKey, outOfRange);
  local hasColor = outOfRange or ns.IsUnableKey(iconKey) or ns.typeColors[iconKey];
  local keys = { GetBindingKey("INTERACTTARGET") };
  local cap = frame.keyCap;
  local name = Safe(UnitName(unit));
  local header = ("#%d  %s  %s"):format(eventCount, date("%H:%M:%S"), name);
  local lines = {
    header,
    ("event: old=%s new=%s sameTarget=%s source=%s"):format(Safe(oldGUID), Safe(newGUID), same,
      frame.fromRangeCheck and "range check" or "game event"),
    ("unit: name=%s player=%s object=%s interactable=%s inRange=%s attackable=%s"):format(
      name, Safe(UnitIsPlayer(unit)), Safe(UnitIsGameObject and UnitIsGameObject(unit)),
      Safe(UnitIsInteractable and UnitIsInteractable(unit)), Safe(UnitIsInInteractRange and UnitIsInInteractRange(unit)),
      Safe(UnitCanAttack("player", unit))),
    ("icon: hasCursor=%s source=%s resolved=%s key=%s color=%.2f,%.2f,%.2f%s talkBadge=%s nudge=%d,%d outOfRange=%s"):format(
      tostring(hasCursor), Safe(frame.iconSource), resolvedKey, iconKey, r, g, b, hasColor and "" or " (default, no entry)",
      tostring(talkBadge and true or false), frame.iconNudgeX or 0, frame.iconNudgeY or 0, tostring(outOfRange)),
    ("key: bindings=%s gamepadActive=%s gamepadUI=%s glyph=%s"):format(
      #keys > 0 and table.concat(keys, ",") or "none", tostring(ns.gamepadActive),
      tostring(ns.IsGamepadUI and ns.IsGamepadUI() or false),
      tostring(ns.GamepadInteractGlyph and ns.GamepadInteractGlyph())),
    ("layout: width=%s nameColumn=%s height=%s key=%s keyCap=%s"):format(
      ("%.0f"):format(frame.boxWidth or 0), ("%.0f"):format(frame.nameWidth or 0), tostring(EnhancedSoftInteractDB.hudHeight),
      cap:IsShown() and Safe(cap.text:GetText()) or "hidden",
      cap:IsShown() and ("%.0fx%.0f"):format(cap.capWidth or 0, cap.capHeight or 0) or "-"),
  };
  -- An open window on the newest page (or the live page) follows new events; on an older page it stays
  -- on that event. While text is selected for copying, the window waits until the next page change.
  local onNewest = window and window.page and window.page >= #pages;
  table.insert(pages, {
    table.concat(lines, "\n"),
    header .. "\n" .. AnimationsText(),
    header .. "\n" .. RangeText(),
  });
  local dropped = #pages > MAX_PAGES;
  if dropped then table.remove(pages, 1); end
  if window and window:IsShown() and not window.text:HasFocus() then
    ShowPage(onNewest and PageCount() or window.page - (dropped and 1 or 0));
  end
end

----
--  The window, built the first time /esi debug opens it.
----
local function CreateWindow()
  local w = CreateFrame("Frame", "EnhancedSoftInteractDebug", UIParent, "PortraitFrameTemplate");
  w:Hide();
  w:SetSize(720, 300);
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
  -- The bag border's portrait ring is smaller than the template's default, so the icon gets the size and
  -- place Blizzard's bag frames use (36 at -4, 1), moved against the cog art's off-center body.
  local PORTRAIT_SIZE = 36;
  local offset = ns.iconArtOffsets["cursor interact"] or {0, 0};
  local function Round(v) return math.floor(v + 0.5) end
  w:SetPortraitAtlasRaw("Crosshair_interact_64");
  w:SetPortraitTextureSizeAndOffset(PORTRAIT_SIZE, -4 - Round(offset[1] * PORTRAIT_SIZE / 64),
    1 + Round(offset[2] * PORTRAIT_SIZE / 64));
  w:SetTitle("Enhanced Soft Interact Debug");
  w:SetScript("OnShow", function() PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN); end);
  w:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE); end);
  table.insert(UISpecialFrames, w:GetName()); --Esc closes it

  w.count = w.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal");
  w.count:SetPoint("RIGHT", w.CloseButton, "LEFT", -5, 0);
  w.count:SetJustifyH("RIGHT");
  w.count:SetTextColor(1, 1, 1);

  local function Button(text, width)
    local b = CreateFrame("Button", nil, w, "SharedButtonTemplate");
    b:SetSize(width, 26);
    b:SetText(text);
    return b;
  end
  w.prev = Button("< Previous", 140);
  w.prev:SetPoint("BOTTOMLEFT", 8, 8);
  w.next = Button("Next >", 140);
  w.next:SetPoint("BOTTOMRIGHT", -8, 8);
  w.copy = Button("Copy", 110);
  w.copyAll = Button("Copy All", 110);
  w.clear = Button("Clear", 110);
  w.copyAll:SetPoint("BOTTOM", 0, 8);
  w.copy:SetPoint("RIGHT", w.copyAll, "LEFT", -6, 0);
  w.clear:SetPoint("LEFT", w.copyAll, "RIGHT", 6, 0);

  -- A read-only edit box, so the text can be selected and copied. Typing puts the shown text back.
  local scroll = CreateFrame("ScrollFrame", nil, w, "ScrollFrameTemplate");
  scroll:SetPoint("TOPLEFT", 12, -44); --below the portrait ring
  scroll:SetPoint("BOTTOMRIGHT", -30, 40);
  local text = CreateFrame("EditBox", nil, scroll);
  text:SetMultiLine(true);
  text:SetAutoFocus(false);
  text:SetMaxLetters(0);
  text:SetFontObject("GameFontHighlightSmall");
  text:SetWidth(scroll:GetWidth());
  text:SetScript("OnEscapePressed", text.ClearFocus);
  text:SetScript("OnTextChanged", function(self, userInput)
    if userInput then self:SetText(w.shownText or ""); self:HighlightText(); end
  end);
  scroll:SetScrollChild(text);
  scroll:SetScript("OnSizeChanged", function(self, width) text:SetWidth(width); end);
  w.text = text;

  local function Show(textToShow, countText)
    w.shownText = textToShow;
    text:SetText(textToShow);
    text:SetCursorPosition(0);
    text:ClearFocus();
    w.count:SetText(countText);
  end

  -- The Animations and Range tabs have one more page than there are events: the live view.
  local function HasLivePage() return w.tab ~= EVENTS_TAB end
  function PageCount() return #pages + (HasLivePage() and 1 or 0) end
  local function OnLivePage() return HasLivePage() and w.page == #pages + 1 end

  function ShowPage(index)
    local count = PageCount();
    if count == 0 then
      w.page = 0;
      Show("No soft target events yet. Look at something you can interact with.", "0 / 0");
    else
      w.page = math.max(1, math.min(index, count));
      if OnLivePage() then
        Show(LIVE_TEXT[w.tab](), ("live  %d / %d"):format(w.page, count));
      else
        Show(pages[w.page][w.tab], ("%d / %d"):format(w.page, count));
      end
    end
    w.prev:SetEnabled(w.page > 1);
    w.next:SetEnabled(w.page < count);
    w.copy:SetEnabled(count > 0);
    w.copyAll:SetEnabled(#pages > 0);
    w.clear:SetEnabled(#pages > 0);
  end

  -- Addons can't write to the clipboard, so Copy selects the text and Ctrl+C does the rest.
  local function SelectForCopy(countText)
    w.count:SetText(countText .. "  |cff20ff20Ctrl+C to copy|r");
    text:SetFocus();
    text:HighlightText();
  end

  -- Shift-click jumps to the first or last page.
  w.prev:SetScript("OnClick", function() ShowPage(IsShiftKeyDown() and 1 or w.page - 1); end);
  w.next:SetScript("OnClick", function() ShowPage(IsShiftKeyDown() and PageCount() or w.page + 1); end);
  w.copy:SetScript("OnClick", function()
    ShowPage(w.page);
    SelectForCopy(w.count:GetText());
  end);
  w.copyAll:SetScript("OnClick", function()
    local all = {};
    for i, page in ipairs(pages) do all[i] = page[w.tab]; end
    Show(table.concat(all, "\n\n"), ("all %d"):format(#pages));
    SelectForCopy(w.count:GetText());
  end);
  w.clear:SetScript("OnClick", function()
    wipe(pages);
    ShowPage(PageCount());
  end);

  -- Bottom tabs, as on Blizzard's Group Finder. The template adds each tab to w.Tabs, which the
  -- PanelTemplates functions read. On an older page a tab change keeps the event, so each tab shows the
  -- same event; on the newest page it goes to the new tab's newest page (the live view there).
  local function SelectTab(index)
    local following = not w.page or w.page >= #pages;
    w.tab = index;
    PanelTemplates_SetTab(w, index);
    ShowPage(following and PageCount() or w.page);
  end
  w.Tabs = w.Tabs or {};
  for index, name in ipairs(TABS) do
    local tab = CreateFrame("Button", nil, w, "PanelTabButtonTemplate");
    tab:SetID(index);
    tab:SetText(name);
    tab:SetScript("OnClick", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB); SelectTab(index); end);
    w.Tabs[index] = tab;
  end
  w.Tabs[1]:SetPoint("TOPLEFT", w, "BOTTOMLEFT", 11, 2);
  PanelTemplates_SetNumTabs(w, #TABS);
  w.SelectTab = SelectTab;

  local sinceRefresh = 0;
  w:SetScript("OnUpdate", function(_, elapsed)
    if not OnLivePage() or text:HasFocus() then return end
    sinceRefresh = sinceRefresh + elapsed;
    if sinceRefresh < LIVE_INTERVAL then return end
    sinceRefresh = 0;
    ShowPage(w.page);
  end);
  return w;
end

ns.slashCommands.debug = function()
  window = window or CreateWindow();
  if window:IsShown() then
    window:Hide();
  else
    window:Show();
    window.page = nil; --opens on the newest page, or the live view on the Animations and Range tabs
    window.SelectTab(window.tab or EVENTS_TAB);
  end
end
