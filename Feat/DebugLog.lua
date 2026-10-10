local _, ns = ...;
local frame, issecretvalue = ns.frame, ns.issecretvalue;

-- Session-only structured diagnostics. The ring owns at most 2000 records, including live snapshots.
-- Sources and data sections gate capture before any diagnostic API reads. Nothing runs while closed.
local LIMIT, INTERVAL = 2000, 0.25;
local log = { limit = LIMIT, interval = INTERVAL, revision = 0, open = false,
  sources = {}, sections = { event = true, animations = false, range = false } };
log.sourceOptions = {
  { "target", "Target changes", "targetFilter", "Records when your soft interact target changes or clears." },
  { "target_repeat", "Target repeats", "repeatFilter", "Records repeated events for the same target. Can be noisy." },
  { "range_check", "Range changes", "checkFilter", "Records changes found by the HUD's range checks." },
  { "interaction", "Interactions", "interactionFilter", "Records interact and loot events." },
  { "cast", "Player casts", "castFilter", "Records your spell casts and channels, including unrelated spells." },
  { "cast_state", "Object cast state", "castStateFilter", "Records changes to tracked gathering and opening casts." },
  { "bindings", "Bindings", "bindingsFilter", "Records keybinding updates." },
  { "input", "Input devices", "inputFilter", "Records gamepad and input mode changes." },
  { "cvars", "Relevant CVars", "cvarFilter", "Records changes to game settings used by this addon." },
  { "snapshot", "Live snapshots", "liveFilter", "Records changing HUD details. Requires Animations or Range data." },
};
for _, option in ipairs(log.sourceOptions) do log.sources[option[1]] = false; end
local function Enabled(source)
  return log.open and log.sources[source] and (log.sections.event or log.sections.animations or log.sections.range);
end
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
  local array = true;
  for key in pairs(v) do
    keys[#keys + 1] = key;
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then array = false; end
  end
  if array and #keys > 0 then
    for i = 1, #keys do if v[i] == nil then array = false; break end end
    if array then
      for i = 1, #keys do fields[i] = JSON(v[i]); end
      return "[" .. table.concat(fields, ",") .. "]";
    end
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b); end);
  for _, key in ipairs(keys) do fields[#fields + 1] = Quote(tostring(key)) .. ":" .. JSON(v[key]); end
  return "{" .. table.concat(fields, ",") .. "}";
end

local function Layer(tex)
  local r, g, b, a = tex:GetVertexColor();
  local w, h = tex:GetSize();
  return { shown = Safe(tex:IsVisible()), width = Number(w), height = Number(h),
    atlas = Safe(tex:GetAtlas()), texture = Safe(tex:GetTextureFilePath()), file_id = Safe(tex:GetTextureFileID()),
    red = Number(r), green = Number(g), blue = Number(b), vertex_alpha = Number(a),
    alpha = Number(tex:GetAlpha()), blend = Safe(tex:GetBlendMode()) };
end

local function Animations()
  local rgb = frame.rgb or {};
  local r, g, b = frame.name:GetTextColor();
  local layers = {};
  local cast = frame.castBar;
  for _, name in ipairs({ "fill1", "fill2", "track1", "track2", "end1", "end2" }) do
    layers["cast_" .. name] = Layer(cast[name]);
  end
  layers.cast_runeGlow = Layer(cast.runeGlow);
    for _, name in ipairs({ "iconGlow", "lineLow", "lineLowGlow", "lineHigh", "flash", "shadow", "stylePlate", "rune",
        "levelupNameGlow", "runicNameGlow", "statusShadow", "icon" }) do
      layers[name] = Layer(frame[name]);
    end
    for _, name in ipairs({ "levelupBloom", "runicBloom" }) do
      for i, region in ipairs(frame[name] or {}) do layers[name .. i] = Layer(region); end
    end
    return { shown = Safe(frame:IsVisible()), alpha = Number(frame:GetAlpha()),
      style = EnhancedSoftInteractDB.hudStyle, shadow_strength = Number(EnhancedSoftInteractDB.shadowStrength),
    scale = Number(frame:GetEffectiveScale()), glow_scale = Number(frame.glowScale),
    color = { red = Number(rgb[1]), green = Number(rgb[2]), blue = Number(rgb[3]) },
    flash_opacity = Number(frame.flashHolder:GetAlpha()),
    cast_bar = { shown = Safe(cast:IsVisible()), progress = Number(cast.progress),
      width = Number(cast.width), height = Number(cast.height), split = cast.split,
      center_bright = cast.centerBright, color = { red = Number(cast.red), green = Number(cast.green), blue = Number(cast.blue) },
      rune_amount = Number(cast.runeAmount) },
    status = { text = Safe(frame.requirement:GetText()), shown = Safe(frame.requirement:IsVisible()),
      alpha = Number(frame.requirement:GetAlpha()), height = Number(frame.requirement:GetHeight()),
      amount = Number(frame.statusAmount), target = Number(frame.statusTarget) },
    name = { red = Number(r), green = Number(g), blue = Number(b),
      alpha = Number(frame.name:GetAlpha()), compact_alpha = Number(frame.compactName:GetAlpha()),
      holder_alpha = Number(frame.nameHolder:GetAlpha()) },
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
    casting = Safe(evidence.casting), channeling = Safe(evidence.channeling), looting = Safe(evidence.looting),
    loot_closing = Safe(evidence.loot_closing),
    out_of_range = Safe(frame.outOfRange), last_in_range_target = same,
    interaction_cast = ns.InteractionCastSnapshot and ns.InteractionCastSnapshot() or nil };
end

local function At(index) return records[(head + index - 2) % LIMIT + 1]; end

local function Append(source, event, animations, range)
  if not Enabled(source) then return end
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

local function Details(evidence)
  return log.sections.animations and Animations() or nil, log.sections.range and Range(evidence) or nil;
end

local function DebugLoot(name, before, after)
  if not Enabled("interaction") then return end
  local animations, range = Details();
  Append("interaction", log.sections.event and { name = name, before = before, after = after } or nil, animations, range);
end

local function DebugInteractionCast(reason, state)
  if not Enabled("cast_state") then return end
  local animations, range = Details();
  Append("cast_state", log.sections.event and { name = "INTERACTION_CAST_STATE", reason = reason,
    interaction_cast = state } or nil, animations, range);
end

local function DebugSoftTarget(oldGUID, newGUID, target, mode)
  local source = frame.fromRangeCheck and "range_check" or "target";
  if not frame.fromRangeCheck and not issecretvalue(oldGUID) and not issecretvalue(newGUID)
      and oldGUID == newGUID then source = "target_repeat"; end
  if not Enabled(source) then return end
  local animations, range = Details(target and target.range);
  if not log.sections.event then Append(source, nil, animations, range); return end
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
  Append(source, event, animations, range);
end

-- Subscribe only to selected sources while the debug window is open.
local watchedCVars = { gamepadenable = true };
for _, kept in ipairs(ns.keptSettings) do
  for cvar in pairs(kept.cvars) do watchedCVars[cvar:lower()] = true; end
end
for _, cvar in ipairs(ns.hiddenCVars) do watchedCVars[cvar:lower()] = true; end
-- Keep payloads as evidence; a cast GUID identifies a cast, not its target object.
local CAST_FIELDS = { "unit", "cast_guid", "spell_id", "cast_bar_id" };
local INTERRUPTED_FIELDS = { "unit", "cast_guid", "spell_id", "interrupted_by", "cast_bar_id" };
local castEvents = {
  UNIT_SPELLCAST_SENT = { "unit", "target", "cast_guid", "spell_id" },
  UNIT_SPELLCAST_START = CAST_FIELDS,
  UNIT_SPELLCAST_DELAYED = CAST_FIELDS,
  UNIT_SPELLCAST_STOP = CAST_FIELDS,
  UNIT_SPELLCAST_SUCCEEDED = CAST_FIELDS,
  UNIT_SPELLCAST_FAILED = CAST_FIELDS,
  UNIT_SPELLCAST_FAILED_QUIET = CAST_FIELDS,
  UNIT_SPELLCAST_INTERRUPTED = INTERRUPTED_FIELDS,
  UNIT_SPELLCAST_CHANNEL_START = CAST_FIELDS,
  UNIT_SPELLCAST_CHANNEL_UPDATE = CAST_FIELDS,
  UNIT_SPELLCAST_CHANNEL_STOP = INTERRUPTED_FIELDS,
};

local function PlayerCast()
  local name, display, _, startMS, endMS, tradeskill, guid, uninterruptible, spellID, barID, delayMS = UnitCastingInfo("player");
  local channel, channelDisplay, _, channelStart, channelEnd, channelTrade, channelUninterruptible,
    channelSpell, empowered, stages, channelBar = UnitChannelInfo("player");
  return {
    cast = { name = Safe(name), display = Safe(display), guid = Safe(guid), spell_id = Number(spellID),
      start_ms = Number(startMS), end_ms = Number(endMS), tradeskill = Safe(tradeskill),
      not_interruptible = Safe(uninterruptible), cast_bar_id = Safe(barID), delay_ms = Number(delayMS) },
    channel = { name = Safe(channel), display = Safe(channelDisplay), spell_id = Number(channelSpell),
      start_ms = Number(channelStart), end_ms = Number(channelEnd), tradeskill = Safe(channelTrade),
      not_interruptible = Safe(channelUninterruptible), empowered = Safe(empowered),
      empower_stages = Number(stages), cast_bar_id = Safe(channelBar) },
    target_name = Safe(UnitSpellTargetName("player")),
  };
end

local function CastTargets()
  return { soft_guid = Safe(UnitGUID("softinteract")), soft_name = Safe(UnitName("softinteract")),
    soft_object = Safe(UnitIsGameObject and UnitIsGameObject("softinteract")),
    mouseover_guid = Safe(UnitGUID("mouseover")), mouseover_name = Safe(UnitName("mouseover")),
    hud_guid = Safe(frame.lastTarget), hud_action = Safe(frame.lastAction), hud_cursor = Safe(frame.colorKey) };
end

local eventSources = { PLAYER_SOFT_TARGET_INTERACTION = "interaction", UPDATE_BINDINGS = "bindings",
  GAME_PAD_ACTIVE_CHANGED = "input", CVAR_UPDATE = "cvars" };
if ns.IsGamepadUI then eventSources.INPUT_DEVICE_INTERFACE_TRANSITION = "input"; end
for name in pairs(castEvents) do eventSources[name] = "cast"; end
local watcher = CreateFrame("Frame");
watcher:SetScript("OnEvent", function(_, name, ...)
  local source = eventSources[name];
  if not source or not Enabled(source) then return end
  local arg1, arg2 = ...;
  if name == "CVAR_UPDATE" and (issecretvalue(arg1) or type(arg1) ~= "string" or not watchedCVars[arg1:lower()]) then return end
  local animations, range = Details();
  if not log.sections.event then Append(source, nil, animations, range); return end
  local event = { name = name, arg1 = Safe(arg1), arg2 = Safe(arg2) };
  local fields = castEvents[name];
  if fields then
    event.payload = {};
    for i, field in ipairs(fields) do event.payload[field] = Safe(select(i, ...)); end
  end
  if fields or name == "PLAYER_SOFT_TARGET_INTERACTION" then
    event.player_cast, event.targets = PlayerCast(), CastTargets();
  end
  Append(source, event, animations, range);
end);

function log.Configure(open)
  log.open = open and true or false;
  lastGUID, lastSnapshot = nil, nil;
  ns.DebugSoftTarget = (Enabled("target") or Enabled("target_repeat") or Enabled("range_check")) and DebugSoftTarget or nil;
  ns.DebugInteractionCast = Enabled("cast_state") and DebugInteractionCast or nil;
  ns.DebugLoot = Enabled("interaction") and DebugLoot or nil;
  for name, source in pairs(eventSources) do
    if Enabled(source) then
      if castEvents[name] then watcher:RegisterUnitEvent(name, "player"); else watcher:RegisterEvent(name); end
    else
      watcher:UnregisterEvent(name);
    end
  end
  if not log.open then
    log.Clear();
  end
end

function log.Match(filters, all)
  local list = {};
  local first, last = filters.from, filters.to;
  local sources, sections = filters.sources, filters.sections;
  for i = 1, count do
    local record = At(i);
    local hasSection = (sections.animations and record.animations) or (sections.range and record.range)
      or (sections.event and record.event);
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
  local exportedSources = {};
  if all then
    for i = first, last do exportedSources[list[i].source] = true; end
  end
  local version, build, _, interface = GetBuildInfo();
  local lines = { JSON({ format = "esi-debug-jsonl", schema = 2, session_started = session,
    client_version = Safe(version), client_build = Safe(build), interface = Safe(interface),
    retained = count, limit = LIMIT, evicted = dropped, exported = math.max(0, last - first + 1),
    scope = all and "all_retained" or "filtered", from_elapsed = all and 0 or Number(lower),
    to_elapsed = all and Number(GetTime() - started) or Number(upper),
    sources = all and exportedSources or sources, capture_sources = log.sources, capture_sections = log.sections,
    sections = all and { event = true, animations = true, range = true } or sections,
    capture_open = log.open, capture_scope = "selected sources and data while debug window is open",
    live_capture = Enabled("snapshot") and (log.sections.animations or log.sections.range) and true or false,
    live_interval = INTERVAL, live_scope = "changed snapshots while debug window is open",
    missing_values = "<nil>", restricted_values = "<secret>", timestamps = "UTC; elapsed is session seconds" }) };
  for i = first, last do lines[#lines + 1] = ExportRecord(list[i], sections, all); end
  return table.concat(lines, "\n");
end

function log.Now() return Number(GetTime() - started); end
function log.Count() return count, dropped; end
function log.Clear()
  -- Drop the ring itself too, so its expanded storage can be reclaimed after a long capture.
  records = {};
  head, count, dropped, lastSnapshot, lastGUID = 1, 0, 0, nil, nil;
  log.revision = log.revision + 1;
end
-- Compare sanitized tables directly: no sorted JSON string allocation on every sample.
local function Equal(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  -- The client assigns a new tooltip instance ID on each query, even when its content is unchanged.
  for key, value in pairs(a) do
    if key ~= "dataInstanceID" and not Equal(value, b[key]) then return false end
  end
  for key in pairs(b) do if key ~= "dataInstanceID" and a[key] == nil then return false end end
  return true;
end
function log.Sample()
  if not Enabled("snapshot") or not (log.sections.animations or log.sections.range) then return end
  local animations, range = Details();
  local snapshot = { animations = animations, range = range };
  if lastSnapshot and Equal(snapshot, lastSnapshot) then return end
  lastSnapshot = snapshot;
  Append("snapshot", nil, animations, range);
end
