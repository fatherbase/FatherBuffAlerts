-- FatherBuffAlerts - Spellbook suggest & helpers
-- Requires FBA_Core.lua

function FBA:GatherSpellbookNames()
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
          table.insert(out, nm)
        end
      end
    end
  end
  table.sort(out, function(a,b) return string.lower(a) < string.lower(b) end)
  return out
end

function FBA:SuggestSpellbook(filterLower)
  local names = self:GatherSpellbookNames()
  self.lastSuggest = {}
  local shown = 0
  DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r Spellbook names:")
  for i=1,table.getn(names) do
    local nm = names[i]
    if (not filterLower) or string.find(string.lower(nm), filterLower, 1, true) then
      shown = shown + 1
      self.lastSuggest[shown] = nm
      DEFAULT_CHAT_FRAME:AddMessage(string.format("  #%d  %s", shown, nm))
      if shown >= 30 then
        DEFAULT_CHAT_FRAME:AddMessage("  ... (showing first 30; refine with /fba suggest <filter>)")
        break
      end
    end
  end
  if shown == 0 then DEFAULT_CHAT_FRAME:AddMessage("  (no matches)") end
  DEFAULT_CHAT_FRAME:AddMessage("Tip: /fba add #<n> to add a name from this list.")
end
