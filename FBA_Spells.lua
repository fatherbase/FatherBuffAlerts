-- FatherBuffAlerts - Spellbook helpers (WoW 1.12)

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
          local tx = GetSpellTexture and GetSpellTexture(idx, "spell") or "Interface\\Icons\\INV_Misc_QuestionMark"
          table.insert(out, { name = nm, texture = tx })
        end
      end
    end
  end
  table.sort(out, function(a,b) return string.lower(a.name) < string.lower(b.name) end)
  return out
end

-- Back-compat (name-only)
function FBA:GatherSpellbookNames()
  local es = self:GatherSpellbookEntries()
  local names = {}
  for i=1,table.getn(es) do names[i] = es[i].name end
  return names
end

function FBA:SuggestSpellbook(filterLower)
  local es = self:GatherSpellbookEntries()
  self.lastSuggest = {}
  local shown = 0
  DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r Spellbook names:")
  for i=1,table.getn(es) do
    local nm = es[i].name
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
