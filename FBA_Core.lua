-- FatherBuffAlerts (WoW 1.12 / Lua 5.0)
-- Version: 2.1.2

FBA = {
  version = "2.1.2",
  timer   = 0,          -- ~10 Hz scan throttle
  EPSILON = 0.15,
  rt      = {},         -- runtime flags per buff key
  activeKey = nil
}

-- ------------ utils
local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r "..(msg or ""))
end

local function InCombat()
  if UnitAffectingCombat then return UnitAffectingCombat("player") end
  return false
end

local function KeyFor(name)
  if not name then return "" end
  return string.lower(name)
end

-- Tooltip fallback for 1.12
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

-- ------------ DB / defaults
local DEFAULT_BELL = "Sound\\Doodad\\BellTollHorde.wav"

local function DefaultSpell(name)
  return {
    name = name,
    enabled = true,
    threshold = 4,
    sound = "default",
    combatOnly = false,
    useLongReminder = true  -- 5m reminder if the instance lasts >= 9m
  }
end

local function IsDruid()
  local class = UnitClass and UnitClass("player") or nil
  if not class then return false end
  return string.lower(class) == "druid"
end

local defaults = {
  enabled = false,
  showAlert = true,
  alertCountdown = true,
  alertPos = { x = 0, y = 120 },
  spells = {},
  minimap = { show = true, angle = 220 },
  firstRunDone = false,
  _migrated = false
}

function FBA:InitDB()
  if not FatherBuffAlertsDB then FatherBuffAlertsDB = {} end
  local db = FatherBuffAlertsDB

  if db.enabled == nil then db.enabled = IsDruid() and true or false end
  if db.showAlert == nil then db.showAlert = defaults.showAlert end
  if db.alertCountdown == nil then db.alertCountdown = defaults.alertCountdown end
  if not db.alertPos then db.alertPos = { x = defaults.alertPos.x, y = defaults.alertPos.y } end
  if not db.spells then db.spells = {} end
  if not db.minimap then db.minimap = { show = true, angle = 220 } end
  if db.firstRunDone == nil then db.firstRunDone = false end

  -- one-time migration
  if not db._migrated then
    for k, sp in pairs(db.spells) do
      if sp and sp.sound == DEFAULT_BELL then sp.sound = "default" end
    end
    db._migrated = true
  end

  self.db = db
end

-- ------------ sound
local function PlayAlertSound(mode)
  mode = mode or "default"
  if mode == "" then mode = "default" end
  if mode == "none" then return end
  if mode == "default" then
    PlaySoundFile(DEFAULT_BELL)
    return
  end
  local ok = PlaySoundFile(mode)
  if not ok then PlaySoundFile(DEFAULT_BELL) end
end

-- ------------ scan/update
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

local function EffectiveThreshold(spellCfg, tl)
  if spellCfg.useLongReminder and tl and tl >= 540 then
    return 300 -- 5m before
  end
  return spellCfg.threshold or 4
end

function FBA:ResetCycleFlag(key)
  local r = self.rt[key]
  if not r then r = {} ; self.rt[key] = r end
  r.played = false
end

function FBA:OnUpdate(elapsed)
  if not self.db or not self.db.enabled then return end
  if not elapsed then elapsed = arg1 end
  if not elapsed or elapsed <= 0 then return end

  if self.AlertOnUpdate then self:AlertOnUpdate(elapsed) end

  self.timer = (self.timer or 0) + elapsed
  if self.timer < 0.10 then return end
  self.timer = 0

  local active = CollectActiveBuffs()
  local soonestKey, soonestTL, soonestLabel = nil, nil, nil

  for key, sp in pairs(self.db.spells) do
    if sp.enabled then
      local a = active[key]
      local rt = self.rt[key] or { played=false }
      self.rt[key] = rt

      if a and a.tl then
        local effThr = EffectiveThreshold(sp, a.tl)

        if a.tl > (effThr + self.EPSILON) then
          rt.played = false
        end

        if a.tl <= (effThr + self.EPSILON) then
          if (not soonestTL) or a.tl < soonestTL then
            soonestTL = a.tl
            soonestKey = key
            soonestLabel = sp.name
          end
        end

        if (a.tl <= (effThr + self.EPSILON)) and not rt.played then
          if (not sp.combatOnly) or InCombat() then
            PlayAlertSound(sp.sound)
            if self.db.showAlert then
              if self.db.alertCountdown then
                self:StartCountdown(sp.name, a.tl)
                self.activeKey = key
              else
                local secs = math.floor(effThr + 0.5)
                self:ShowStatic(sp.name.." expiring in "..secs.." seconds")
                self.activeKey = nil
              end
            end
          end
          rt.played = true
        end
      else
        rt.played = false
      end
    end
  end

  if self.db.showAlert and self.db.alertCountdown and soonestKey and active[soonestKey] then
    local tl = active[soonestKey].tl or 0
    self:UpdateCountdown(soonestLabel, tl)
    self.activeKey = soonestKey
    if tl <= 0.05 then
      self:HideAlert()
      self.activeKey = nil
    end
  elseif self.db.alertCountdown and self.activeKey and (not active[self.activeKey]) then
    self:HideAlert()
    self.activeKey = nil
  end
end

-- ------------ slash helpers
local function ShowHelp()
  Print("FatherBuffAlerts v"..FBA.version.." — Commands:")
  Print("  /fba settings              - Open settings window.")
  Print("  /fba enable                - Master ON/OFF (per-character).")
  Print("  /fba list                  - List tracked buffs.")
  Print("  /fba add <Buff Name>       - Track a new buff.")
  Print("  /fba add #<n>              - Add from last /fba suggest by index.")
  Print("  /fba remove <Buff Name>    - Stop tracking a buff.")
  Print("  /fba suggest [filter]      - List spellbook names.")
  Print("  /fba set <Buff> delay <s>  - Set per-buff delay.")
  Print("  /fba set <Buff> sound default|none|<path>")
  Print("  /fba set <Buff> combat     - Toggle per-buff combat-only.")
  Print("  /fba set <Buff> enable     - Toggle per-buff enable.")
  Print("  /fba set <Buff> long       - Toggle 5m reminder for ≥9m buffs.")
  Print("  /fba alert                 - Toggle splash (global).")
  Print("  /fba countdown             - Toggle live countdown (global).")
  Print("  /fba unlock | /fba lock    - Move/lock splash position.")
  Print("  /fba test <Buff>           - Test that buff’s sound + splash.")
  Print("  /fba status                - Show settings.")
end

FBA.lastSuggest = nil

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
  if not name or name == "" then
    Print("Usage: /fba add <Buff Name>")
    return
  end
  local key = KeyFor(name)
  if not FBA.db.spells[key] then
    FBA.db.spells[key] = DefaultSpell(name)
    Print("Added buff '"..name.."' with default settings.")
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
  for key, sp in pairs(FBA.db.spells) do
    n = n + 1
    Print(string.format("  %d) %s  [enabled:%s, delay:%ss, combat:%s, sound:%s, long:%s]",
      n, sp.name, sp.enabled and "ON" or "OFF",
      tostring(sp.threshold or 4),
      sp.combatOnly and "ON" or "OFF",
      (sp.sound == "default" and "default" or (sp.sound == "none" and "none" or sp.sound)),
      sp.useLongReminder and "ON" or "OFF"))
  end
  if n == 0 then Print("  (none)") end
end

-- ------------ slash
SLASH_FBA1 = "/fba"
SlashCmdList["FBA"] = function(msg)
  msg = msg or ""
  local lower = string.lower(msg)

  if lower == "" or string.find(lower, "^help") then
    ShowHelp()
    return
  end

  if lower == "settings" then
    if FBA.UI_Show then FBA:UI_Show() else Print("UI not loaded.") end
    return
  end

  if lower == "enable" then
    FBA.db.enabled = not FBA.db.enabled
    Print("Addon enabled: "..(FBA.db.enabled and "ON" or "OFF").." (per-character).")
    if FBA.UI_Refresh then FBA:UI_Refresh() end
    return
  end

  if lower == "list" then
    ListTracked()
    return
  end

  local addArg = ParseAfter(lower, "add")
  if addArg ~= nil then
    local raw = ParseAfter(msg, "add")
    if string.sub(addArg,1,1) == "#" then
      local idxStr = string.sub(addArg,2)
      local idx = tonumber(idxStr)
      if FBA.lastSuggest and idx and FBA.lastSuggest[idx] then
        AddSpellByName(FBA.lastSuggest[idx])
      else
        Print("No suggested spell at #"..(idxStr or "?"))
      end
    else
      AddSpellByName(raw)
    end
    return
  end

  local remArg = ParseAfter(lower, "remove")
  if remArg ~= nil then
    local raw = ParseAfter(msg, "remove")
    RemoveSpellByName(raw)
    return
  end

  local sugArg = ParseAfter(lower, "suggest")
  if sugArg ~= nil then
    FBA:SuggestSpellbook(string.lower(sugArg))
    return
  end

  local setArg = ParseAfter(lower, "set")
  if setArg ~= nil then
    local raw = ParseAfter(msg, "set")
    if not raw or raw == "" then Print("Usage: /fba set <Buff> ..."); return end
    local lraw = string.lower(raw)

    -- delay
    local dstart, dend = string.find(lraw, "%sdelay%s")
    if dstart then
      local _,_, nm, s = string.find(raw, "^(.-)%s+[dD][eE][lL][aA][yY]%s+([%d%.]+)%s*$")
      if not nm or not s then Print("Usage: /fba set <Buff> delay <seconds>"); return end
      local cfg = GetSpellCfgByName(nm)
      local key
      cfg, key = GetSpellCfgByName(nm)
      if not cfg then Print("Unknown buff '"..nm.."'"); return end
      local n = tonumber(s)
      if not n then Print("Delay must be a number"); return end
      if n < 0 then n = 0 end
      if n > 600 then n = 600 end
      cfg.threshold = n
      Print("Delay for '"..cfg.name.."' set to "..n.."s.")
      if FBA.UI_Refresh then FBA:UI_Refresh() end
      return
    end

    -- sound
    local sstart = string.find(lraw, "%ssound%s")
    if sstart then
      local _,_, nm, rest = string.find(raw, "^(.-)%s+[sS][oO][uU][nN][dD]%s+(.+)$")
      if not nm or not rest then Print("Usage: /fba set <Buff> sound default|none|<path>"); return end
      local cfg = GetSpellCfgByName(nm)
      local key
      cfg, key = GetSpellCfgByName(nm)
      if not cfg then Print("Unknown buff '"..nm.."'"); return end
      local m = string.lower(rest)
      if m == "default" or rest == "" then
        cfg.sound = "default"; Print("Sound for '"..cfg.name.."' set to default.")
      elseif m == "none" then
        cfg.sound = "none"; Print("Sound for '"..cfg.name.."' disabled.")
      else
        cfg.sound = rest; Print("Sound for '"..cfg.name.."' set to: "..rest)
      end
      if FBA.UI_Refresh then FBA:UI_Refresh() end
      return
    end

    -- combat toggle
    local cpos = string.find(lraw, "%scombat%s*$")
    if cpos then
      local nm = string.sub(raw, 1, cpos-1)
      local cfg = GetSpellCfgByName(nm)
      local key
      cfg, key = GetSpellCfgByName(nm)
      if not cfg then Print("Unknown buff '"..(nm or "").."'"); return end
      cfg.combatOnly = not cfg.combatOnly
      Print("Combat-only for '"..cfg.name.."': "..(cfg.combatOnly and "ON" or "OFF"))
      if FBA.UI_Refresh then FBA:UI_Refresh() end
      return
    end

    -- enable toggle
    local epos = string.find(lraw, "%senable%s*$")
    if epos then
      local nm = string.sub(raw, 1, epos-1)
      local cfg = GetSpellCfgByName(nm)
      local key
      cfg, key = GetSpellCfgByName(nm)
      if not cfg then Print("Unknown buff '"..(nm or "").."'"); return end
      cfg.enabled = not cfg.enabled
      Print("Enabled for '"..cfg.name.."': "..(cfg.enabled and "ON" or "OFF"))
      if FBA.UI_Refresh then FBA:UI_Refresh() end
      return
    end

    -- long toggle
    local lpos = string.find(lraw, "%slong%s*$")
    if lpos then
      local nm = string.sub(raw, 1, lpos-1)
      local cfg = GetSpellCfgByName(nm)
      local key
      cfg, key = GetSpellCfgByName(nm)
      if not cfg then Print("Unknown buff '"..(nm or "").."'"); return end
      cfg.useLongReminder = not cfg.useLongReminder
      Print("Long-buff reminder for '"..cfg.name.."': "..(cfg.useLongReminder and "ON" or "OFF"))
      if FBA.UI_Refresh then FBA:UI_Refresh() end
      return
    end

    Print("Usage: /fba set <Buff> delay <s> | sound <...> | combat | enable | long")
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
    Print("Live countdown: "..(FBA.db.alertCountdown and "ON" or "OFF"))
    if not FBA.db.alertCountdown then FBA:HideAlert() end
    if FBA.UI_Refresh then FBA:UI_Refresh() end
    return
  end

  if lower == "unlock" then
    FBA:ApplyAlertPosition()
    FBA:ShowStatic("FatherBuffAlerts — drag me, then /fba lock")
    FBA:ShowAnchor(true)
    Print("Anchor shown. Drag it, then /fba lock.")
    return
  end

  if lower == "lock" then
    FBA:ShowAnchor(false)
    FBA:HideAlert()
    Print("Anchor locked.")
    return
  end

  local testArg = ParseAfter(lower, "test")
  if testArg ~= nil then
    local raw = ParseAfter(msg, "test")
    local cfg = GetSpellCfgByName(raw)
    local key
    cfg, key = GetSpellCfgByName(raw)
    if not cfg then Print("Usage: /fba test <Buff Name>"); return end
    PlayAlertSound(cfg.sound)
    if FBA.db.showAlert then
      if FBA.db.alertCountdown then
        FBA:StartCountdown(cfg.name, cfg.threshold or 4)
      else
        local secs = math.floor((cfg.threshold or 4) + 0.5)
        FBA:ShowStatic(cfg.name.." expiring in "..secs.." seconds")
      end
    end
    return
  end

  if lower == "status" then
    local pos = FBA.db.alertPos or {x=0,y=0}
    Print("FatherBuffAlerts v"..FBA.version.." — Global:")
    Print("  Enabled:         "..(FBA.db.enabled and "ON" or "OFF"))
    Print("  Splash:          "..(FBA.db.showAlert and "ON" or "OFF"))
    Print("  Countdown:       "..(FBA.db.alertCountdown and "ON" or "OFF"))
    Print(string.format("  Position:        x=%d, y=%d (from center)", pos.x or 0, pos.y or 0))
    ListTracked()
    return
  end

  ShowHelp()
end

-- ------------ events
local f = CreateFrame("Frame", "FBA_Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_AURAS_CHANGED")

f:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    FBA:InitDB()
    FBA:InitAlerts()   -- Alerts file
    FBA:UI_Init()      -- UI file
    if not FBA.db.firstRunDone then
      if FBA.UI_Show then FBA:UI_Show() end
      FBA.db.firstRunDone = true
    end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_AURAS_CHANGED" then
    for key, rt in pairs(FBA.rt) do rt.played = false end
  end
end)

f:SetScript("OnUpdate", function()
  FBA:OnUpdate(arg1)
end)

f:Show()
