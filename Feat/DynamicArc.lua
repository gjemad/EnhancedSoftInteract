local ADDON_NAME, ns = ...;
local issecretvalue = ns.issecretvalue;
local L = ns.L;

-- Dynamic Interaction Arc (interactArc "dynamic"). The arc starts at its widest and narrows one step when
-- the soft target has moved between several different targets in a short time, a sign that targets stand
-- close together. After a while with no soft target it widens one step. It narrows only right after the
-- target changes and widens only while there is no target, so it never pulls the arc away from a target
-- you are looking at. No API lists the game's candidate targets, so target changes are the measure.
-- Feat\Targeting.lua sets the CVar from ns.DynamicArcLevel(). Its settings are in
-- EnhancedSoftInteractDB.dynamicArc, changed in the Dynamic Interaction Arc window (Dynamic Arc Settings
-- on the settings page, or /esi arc).
local DYNAMIC = "dynamic";
ns.DYNAMIC_ARC = DYNAMIC;

-- Each setting: its saved key, range, default, and text() returning its name and tooltip, read when the
-- window is built so the chosen language applies. seconds and arc pick how its value reads.
local SETTINGS = {
  { key = "window", min = 1, max = 10, step = 0.5, default = 4, seconds = true,
    text = function() return L.ARC_TIME_WINDOW, L.ARC_TIME_WINDOW_DESC end },
  { key = "narrowAt", min = 2, max = 6, step = 1, default = 3,
    text = function() return L.ARC_TARGETS, L.ARC_TARGETS_DESC end },
  { key = "cooldown", min = 0, max = 5, step = 0.25, default = 1.5, seconds = true,
    text = function() return L.ARC_WAIT, L.ARC_WAIT_DESC end },
  { key = "widenAfter", min = 0.25, max = 10, step = 0.25, default = 2, seconds = true,
    text = function() return L.ARC_WIDEN, L.ARC_WIDEN_DESC end },
  { key = "widest", min = 0, max = 2, step = 1, default = 2, arc = true,
    text = function() return L.ARC_WIDEST, L.ARC_WIDEST_DESC end },
  { key = "narrowest", min = 0, max = 2, step = 1, default = 0, arc = true,
    text = function() return L.ARC_NARROWEST, L.ARC_NARROWEST_DESC end },
};

local level; --the arc in use, 0 to 2
local recent = {}; --soft target arrivals, oldest first: { guid, time }
local lastStep = -math.huge; --GetTime() of the last change of level
local noTargetSince; --GetTime() since there has been no soft target, or nil with a target
local window;

local function Saved() return EnhancedSoftInteractDB.dynamicArc end

local function Bounds()
  local t = Saved();
  return math.min(t.widest, t.narrowest), math.max(t.widest, t.narrowest);
end

local function Active()
  local db = EnhancedSoftInteractDB;
  return db and db.enabled and db.interactArc == DYNAMIC and ns.loggedIn and not ns.ForeverLootSparklesOwnsTargeting();
end

-- How many different targets arrived in the last span seconds; drops older arrivals.
local function Distinct(now, span)
  local seen, count = {}, 0;
  for i = #recent, 1, -1 do
    local entry = recent[i];
    if now - entry.time > span then
      table.remove(recent, i);
    elseif not seen[entry.guid] then
      seen[entry.guid] = true;
      count = count + 1;
    end
  end
  return count;
end

local function SetLevel(new)
  local low, high = Bounds();
  new = math.max(low, math.min(high, new));
  if new == level then return end
  level = new;
  lastStep = GetTime();
  wipe(recent);
  ns.UpdateTargeting();
end

-- The arc Feat\Targeting.lua sets while Interaction Arc is Dynamic.
function ns.DynamicArcLevel()
  if not level then level = select(2, Bounds()); end
  return level;
end

-- Called when Interaction Arc changes: start again from the widest arc.
function ns.ResetDynamicArc()
  level = select(2, Bounds());
  lastStep = -math.huge;
  noTargetSince = nil;
  wipe(recent);
end

local watcher = CreateFrame("Frame");
watcher:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED");
watcher:SetScript("OnEvent", function()
  if not Active() then return end
  local now = GetTime();
  local guid = UnitGUID("softinteract");
  if issecretvalue(guid) then noTargetSince = nil; return end --can't tell targets apart
  if not guid then noTargetSince = noTargetSince or now; return end
  noTargetSince = nil;
  recent[#recent + 1] = { guid = guid, time = now };
  local t = Saved();
  if Distinct(now, t.window) >= t.narrowAt and now - lastStep >= t.cooldown then
    SetLevel(ns.DynamicArcLevel() - 1);
  end
end);

local CHECK_INTERVAL = 0.2;
local sinceCheck = 0;
watcher:SetScript("OnUpdate", function(_, elapsed)
  sinceCheck = sinceCheck + elapsed;
  if sinceCheck < CHECK_INTERVAL then return end
  sinceCheck = 0;
  if not Active() then return end
  local now = GetTime();
  local guid = UnitGUID("softinteract");
  if issecretvalue(guid) or guid then noTargetSince = nil; return end
  noTargetSince = noTargetSince or now;
  if now - noTargetSince >= Saved().widenAfter and ns.DynamicArcLevel() < select(2, Bounds()) then
    SetLevel(level + 1);
    noTargetSince = now; --the next step waits as long again
  end
end);

table.insert(ns.onLoad, function()
  local db = EnhancedSoftInteractDB;
  db.dynamicArc = db.dynamicArc or {};
  for _, item in ipairs(SETTINGS) do
    if db.dynamicArc[item.key] == nil then db.dynamicArc[item.key] = item.default; end
  end
end);

----
--  The Dynamic Interaction Arc window. Feat\Settings.lua builds it with the settings page, because
--  Forever's gamepad UI is tainted by frames created while the page is open, and its rows use the page's
--  sliders and tooltip.
----
local ARC_ICONS = { [0] = "ArcStraightAhead", [1] = "ArcNarrow", [2] = "ArcWide" };
local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];
local ROW_HEIGHT = 34;
local WIDTH = 500;

local function ArcName(arc)
  return arc == 0 and L.VALUE_ARC_STRAIGHT_AHEAD or arc == 1 and L.VALUE_ARC_NARROW or L.VALUE_ARC_WIDE;
end

local function Format(item, value)
  if item.arc then return ArcName(value) end
  if item.seconds then
    local text = ("%.2f"):format(value):gsub("0+$", ""):gsub("%.$", "");
    return L.VALUE_SECONDS:format(text);
  end
  return tostring(value);
end

local function CreateRow(w, item, y)
  local row = CreateFrame("Frame", nil, w);
  row:SetPoint("TOPLEFT", 18, y);
  row:SetPoint("TOPRIGHT", -18, y);
  row:SetHeight(ROW_HEIGHT);
  row:EnableMouse(true);
  row.highlight = row:CreateTexture(nil, "BACKGROUND");
  row.highlight:SetAllPoints();
  row.highlight:SetColorTexture(1, 1, 1, 0.15);
  row.highlight:Hide();
  local name, desc = item.text();
  local data = { name = name, desc = desc, minValue = item.min, maxValue = item.max, valueStep = item.step };
  ns.HoverSettingsTooltip(row, data);
  local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal");
  label:SetPoint("LEFT", 10, 0);
  label:SetWidth(210);
  label:SetJustifyH("LEFT");
  label:SetText(data.name);
  local value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
  value:SetPoint("RIGHT", -6, 0);
  local slider = ns.CreateSettingsSlider(row, data);
  slider:SetPoint("RIGHT", -84, 0);
  ns.HoverSettingsTooltip(slider, data, row);
  slider:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v / item.step + 0.5) * item.step;
    if slider.UpdateSteppers then slider:UpdateSteppers(); end
    value:SetText(Format(item, v));
    if row.loading then return end
    Saved()[item.key] = v;
    if item.arc and level then SetLevel(level); end
  end);
  function row.Load()
    row.loading = true;
    slider:SetValue(Saved()[item.key]);
    if slider.UpdateSteppers then slider:UpdateSteppers(); end
    value:SetText(Format(item, Saved()[item.key]));
    row.loading = false;
  end
  return row;
end

function ns.CreateDynamicArcWindow()
  local w = CreateFrame("Frame", "EnhancedSoftInteractDynamicArc", UIParent, "ButtonFrameBaseTemplate");
  w:Hide();
  w:SetPoint("RIGHT", -60, 0);
  w:SetFrameStrata("DIALOG");
  w:SetToplevel(true);
  w:SetMovable(true);
  w:EnableMouse(true);
  w:RegisterForDrag("LeftButton");
  w:SetClampedToScreen(true);
  w:SetScript("OnDragStart", w.StartMoving);
  w:SetScript("OnDragStop", w.StopMovingOrSizing);
  w:SetBorder("ButtonFrameTemplateNoPortrait");
  w:SetPortraitShown(false);
  w.TitleBg = w:CreateTexture(nil, "BACKGROUND", "_UI-Frame-TitleTileBg", -6);
  w.TitleBg:SetHeight(17);
  w.TitleBg:SetPoint("TOPLEFT", 2, -3);
  w.TitleBg:SetPoint("TOPRIGHT", -2, -3);
  w:SetTitle(L.ARC_TITLE);
  table.insert(UISpecialFrames, w:GetName());

  -- The arc in use, with the Interaction Arc dropdown's icon.
  w.icon = w:CreateTexture(nil, "ARTWORK");
  w.icon:SetSize(24, 24);
  w.icon:SetPoint("TOPLEFT", 28, -36);
  w.current = w:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
  w.current:SetPoint("LEFT", w.icon, "RIGHT", 8, 0);
  w.current:SetPoint("RIGHT", w, "RIGHT", -28, 0);
  w.current:SetJustifyH("LEFT");

  w.rows = {};
  local y = -70;
  for _, item in ipairs(SETTINGS) do
    w.rows[#w.rows + 1] = CreateRow(w, item, y);
    y = y - ROW_HEIGHT;
  end
  w:SetSize(WIDTH, -y + 60);

  local defaults = CreateFrame("Button", nil, w, "UIPanelButtonTemplate");
  defaults:SetSize(140, 24);
  defaults:SetPoint("BOTTOMRIGHT", -20, 18);
  defaults:SetText(L.ARC_DEFAULTS);
  defaults:SetScript("OnClick", function()
    for _, item in ipairs(SETTINGS) do Saved()[item.key] = item.default; end
    for _, row in ipairs(w.rows) do row.Load(); end
    if level then SetLevel(level); end
  end);

  -- Shows the arc in use, or how to turn Dynamic on.
  local function ShowCurrent()
    if Active() then
      local arc = ns.DynamicArcLevel();
      w.icon:SetTexture(MEDIA .. ARC_ICONS[arc]);
      w.icon:Show();
      w.current:SetText(L.ARC_CURRENT:format(ArcName(arc)));
    else
      w.icon:Hide();
      w.current:SetText(L.ARC_NOT_IN_USE);
    end
  end
  local since = 0;
  w:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed;
    if since < 0.1 then return end
    since = 0;
    ShowCurrent();
  end);
  w:SetScript("OnShow", function()
    for _, row in ipairs(w.rows) do row.Load(); end
    ShowCurrent();
  end);
  window = w;
  ns.dynamicArcWindow = w; --for the test tools
  return w;
end

function ns.ToggleDynamicArcWindow()
  if window then window:SetShown(not window:IsShown()); end
end
ns.slashCommands.arc = ns.ToggleDynamicArcWindow;
