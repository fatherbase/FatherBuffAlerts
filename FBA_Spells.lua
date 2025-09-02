-- FatherBuffAlerts - Spellbook & Active Buff helpers (WoW 1.12)
-- Version: 2.1.7

-- get active buff entries: { {name=, texture=, active=true}, ... }
local function GetBuffNameCompat(buff)
  if GetPlayerBuffName then return GetPlayerBuffName(buff) end
  local tip = CreateFrame("GameTooltip", "FBA_TmpTooltip", UIParent, "GameTooltipTemplate")
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:SetPlayerBuff(buff)
  local r = getglobal("FBA_TmpTooltipTextLeft1")
  local txt = r and r:GetText() or nil
  tip:Hide()
  return txt
end

local function GatherActiveBuffEntries()
  local out, seen = {}, {}
  local i = 0
  while true do
    local buff = GetPlayerBuff(i, "HELPFUL")
    if buff == -1 then break end
    local nm = GetBuffNameCompat(buff)
    if nm and nm ~= "" and not seen[nm] then
      seen[nm] = true
      local tx = (GetPlayerBuffTexture and GetPlayerBuffTexture(buff)) or "Interface\\Icons\\INV_Misc_QuestionMark"
      table.insert(out, { name = nm, texture = tx, active = true })
    end
    i = i + 1
  end
  table.sort(out, function(a,b) return string.lower(a.name) < string.lower(b.name) end)
  return out, seen
end

function FBA:GatherSpellbookEntries()
  local out, seen = {}, {}
  if not (GetNumSpellTabs and GetSpellTabInfo and GetSpellName) then return out end
  for t = 1, GetNumSpellTabs() do
    local _, _, offset, numSpells = GetSpellTabInfo(t)
    if offset and numSpells then
      for s = 1, numSpells do
        local idx = offset + s
        local nm = GetSpellName(idx, "spell")
        if nm and nm ~= "" and not seen[nm] then
          seen[nm] = true
          local tx = (GetSpellTexture and GetSpellTexture(idx, "spell")) or "Interface\\Icons\\INV_Misc_QuestionMark"
          table.insert(out, { name = nm, texture = tx })
        end
      end
    end
  end
  table.sort(out, function(a,b) return string.lower(a.name) < string.lower(b.name) end)
  return out
end

-- Build book list with actives first (deduped). Optional filterLower.
function FBA:BuildBookList(filterLower)
  local actives, seen = GatherActiveBuffEntries()
  local spells = self:GatherSpellbookEntries()
  local list = {}
  local function matches(nm)
    if not filterLower or filterLower == "" then return true end
    return string.find(string.lower(nm), filterLower, 1, true) ~= nil
  end
  -- add actives first
  for i=1,table.getn(actives) do
    local e = actives[i]
    if matches(e.name) then table.insert(list, e) end
    seen[string.lower(e.name)] = true
  end
  -- add remaining spells not already present
  for i=1,table.getn(spells) do
    local e = spells[i]
    if not seen[string.lower(e.name)] and matches(e.name) then
      table.insert(list, e)
    end
  end
  return list
end

-- Back-compat (name-only) used by /fba suggest
function FBA:GatherSpellbookNames()
  local es = self:BuildBookList(nil) -- with actives first
  local names = {}
  for i=1,table.getn(es) do names[i] = es[i].name end
  return names
end

function FBA:SuggestSpellbook(filterLower)
  local es = self:BuildBookList(filterLower and string.lower(filterLower) or nil)
  self.lastSuggest = {}
  local shown = 0
  DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r Spellbook (+actives) names:")
  for i=1,table.getn(es) do
    local nm = es[i].name
    shown = shown + 1
    self.lastSuggest[shown] = nm
    local mark = es[i].active and " |cff55ff55(active)|r" or ""
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  #%d  %s%s", shown, nm, mark))
    if shown >= 30 then
      DEFAULT_CHAT_FRAME:AddMessage("  ... (showing first 30; refine with /fba suggest <filter>)")
      break
    end
  end
  if shown == 0 then DEFAULT_CHAT_FRAME:AddMessage("  (no matches)") end
  DEFAULT_CHAT_FRAME:AddMessage("Tip: /fba add #<n> to add a name from this list.")
end
