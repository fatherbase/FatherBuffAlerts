-- FatherBuffAlerts (WoW 1.12 / Lua 5.0)
-- Core logic: DB, multi-buff scanning, sounds, countdown hooks, slash commands.
-- Version: 2.1.8

FBA = FBA or {}

-- ---- Core state / constants
FBA.version    = "2.1.8"
FBA.timer      = FBA.timer or 0          -- ~10 Hz scan throttle
FBA.EPSILON    = FBA.EPSILON or 0.15     -- small cushion for frame timing
FBA.rt         = FBA.rt or {}            -- runtime flags per tracked buff key
FBA.activeKey  = nil                     -- which buff drives the live countdown
FBA.UI_waitNextCast = FBA.UI_waitNextCast or false

local DEFAULT_BELL = "Sound\\Doodad\\BellTollHorde.wav"

-- ---- Utilities
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r "..(msg or "")) end
local function InCombat() if UnitAffectingCombat then return UnitAffectingCombat("player") end return false end
local function KeyFor(name) if not name then return "" end return string.lower(name) end

-- Tooltip fallback (Vanilla) to read buff names
local tip = CreateFrame("GameTooltip", "FBA_Tooltip", UIParent, "GameTooltipTemplate")
local function GetBuffNameCompat(buff)
  if GetPlayerBuffName then return GetPlayerBuffName(buff) end
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:SetPlayerBuff(buff)
  local r = getglobal("FBA_TooltipTextLeft1")
  local txt = r and r:GetText() or nil
  tip:Hide()
  return txt
end

-- ---- Defaults / DB
local function DefaultSpell(name)
  return {
    name = name,
    enabled = true,
    threshold = 4,
    sound = "default",      -- "default" | "none" | <path>
    combatOnly = false,
    useLongReminder = true, -- if instance lasts >= 9m, also remind at 5m
    showCountdown = true,   -- per-buff live countdown (default ON)
  }
end

local function IsDruid()
  local class = UnitClass and UnitClass("player") or nil
  if not class then return false end
  return string.lower(class) == "druid"
end

function FBA:InitDB()
  if not FatherBuffAlertsDB then FatherBuffAlertsDB = {} end
  local db = FatherBuffAlertsDB

  if db.enabled == nil then db.enabled = IsDruid() and true or false end
  if db.showAlert == nil then db.showAlert = true end
  if db.alertCountdown == nil then db.alertCountdown = true end -- global default ON
  if not db.alertPos then db.alertPos = { x = 0, y = 120 } end
  if not db.spells then db.spells = {} end
  if not db.minimap then db.minimap = { show = true, angle = 220 } end
  if db.firstRunDone == nil then db.firstRunDone = false end
  if not db._migrated then
    for _, sp in pairs(db.spells) do
      if sp and sp.sound == DEFAULT_BELL then sp.sound = "default" end
    end
    db._migrated = true
  end
  -- backfill new flag
  for _, sp in pairs(db.spells) do
    if sp.showCountdown == nil then sp.showCountdown = true end
  end

  self.db = db
end

-- ---- Sound
local function PlayAlertSound(mode)
  mode = mode or "default"
  if mode == "" then mode = "default" end
  if mode == "none" then return end
  if mode == "default" then PlaySoundFile(DEFAULT_BELL); return end
  local ok = PlaySoundFile(mode)
  if not ok then PlaySoundFile(DEFAULT_BELL) end
end

-- ---- Buff scan / timing
local function CollectActiveBuffs()
  local out = {}
  local i = 0
  while true do
    local buff = GetPlayerBuff(i, "HELPFUL")
    if buff == -1 then break end
    local nm = GetBuffNameCompat(buff)
    if nm and nm ~= "" then
      out[KeyFor(nm)] = { id = buff, tl = GetPlayerBuffTimeLeft(buff), name = nm }
    end
    i = i + 1
  end
  return out
end

-- choose countdown step by threshold
local function stepForThreshold(thr)
  if not thr then return 0.1 end
  if thr > 30 then return 10
  elseif thr > 10 then return 1
  else return 0.1 end
end

function FBA:OnUpdate(elapsed)
  if not elapsed then elapsed = arg1 end

  -- ALWAYS tick alert visuals (so /fba test fades/counts down even if addon disabled)
  if self.AlertOnUpdate then self:AlertOnUpdate(elapsed or 0) end

  -- stop here if not enabled for actual scanning
  if not self.db or not self.db.enabled then return end
  if not elapsed or elapsed <= 0 then return end

  self.timer = (self.timer or 0) + elapsed
  if self.timer < 0.10 then return end
  self.timer = 0

  local active = CollectActiveBuffs()
  local soonestKey, soonestTL, soonestLabel, soonestThr, soonestShowCD = nil, nil, nil, nil, nil

  for key, sp in pairs(self.db.spells) do
    if sp.enabled then
      local a = active[key]
      local rt = self.rt[key] or { longPlayed=false, shortPlayed=false, seenMaxTL=nil, prevTL=nil }
      self.rt[key] = rt

      if a and a.tl then
        -- track max to detect long buffs / reapplications
        if (not rt.seenMaxTL) or (a.tl > rt.seenMaxTL) then rt.seenMaxTL = a.tl; rt.shortPlayed = false; rt.longPlayed = false end

        -- 5m reminder for long instances (no countdown)
        if sp.useLongReminder and rt.seenMaxTL and rt.seenMaxTL >= 540 then
          if (not rt.longPlayed) and (a.tl <= 300 + self.EPSILON) and (a.tl > (sp.threshold or 4) + self.EPSILON) then
            if (not sp.combatOnly) or InCombat() then
              PlayAlertSound(sp.sound)
              if self.db.showAlert and self.ShowStatic then
                -- 3s soft fade if big numbers
                self:ShowStatic(" "..sp.name.." has ~5 minutes remaining", 3)
              end
            end
            rt.longPlayed = true
          end
        else
          rt.longPlayed = false
        end

        -- per-buff threshold alert (single-fire on downward crossing)
        local thr = sp.threshold or 4
        local prev = rt.prevTL
        if prev and (prev <= (thr + self.EPSILON)) then
          -- already below threshold last tick; do nothing
        else
          if (a.tl <= (thr + self.EPSILON)) and not rt.shortPlayed then
            if (not sp.combatOnly) or InCombat() then
              PlayAlertSound(sp.sound)
              if self.db.showAlert then
                local useCD = (self.db.alertCountdown and sp.showCountdown)
                if useCD and self.StartCountdown then
                  -- set tick step by threshold
                  self:SetCountdownStep(stepForThreshold(thr))
                  self:StartCountdown(sp.name, a.tl)
                  self.activeKey = key
                else
                  local secs = math.floor(thr + 0.5)
                  local totalDur = (thr > 10) and 3 or nil
                  if self.ShowStatic then self:ShowStatic(sp.name.." expiring in "..secs.." seconds", totalDur) end
                  self.activeKey = nil
                end
              end
            end
            rt.shortPlayed = true
          end
        end

        -- track the “soonest” one for live updates
        if (a.tl <= (thr + self.EPSILON)) then
          if (not soonestTL) or a.tl < soonestTL then
            soonestTL = a.tl; soonestKey = key; soonestLabel = sp.name; soonestThr = thr; soonestShowCD = (self.db.alertCountdown and sp.showCountdown)
          end
        end

        rt.prevTL = a.tl
      else
        -- buff not present; clear runtime markers
        rt.longPlayed = false; rt.shortPlayed = false; rt.seenMaxTL = nil; rt.prevTL = nil
      end
    end
  end

  -- keep the live countdown text current for the nearest one (if per-buff countdown enabled)
  if self.db.showAlert and soonestShowCD and soonestKey and active[soonestKey] then
    local tl = active[soonestKey].tl or 0
    -- set step appropriate to this active buff
    self:SetCountdownStep(stepForThreshold(soonestThr))
    if self.UpdateCountdown then self:UpdateCountdown(soonestLabel, tl) end
    self.activeKey = soonestKey
    if tl <= 0.05 then
      if self.HideAlert then self:HideAlert() end
      self.activeKey = nil
    end
  elseif self.activeKey and (not active[self.activeKey]) then
    if self.HideAlert then self:HideAlert() end
    self.activeKey = nil
  end
end

-- ---- Slash helpers
local function ShowHelp()
  Print("FatherBuffAlerts v"..FBA.version.." — Commands:")
  Print("  /fba settings                 - Open settings window.")
  Print("  /fba enable                   - Master ON/OFF.")
  Print("  /fba list                     - List tracked buffs.")
  Print("  /fba add <Buff Name>          - Track a new buff.")
  Print("  /fba add #<n>                 - Add from last /fba suggest by index.")
  Print("  /fba remove <Buff Name>       - Stop tracking a buff.")
  Print("  /fba suggest [filter]         - List spellbook (actives first).")
  Print("  /fba set <Buff> delay <s>     - Set per-buff delay.")
  Print("  /fba set <Buff> sound default|none|<path>")
  Print("  /fba set <Buff> combat        - Toggle per-buff combat-only.")
  Print("  /fba set <Buff> enable        - Toggle per-buff enable.")
  Print("  /fba set <Buff> long          - Toggle 5m reminder for ≥9m.")
  Print("  /fba set <Buff> countdown     - Toggle per-buff live countdown.")
  Print("  /fba alert                    - Toggle on-screen splash (global).")
  Print("  /fba countdown                - Toggle global live countdown.")
  Print("  /fba unlock | /fba lock       - Move/lock splash position.")
  Print("  /fba test <Buff>              - Test that buff’s alert.")
  Print("  /fba status                   - Show settings.")
  Print("Note: Clicking a spell in the left Spellbook panel adds it to Tracked.")
end

FBA.lastSuggest = FBA.lastSuggest or nil

local function ParseAfter(msg, prefix)
  if not msg then return nil end
  local lower = string.lower(msg)
  if string.find(lower, "^"..prefix) then
    local start = string.len(prefix) + 1
    local rest = string.sub(msg, start)
    while string.sub(rest,1,1) == " " do rest = string.sub(rest,2) end
    return rest
  end
  return nil
end

local function GetSpellCfgByName(name)
  if not name or name == "" then return nil, nil end
  local key = KeyFor(name)
  return FBA.db.spells[key], key
end

local function AddSpellByName(name)
  if not name or name == "" then Print("Usage: /fba add <Buff Name>"); return end
  local key = KeyFor(name)
  if not FBA.db.spells[key] then
    FBA.db.spells[key] = DefaultSpell(name)
    Print("Added '"..name.."' with default settings.")
    if FBA.UI_Refresh then FBA:UI_Refresh() end
  else
    Print("Already tracking '"..name.."'.")
  end
end

local function RemoveSpellByName(name)
  local cfg, key = GetSpellCfgByName(name)
  if cfg then
    FBA.db.spells[key] = nil
    FBA.rt[key] = nil
    Print("Removed '"..cfg.name.."'.")
    if FBA.UI_Refresh then FBA:UI_Refresh() end
  else
    Print("Not tracking '"..(name or "").."'.")
  end
end

local function ListTracked()
  local n = 0
  Print("Tracked buffs:")
  for _, sp in pairs(FBA.db.spells) do
    n = n + 1
    Print(string.format("  %d) %s  [enabled:%s, delay:%ss, combat:%s, sound:%s, long:%s, countdown:%s]",
      n, sp.name, sp.enabled and "ON" or "OFF",
      tostring(sp.threshold or 4),
      sp.combatOnly and "ON" or "OFF",
      (sp.sound == "default" and "default" or (sp.sound == "none" and "none" or sp.sound)),
      sp.useLongReminder and "ON" or "OFF",
      sp.showCountdown and "ON" or "OFF"))
  end
  if n == 0 then Print("  (none)") end
end

-- ---- Slash
SLASH_FBA1 = "/fba"
SlashCmdList["FBA"] = function(msg)
  msg = msg or ""
  local lower = string.lower(msg)

  if lower == "" or string.find(lower, "^help") then ShowHelp(); return end

  if lower == "settings" then if FBA.UI_Show then FBA:UI_Show() else Print("UI not loaded.") end; return end

  if lower == "enable" then
    FBA.db.enabled = not FBA.db.enabled
    Print("Addon enabled: "..(FBA.db.enabled and "ON" or "OFF")..".")
    if FBA.UI_Refresh then FBA:UI_Refresh() end
    return
  end

  if lower == "list" then ListTracked(); return end

  local addArg = ParseAfter(lower, "add")
  if addArg ~= nil then
    local raw = ParseAfter(msg, "add")
    if string.sub(addArg,1,1) == "#" then
      local idxStr = string.sub(addArg,2)
      local idx = tonumber(idxStr)
      if FBA.lastSuggest and idx and FBA.lastSuggest[idx] then AddSpellByName(FBA.lastSuggest[idx])
      else Print("No suggested spell at #"..(idxStr or "?")) end
    else
      AddSpellByName(raw)
    end
    return
  end

  local remArg = ParseAfter(lower, "remove")
  if remArg ~= nil then local raw = ParseAfter(msg, "remove"); RemoveSpellByName(raw); return end

  local sugArg = ParseAfter(lower, "suggest")
  if sugArg ~= nil then FBA:SuggestSpellbook(string.lower(sugArg)); return end

  local setArg = ParseAfter(lower, "set")
  if setArg ~= nil then
    local raw = ParseAfter(msg, "set")
    if not raw or raw == "" then Print("Usage: /fba set <Buff> ..."); return end
    local lraw = string.lower(raw)

    -- delay
    if string.find(lraw, "%sdelay%s") then
      local _,_, nm, s = string.find(raw, "^(.-)%s+[dD][eE][lL][aA][yY]%s+([%d%.]+)%s*$")
      if not nm or not s then Print("Usage: /fba set <Buff> delay <seconds>"); return end
      local cfg = GetSpellCfgByName(nm); if not cfg then Print("Unknown buff '"..nm.."'"); return end
      local n = tonumber(s); if not n then Print("Delay must be a number"); return end
      if n < 0 then n = 0 end; if n > 600 then n = 600 end
      cfg.threshold = n
      Print("Delay for '"..cfg.name.."' set to "..n.."s.")
      if FBA.UI_Refresh then FBA:UI_Refresh() end
      return
    end

    -- sound
    if string.find(lraw, "%ssound%s") then
      local _,_, nm, rest = string.find(raw, "^(.-)%s+[sS][oO][uU][nN][dD]%s+(.+)$")
      if not nm or not rest then Print("Usage: /fba set <Buff> sound default|none|<path>"); return end
      local cfg = GetSpellCfgByName(nm); if not cfg then Print("Unknown buff '"..nm.."'"); return end
      local m = string.lower(rest)
      if m == "default" or rest == "" then cfg.sound = "default"; Print("Sound for '"..cfg.name.."' set to default.")
      elseif m == "none" then cfg.sound = "none"; Print("Sound for '"..cfg.name.."' disabled.")
      else cfg.sound = rest; Print("Sound for '"..cfg.name.."' set to: "..rest) end
      if FBA.UI_Refresh then FBA:UI_Refresh() end
      return
    end

    -- combat toggle
    local cpos = string.find(lraw, "%scombat%s*$")
    if cpos then
      local nm = string.sub(raw, 1, cpos-1)
      local cfg = GetSpellCfgByName(nm); if not cfg then Print("Unknown buff '"..(nm or "").."'"); return end
      cfg.combatOnly = not cfg.combatOnly
      Print("Combat-only for '"..cfg.name.."': "..(cfg.combatOnly and "ON" or "OFF"))
      if FBA.UI_Refresh then FBA:UI_Refresh() end
      return
    end

    -- enable toggle
    local epos = string.find(lraw, "%senable%s*$")
    if epos then
      local nm = string.sub(raw, 1, epos-1)
      local cfg = GetSpellCfgByName(nm); if not cfg then Print("Unknown buff '"..(nm or "").."'"); return end
      cfg.enabled = not cfg.enabled
      Print("Enabled for '"..cfg.name.."': "..(cfg.enabled and "ON" or "OFF"))
      if FBA.UI_Refresh then FBA:UI_Refresh() end
      return
    end

    -- long toggle
    local lpos = string.find(lraw, "%slong%s*$")
    if lpos then
      local nm = string.sub(raw, 1, lpos-1)
      local cfg = GetSpellCfgByName(nm); if not cfg then Print("Unknown buff '"..(nm or "").."'"); return end
      cfg.useLongReminder = not cfg.useLongReminder
      Print("Long-buff reminder for '"..cfg.name.."': "..(cfg.useLongReminder and "ON" or "OFF"))
      if FBA.UI_Refresh then FBA:UI_Refresh() end
      return
    end

    -- per-buff countdown toggle
    local cdpos = string.find(lraw, "%scountdown%s*$")
    if cdpos then
      local nm = string.sub(raw, 1, cdpos-1)
      local cfg = GetSpellCfgByName(nm); if not cfg then Print("Unknown buff '"..(nm or "").."'"); return end
      cfg.showCountdown = not cfg.showCountdown
      Print("Live countdown for '"..cfg.name.."': "..(cfg.showCountdown and "ON" or "OFF"))
      if FBA.UI_Refresh then FBA:UI_Refresh() end
      return
    end

    Print("Usage: /fba set <Buff> delay <s> | sound <...> | combat | enable | long | countdown")
    return
  end

  if lower == "alert" then
    FBA.db.showAlert = not FBA.db.showAlert
    Print("On-screen splash: "..(FBA.db.showAlert and "ON" or "OFF"))
    if FBA.UI_Refresh then FBA:UI_Refresh() end
    return
  end

  if lower == "countdown" then
    FBA.db.alertCountdown = not FBA.db.alertCountdown
    Print("Global live countdown: "..(FBA.db.alertCountdown and "ON" or "OFF"))
    if not FBA.db.alertCountdown and FBA.HideAlert then FBA:HideAlert() end
    if FBA.UI_Refresh then FBA:UI_Refresh() end
    return
  end

  if lower == "unlock" then
    if FBA.ApplyAlertPosition then FBA:ApplyAlertPosition() end
    if FBA.ShowStatic then FBA:ShowStatic("FatherBuffAlerts — drag me, then /fba lock") end
    if FBA.ShowAnchor then FBA:ShowAnchor(true) end
    Print("Anchor shown. Drag it, then /fba lock.")
    return
  end

  if lower == "lock" then
    if FBA.ShowAnchor then FBA:ShowAnchor(false) end
    if FBA.HideAlert then FBA:HideAlert() end
    Print("Anchor locked.")
    return
  end

  local testArg = ParseAfter(lower, "test")
  if testArg ~= nil then
    local raw = ParseAfter(msg, "test")
    local cfg = GetSpellCfgByName(raw)
    if not cfg then Print("Usage: /fba test <Buff Name>"); return end
    PlayAlertSound(cfg.sound)
    if FBA.db.showAlert then
      if (FBA.db.alertCountdown and cfg.showCountdown) and FBA.StartCountdownSim then
        local thr = cfg.threshold or 4
        FBA:SetCountdownStep(stepForThreshold(thr))
        FBA:StartCountdownSim(cfg.name, thr)
      elseif FBA.ShowStatic then
        local secs = math.floor((cfg.threshold or 4) + 0.5)
        FBA:ShowStatic(cfg.name.." expiring in "..secs.." seconds", (secs > 10) and 3 or nil)
      end
    end
    return
  end

  if lower == "status" then
    local pos = FBA.db.alertPos or {x=0,y=0}
    Print("FatherBuffAlerts v"..FBA.version.." — Global:")
    Print("  Enabled:         "..(FBA.db.enabled and "ON" or "OFF"))
    Print("  Splash:          "..(FBA.db.showAlert and "ON" or "OFF"))
    Print("  Global countdown:"..(FBA.db.alertCountdown and "ON" or "OFF"))
    Print(string.format("  Position:        x=%d, y=%d (from center)", pos.x or 0, pos.y or 0))
    ListTracked()
    return
  end

  ShowHelp()
end

-- ---- Events / frame
local f = CreateFrame("Frame", "FBA_Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_AURAS_CHANGED")
f:RegisterEvent("SPELLCAST_START")   -- Vanilla: arg1 = spell name

f:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    FBA:InitDB()
    if FBA.InitAlerts then FBA:InitAlerts() end   -- FBA_Alerts.lua
    if FBA.UI_Init then FBA:UI_Init() end         -- FBA_UI.lua
    if not FBA.db.firstRunDone then
      if FBA.UI_Show then FBA:UI_Show() end
      FBA.db.firstRunDone = true
    end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_AURAS_CHANGED" then
    for key, rt in pairs(FBA.rt) do rt.shortPlayed = false; rt.longPlayed = false; rt.seenMaxTL = nil; rt.prevTL = nil end
  elseif event == "SPELLCAST_START" then
    local spellName = arg1
    if FBA.UI_waitNextCast and spellName and spellName ~= "" then
      FBA.UI_waitNextCast = false
      local added = spellName
      local key = string.lower(added)
      if not FBA.db.spells[key] then FBA.db.spells[key] = DefaultSpell(added) end
      if FBA.UI_OnAddedFromCast then FBA:UI_OnAddedFromCast(added) end
      Print("Added from next cast: "..added)
      if FBA.UI_Refresh then FBA:UI_Refresh() end
    end
  end
end)

f:SetScript("OnUpdate", function() FBA:OnUpdate(arg1) end)
f:Show()
