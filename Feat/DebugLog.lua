local _, ns = ...;
local frame, issecretvalue = ns.frame, ns.issecretvalue;

-- Session-only structured diagnostics. The ring owns at most 2000 records, including live snapshots.
-- Filters never change capture. JSON lines are escaped before display and contain no secret values.
local LIMIT, INTERVAL = 2000, 0.25;
local log = { limit = LIMIT, interval = INTERVAL, revision = 0, liveCapture = true };
ns.debugLog = log;
local started = GetTime();
local session = date("!%Y-%m-%dT%H:%M:%SZ");
local records, head, count, sequence, dropped = {}, 1, 0, 0, 0;
local lastGUID, lastSnapshot;

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

local function Range(evidence)
  local target = frame.targetState;
  evidence = evidence or ns.ReadTargetRange(target and target.range.cursor, frame.inRangeTarget);
  local guid = evidence.guid;
  local same = "<nil>";
  if issecretvalue(guid) or issecretvalue(frame.inRangeTarget) then
    same = "<secret>";
  elseif guid and frame.inRangeTarget then
    same = guid == frame.inRangeTarget;
  end
  return { name = Safe(evidence.name), guid = Safe(guid), drawn = Safe(frame.iconSource),
    shown = Safe(frame.colorKey), cursor = Safe(evidence.cursor),
    interact_range = Safe(evidence.interactRange), spell_range = Safe(evidence.spellRange),
    casting = Safe(evidence.casting), channeling = Safe(evidence.channeling),
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
  log.revision = log.revision + 1;
end

function ns.DebugSoftTarget(oldGUID, newGUID, target, mode)
  target = target or {};
  local hasCursor, resolvedKey, iconKey = target.hasCursor, target.resolvedKey, target.iconKey;
  local talkBadge, outOfRange = target.talkBadge, target.outOfRange;
  local same = "<secret>";
  if not issecretvalue(newGUID) and not issecretvalue(lastGUID) then same = newGUID == lastGUID; end
  lastGUID = newGUID;
  local unit, cap = "softinteract", frame.keyCap;
  local r, g, b = ns.GetTypeColor(iconKey, outOfRange);
  local key1, key2 = GetBindingKey("INTERACTTARGET");
  local event = { name = "PLAYER_SOFT_INTERACT_CHANGED", old_guid = Safe(oldGUID), new_guid = Safe(newGUID),
    same_target = same, mode = mode or "active", cleared = not issecretvalue(newGUID) and newGUID == nil,
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
  Append(frame.fromRangeCheck and "range_check" or "game", event, Animations(), Range(target.range));
end

-- Keep the triggers for short animations and changes to input/persistence, even with the window closed.
local watchedCVars = { gamepadenable = true };
for _, kept in ipairs(ns.keptSettings) do
  for cvar in pairs(kept.cvars) do watchedCVars[cvar:lower()] = true; end
end
for _, cvar in ipairs(ns.hiddenCVars) do watchedCVars[cvar:lower()] = true; end
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

function log.Match(filters, all)
  local list = {};
  local first, last = filters.from, filters.to;
  local sources, sections = filters.sources, filters.sections;
  for i = 1, count do
    local record = At(i);
    local hasSection = sections.animations or sections.range or (sections.event and record.event);
    if all or (hasSection and sources[record.source] and record.elapsed >= first and record.elapsed <= last) then
      list[#list + 1] = record;
    end
  end
  return list;
end

local function ExportRecord(record, sections, all)
  local result = { sequence = record.sequence, timestamp = record.timestamp, elapsed = record.elapsed,
    source = record.source };
  for _, name in ipairs({ "event", "animations", "range" }) do
    if all or sections[name] then result[name] = record[name]; end
  end
  return JSON(result);
end

function log.Export(list, first, last, filters, all)
  local lower, upper = filters.from, filters.to;
  local sources, sections = filters.sources, filters.sections;
  local version, build, _, interface = GetBuildInfo();
  local lines = { JSON({ format = "esi-debug-jsonl", schema = 1, session_started = session,
    client_version = Safe(version), client_build = Safe(build), interface = Safe(interface),
    retained = count, limit = LIMIT, evicted = dropped, exported = math.max(0, last - first + 1),
    scope = all and "all_retained" or "filtered", from_elapsed = all and 0 or Number(lower),
    to_elapsed = all and Number(GetTime() - started) or Number(upper),
    sources = all and { game = true, range_check = true, snapshot = true } or sources,
    sections = all and { event = true, animations = true, range = true } or sections,
    live_capture = log.liveCapture,
    live_interval = INTERVAL, live_scope = "changed snapshots while debug window is open",
    missing_values = "<nil>", restricted_values = "<secret>", timestamps = "UTC; elapsed is session seconds" }) };
  for i = first, last do lines[#lines + 1] = ExportRecord(list[i], sections, all); end
  return table.concat(lines, "\n");
end

function log.Now() return Number(GetTime() - started); end
function log.Count() return count, dropped; end
function log.Clear()
  wipe(records);
  head, count, dropped, lastSnapshot = 1, 0, 0, nil;
  log.revision = log.revision + 1;
end
function log.ResetLive() lastSnapshot = nil; end
function log.Sample()
  if not log.liveCapture then return end
  local animations, range = Animations(), Range();
  local signature = JSON({ animations = animations, range = range });
  if signature == lastSnapshot then return end
  lastSnapshot = signature;
  Append("snapshot", nil, animations, range);
end
