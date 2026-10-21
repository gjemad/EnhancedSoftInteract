local _, ns = ...;
local frame, issecretvalue = ns.frame, ns.issecretvalue;

-- A cast GUID does not identify its object. Keep a conservative association from an interact
-- attempt, the sent target name and the same full object GUID at cast start.
-- Track gathering and object-opening casts; other casts stay unassociated.
local ATTEMPT_WINDOW = 1;
local END_EVENT_GRACE = 0.25; --Food Crate success arrived 50 ms after the advertised end
local PROFESSION_SPELLS = { ["cursor skin"] = 8613, ["cursor gatherherbs"] = 2368, ["cursor mine"] = 2576 };
local attempt, sent, active;
local watcher = CreateFrame("Frame");
watcher:Hide();

local function Accessible(value)
  if issecretvalue(value) then return nil end
  return value;
end

local function Target()
  local guid, name = Accessible(UnitGUID("softinteract")), Accessible(UnitName("softinteract"));
  local action = frame.lastAction;
  if not guid or not name or guid ~= frame.lastTarget then return end
  if action == "cursor skin" then return guid, name, action end
  if (action == "cursor interact" or PROFESSION_SPELLS[action])
      and UnitIsGameObject and Accessible(UnitIsGameObject("softinteract")) == true then
    return guid, name, action;
  end
end

local function SupportedSpell(action, id)
  -- The barrel uses Opening - No Text, 22810, with an empty display name. Never show that
  -- internal spell name to the player or treat every cast on an Interact object as opening.
  if action == "cursor interact" then return id == 22810 end
  local profession = PROFESSION_SPELLS[action];
  local name = profession and Accessible(C_Spell.GetSpellName(profession));
  return name and Accessible(C_Spell.GetSpellName(id)) == name;
end

local function Visible()
  if not active then return false end
  local db = EnhancedSoftInteractDB;
  if not db.enabled or not db.castBarEnabled or frame.inEditMode or frame.sampleName or not frame:IsShown() then
    return false;
  end
  -- Looking away mid-cast clears the target: the bar keeps animating while the HUD fades out.
  if UnitGUID("softinteract") == nil and frame.lastTarget == nil then return true end
  local guid = Accessible(UnitGUID("softinteract"));
  return not frame.fadingOut and guid == active.objectGUID and frame.lastTarget == active.objectGUID;
end

local function Progress()
  return math.max(0, math.min(1, (GetTime() - active.startTime) / (active.endTime - active.startTime)));
end

-- Auto Hide Default Cast Bar: while the HUD shows a tracked cast, the game's player cast bars go transparent.
-- Alpha is not protected, so Blizzard's own show/hide logic keeps running. Blizzard only fades out
-- (and then hides) a finished bar whose alpha is above zero, and every client resets alpha to 1 when
-- its next cast starts. So only a bar that is still casting gets its alpha back; a finished bar stays
-- transparent, which also hides its end flash, until the game's next cast restores it.
-- A finished bar restored to alpha 1 would stay on screen, full and frozen.
local GAME_CAST_BARS = { "PlayerCastingBarFrame", "GamepadPlayerCastingBarFrame" };
local gameBarHidden = false;
local function SetGameCastBarHidden(hidden)
  if not hidden and not gameBarHidden then return end
  gameBarHidden = hidden;
  for _, name in ipairs(GAME_CAST_BARS) do
    local castBar = _G[name];
    if castBar and (hidden or castBar.casting or castBar.channeling) then
      local alpha = hidden and 0 or 1;
      if castBar:GetAlpha() ~= alpha then castBar:SetAlpha(alpha); end
    end
  end
end

-- The HUD played a success or interrupt outcome: keep the finished game bar transparent instead of
-- restoring it, and stop the game's own "Interrupted" hold-and-fade, which would force alpha back to 1.
local function ReleaseGameCastBar()
  if not gameBarHidden then return end
  gameBarHidden = false;
  for _, name in ipairs(GAME_CAST_BARS) do
    local castBar = _G[name];
    if castBar then
      for _, anim in ipairs({ castBar.HoldFadeOutAnim, castBar.FadeOutAnim }) do
        if anim and anim:IsPlaying() then anim:Stop(); end
      end
      if castBar:GetAlpha() ~= 0 then castBar:SetAlpha(0); end
    end
  end
end

local function UpdateGameCastBar()
  local db = EnhancedSoftInteractDB;
  SetGameCastBarHidden((db.enabled and db.castBarEnabled and db.castBarHideGame and Visible()) and true or false);
end

function ns.RefreshInteractionCastBar()
  UpdateGameCastBar();
  if not Visible() then ns.CastBar.Hide(frame, not active); return end
  ns.CastBar.Paint(frame, ns.GetTypeColor(active.colorKey, false));
  ns.CastBar.SetProgress(frame, Progress());
end

function ns.InteractionCastSnapshot()
  if not active then return { active = false, visible = false }; end
  local visible = Visible();
  return { active = true, visible = visible and true or false, object_guid = active.objectGUID,
    cast_guid = active.castGUID, spell_id = active.spellID, name = active.name,
    color_key = active.colorKey, progress = Progress() };
end

local function Changed(reason)
  ns.RefreshInteractionCastBar();
  if ns.DebugInteractionCast then ns.DebugInteractionCast(reason, ns.InteractionCastSnapshot()); end
end

local function Clear(reason)
  attempt, sent = nil, nil;
  watcher:Hide();
  if not active then
    -- A new or unrelated cast uses the game's bar again.
    SetGameCastBarHidden(false);
    ns.CastBar.Hide(frame);
    return;
  end
  -- Success and interruption each play their style's outcome on the original object.
  -- Expiry, superseding casts and quiet failures simply clear the bar.
  local kind = reason == "UNIT_SPELLCAST_SUCCEEDED" and "success"
    or (reason == "UNIT_SPELLCAST_INTERRUPTED" or reason == "UNIT_SPELLCAST_FAILED") and "interrupt";
  local guid, progress = kind and Visible() and active.objectGUID, Progress();
  if guid then ReleaseGameCastBar(); end
  active = nil;
  Changed(reason);
  if guid then ns.CastBar.Outcome(frame, guid, kind, progress); end
end

local function ReadCast(castGUID, spellID)
  local name, _, _, startMS, endMS, _, actualGUID, _, actualSpellID = UnitCastingInfo("player");
  name, startMS, endMS = Accessible(name), Accessible(startMS), Accessible(endMS);
  actualGUID, actualSpellID = Accessible(actualGUID), Accessible(actualSpellID);
  if not name or type(startMS) ~= "number" or type(endMS) ~= "number" or endMS <= startMS
      or actualGUID ~= castGUID or actualSpellID ~= spellID then return end
  return name, startMS / 1000, endMS / 1000;
end

watcher:SetScript("OnEvent", function(_, event, unit, value, spellID, sentSpellID)
  if event == "PLAYER_SOFT_TARGET_INTERACTION" then
    attempt, sent = nil, nil;
    if not EnhancedSoftInteractDB.enabled or frame.inEditMode or frame.outOfRange or frame.requirementText then return end
    if UnitCastingInfo("player") or UnitChannelInfo("player") then return end
    local guid, name, action = Target();
    if guid then attempt = { objectGUID = guid, name = name, action = action,
      colorKey = frame.colorKey, time = GetTime() }; watcher:Show(); end
    return;
  end
  if event == "PLAYER_ENTERING_WORLD" then Clear("world_changed"); return end
  if Accessible(unit) ~= "player" then return end
  if event == "UNIT_SPELLCAST_CHANNEL_START" then Clear("superseded"); return end
  if event == "UNIT_SPELLCAST_SENT" then
    sent = nil;
    local targetName, castGUID = Accessible(value), Accessible(spellID);
    local id = Accessible(sentSpellID);
    local guid, name, action = Target();
    local previous = attempt;
    attempt = nil; --each interaction attempt can associate at most one sent cast
    -- Show for Clicked Objects: a mouse click sends no interaction event, and the game names the
    -- clicked object but not which one. Match that name to the HUD's target as a best effort, so a
    -- same-named neighbor can receive the bar. Interact-key casts keep their stricter association.
    local db = EnhancedSoftInteractDB;
    if not previous and db.castBarClicked and db.enabled and guid and not frame.inEditMode
        and not frame.outOfRange and not frame.requirementText then
      previous = { objectGUID = guid, name = name, action = action, colorKey = frame.colorKey, time = GetTime() };
    end
    if not previous or GetTime() - previous.time > ATTEMPT_WINDOW or guid ~= previous.objectGUID
        or action ~= previous.action or name ~= previous.name or targetName ~= name
        or not castGUID or type(id) ~= "number" or not SupportedSpell(action, id) then return end
    sent = { objectGUID = guid, name = name, action = action, colorKey = previous.colorKey,
      castGUID = castGUID, spellID = id, time = GetTime() };
    watcher:Show(); --a clicked cast has no attempt that woke the watcher to expire it
    return;
  end
  local castGUID, id = Accessible(value), Accessible(spellID);
  if not castGUID then return end
  if event == "UNIT_SPELLCAST_START" then
    local pending = sent;
    sent = nil;
    -- A new player cast supersedes any old association, even when it is unrelated.
    Clear("superseded");
    local guid = Target();
    if not pending or pending.castGUID ~= castGUID or pending.spellID ~= id
        or GetTime() - pending.time > ATTEMPT_WINDOW or guid ~= pending.objectGUID then return end
    local name, startTime, endTime = ReadCast(castGUID, id);
    if not name or endTime <= GetTime() then return end
    active = { objectGUID = guid, castGUID = castGUID, spellID = id,
      name = name, colorKey = pending.colorKey, startTime = startTime, endTime = endTime };
    watcher:Show();
    Changed("started");
  elseif event == "UNIT_SPELLCAST_DELAYED" then
    if not active or active.castGUID ~= castGUID then return end
    local _, startTime, endTime = ReadCast(castGUID, active.spellID);
    if startTime then active.startTime, active.endTime = startTime, endTime; Changed("delayed"); end
  else
    if sent and sent.castGUID == castGUID then sent = nil; end
    -- Interrupted can arrive before UnitCastingInfo clears, followed by duplicate interruptions.
    -- An old stop must never clear a newer cast.
    if active and active.castGUID == castGUID then Clear(event); end
  end
end);

-- Bound the lifetime even if the client omits a terminal event. No spell is cast or cancelled here.
watcher:SetScript("OnUpdate", function()
  if attempt and GetTime() - attempt.time > ATTEMPT_WINDOW then attempt = nil; end
  if sent and GetTime() - sent.time > ATTEMPT_WINDOW then sent = nil; end
  if active and GetTime() >= active.endTime + END_EVENT_GRACE then Clear("expired"); end
  if active then ns.RefreshInteractionCastBar(); end
  if not (attempt or sent or active) then watcher:Hide(); end
end);

table.insert(ns.onLoad, function()
  watcher:RegisterEvent("PLAYER_SOFT_TARGET_INTERACTION");
  watcher:RegisterEvent("PLAYER_ENTERING_WORLD");
  for _, event in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED",
      "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
      "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START" }) do
    watcher:RegisterUnitEvent(event, "player");
  end
end);
