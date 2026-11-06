local _, ns = ...;

-- How far and where the game looks for soft interact targets: SoftTargetInteractRange and
-- SoftTargetInteractArc (0 straight ahead, 1 in a cone ahead, 2 the half circle in front). This file owns
-- both CVars, and outlineModeShowLootEffectWhenDisabled (WoW: Forever only), which turns on the game's loot
-- effect for quest items you can loot.
--
-- While the addon is enabled, it holds them at Interaction Range, Interaction Arc and Show Quest Item
-- Loot Effect. With Show Quest Item Loot Effect unchecked, that CVar is the player's. The player's own
-- value comes back when the addon is turned off, and at logout, so the client never saves an addon value.
-- The range is a secure CVar, so it can't change in combat; the arc can. A change blocked by combat
-- happens at PLAYER_REGEN_ENABLED. In Forever's gamepad UI the values are temporary CVars (ns.SetGameCVar).
local ARC, RANGE = "SoftTargetInteractArc", "SoftTargetInteractRange";
local QUEST_EFFECT = "outlineModeShowLootEffectWhenDisabled";

-- Forever Loot Sparkles sets the range and arc while any of its node or corpse options is on, and holds
-- the quest item loot effect on while its main option is on. Its saved settings are nil until it loads,
-- after this addon.
local function ForeverLootSparklesSettings()
  local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ForeverLootSparkles");
  return loaded and _G.ForeverLootSparklesDB or nil;
end
function ns.ForeverLootSparklesOwnsTargeting()
  local db = ForeverLootSparklesSettings();
  return db ~= nil and (db.sparkleOre or db.sparkleHerbs or db.sparkleQuest or db.sparkleCorpseLoot) == true;
end
function ns.ForeverLootSparklesOwnsQuestEffect()
  local db = ForeverLootSparklesSettings();
  return db ~= nil and db.enabled ~= false;
end
-- One of that addon's options, by its saved key ("sparkleOre"), for Feat\LootEffect.lua.
function ns.ForeverLootSparklesOption(key)
  local db = ForeverLootSparklesSettings();
  return db ~= nil and db[key] == true;
end

-- Each CVar with the value the addon wants from the settings, or nil for the player's own, and owner(),
-- true while another addon sets it.
local CVARS = {
  { cvar = ARC, want = function(db) return db.interactArc end, owner = ns.ForeverLootSparklesOwnsTargeting },
  { cvar = RANGE, want = function(db) return db.interactRange end, owner = ns.ForeverLootSparklesOwnsTargeting },
  { cvar = QUEST_EFFECT, want = function(db) return db.showQuestLootEffect and 1 or nil end,
    owner = ns.ForeverLootSparklesOwnsQuestEffect },
};

local original = {}; --CVar -> the player's value from before the addon changed it
local applying = false;

local function Has(cvar) return GetCVar(cvar) ~= nil end

function ns.TargetingAvailable() return Has(ARC) or Has(RANGE) end
function ns.QuestLootEffectAvailable() return Has(QUEST_EFFECT) end

-- The value the addon wants, or nil for the player's own.
local function Wanted(item)
  local db = EnhancedSoftInteractDB;
  if db and db.enabled then return item.want(db) end
end

-- Secure CVars can't be changed in combat.
local function BlockedInCombat(cvar)
  if not InCombatLockdown() then return false end
  if C_CVar and C_CVar.GetCVarInfo then
    local _, _, _, _, _, secure = C_CVar.GetCVarInfo(cvar);
    return secure and true or false;
  end
  return cvar == RANGE;
end

-- Sets every CVar to the value wanted now, or back to the player's own.
local function Apply()
  if applying then return end
  applying = true; --setting a CVar fires CVAR_UPDATE, which calls this again
  for _, item in ipairs(CVARS) do
    local cvar = item.cvar;
    local current = Has(cvar) and tonumber(GetCVar(cvar));
    if item.owner() then
      original[cvar] = nil; --the other addon's value now, so it stays at logout
    elseif current and not BlockedInCombat(cvar) then
      local want = Wanted(item);
      if want then
        if current ~= want then
          original[cvar] = original[cvar] or GetCVar(cvar);
          ns.SetGameCVar(cvar, want);
        end
      elseif original[cvar] then
        -- The loot effect stays until the player logs out, so say so.
        if cvar == QUEST_EFFECT and tonumber(original[cvar]) ~= 1 then ns.Notify(ns.L.CHAT_QUEST_LOOT_EFFECT_LOG_OUT); end
        ns.SetGameCVar(cvar, original[cvar]);
        original[cvar] = nil;
      end
    end
  end
  applying = false;
end

-- Called when Enabled or a targeting setting changes.
ns.UpdateTargeting = Apply;

-- Unchecking Show Quest Item Loot Effect turns the game's effect off for good, not only back to the player's
-- value: an older Forever Loot Sparkles leaves the CVar at 1 and Outline Mode off, which shows the effect on
-- quest NPCs too. The CVar goes to 0, and Outline Mode comes back from off, so the game draws its outline
-- where it showed the effect. Both are saved, so they use SetCVar even in the gamepad UI. Blocked by combat,
-- it happens at PLAYER_REGEN_ENABLED.
local OUTLINE = "graphicsOutlineMode";
local OUTLINE_ON = 2;
local clearPending = false;
local function ClearQuestEffect()
  clearPending = false;
  if ns.ForeverLootSparklesOwnsQuestEffect() or not Has(QUEST_EFFECT) then return end
  if BlockedInCombat(QUEST_EFFECT) or (Has(OUTLINE) and BlockedInCombat(OUTLINE)) then
    clearPending = true;
    return;
  end
  original[QUEST_EFFECT] = nil;
  if tonumber(GetCVar(QUEST_EFFECT)) ~= 0 then
    SetCVar(QUEST_EFFECT, 0);
    ns.Notify(ns.L.CHAT_QUEST_LOOT_EFFECT_LOG_OUT);
  end
  if Has(OUTLINE) and tonumber(GetCVar(OUTLINE)) == 0 then SetCVar(OUTLINE, OUTLINE_ON); end
end

-- Called when Show Quest Item Loot Effect changes.
function ns.UpdateQuestLootEffect(checked)
  Apply();
  if not checked then ClearQuestEffect(); end
end

local watched = {};
for _, item in ipairs(CVARS) do watched[item.cvar:lower()] = true; end
-- A graphics preset turns the loot effect off without a CVAR_UPDATE for them that can be relied on, so the
-- addon sets them again a second after the preset changes.
local PRESET_DELAY = 1;
local presets = { graphicsquality = true, raidgraphicsquality = true };
local watcher = CreateFrame("Frame");
watcher:RegisterEvent("PLAYER_REGEN_ENABLED");
watcher:RegisterEvent("PLAYER_ENTERING_WORLD"); --account settings can arrive after the addon loads
watcher:RegisterEvent("CVAR_UPDATE");
watcher:RegisterEvent("PLAYER_LOGOUT");
watcher:SetScript("OnEvent", function(_, event, name)
  if event == "CVAR_UPDATE" then
    if ns.issecretvalue(name) or type(name) ~= "string" then return end
    local key = name:lower();
    -- Something else (the gamepad UI, the player) changed a value the addon holds: set it again.
    if watched[key] then Apply();
    elseif presets[key] and not applying then C_Timer.After(PRESET_DELAY, Apply); end
  elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
    Apply();
    if clearPending then ClearQuestEffect(); end
  else
    -- Never leave an addon value in the saved settings.
    applying = true;
    for cvar, value in pairs(original) do ns.SetGameCVar(cvar, value); end
  end
end);

table.insert(ns.onLoad, Apply);
