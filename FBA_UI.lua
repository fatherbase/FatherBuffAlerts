-- FatherBuffAlerts - Settings UI + Minimap button (WoW 1.12 / Lua 5.0)

-- =======================
-- Minimap Button
-- =======================
local iconPath = "Interface\\Icons\\Ability_Druid_TigersFury"

local btn = CreateFrame("Button", "FBA_MinimapButton", Minimap)
btn:SetWidth(32); btn:SetHeight(32)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
btn:RegisterForClicks("LeftButtonUp")
btn:RegisterForDrag("LeftButton")
btn:EnableMouse(true)
btn:SetMovable(true)
btn:SetClampedToScreen(true)

-- Ensure it's visible even before DB/positioning is ready
btn:ClearAllPoints()
btn:SetPoint("CENTER", Minimap, "CENTER", 0, 0)

local tex = btn:CreateTexture(nil, "ARTWORK")
tex:SetAllPoints(btn)
tex:SetTexture(iconPath)

btn:SetScript("OnClick", function()
  if FBA and FBA.UI_Show then
    FBA:UI_Show()
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r UI not ready.")
  end
end)

btn:SetScript("OnDragStart", function(self) self:StartMoving() end)
btn:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  if not (FBA and FBA.db and FBA.db.minimap) then return end
  local mx, my = Minimap:GetCenter()
  local cx, cy = self:GetCenter()
  local dx, dy = cx - mx, cy - my
  local angle = math.deg(math.atan2(dy, dx))
  if angle < 0 then angle = angle + 360 end
  FBA.db.minimap.angle = math.floor(angle + 0.5)
  if FBA.UI_PositionMinimapButton then FBA:UI_PositionMinimapButton() end
end)

local function deg2rad(d) return d * math.pi / 180 end

function FBA:UI_PositionMinimapButton()
  if not FBA.db or not FBA.db.minimap then return end
  local a = FBA.db.minimap.angle or 220
  local r = (Minimap:GetWidth() / 2) - 10
  local x = math.cos(deg2rad(a)) * r
  local y = math.sin(deg2rad(a)) * r
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
  if FBA.db.minimap.show then btn:Show() else btn:Hide() end
end

-- =======================
-- Settings Window
-- =======================
local frame = CreateFrame("Frame", "FBA_Config", UIParent)
frame:SetWidth(720); frame:SetHeight(480)
frame:SetPoint("CENTER")
frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                    tile = true, tileSize = 32, edgeSize = 32,
                    insets = { left=8, right=8, top=8, bottom=8 } })
frame:Hide()
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
title:SetPoint("TOP", 0, -16)
title:SetText("FatherBuffAlerts — Settings")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -5, -5)

-- Global toggles
local cbEnabled = CreateFrame("CheckButton", "FBA_CBEnabled", frame, "UICheckButtonTemplate")
cbEnabled:SetPoint("TOPLEFT", 20, -48)
FBA_CBEnabledText:SetText("Enabled (per-character)")
cbEnabled:SetScript("OnClick", function(self) if FBA and FBA.db then FBA.db.enabled = self:GetChecked() end end)

local cbSplash = CreateFrame("CheckButton", "FBA_CBSplash", frame, "UICheckButtonTemplate")
cbSplash:SetPoint("TOPLEFT", 20, -72)
FBA_CBSplashText:SetText("Show on-screen splash")
cbSplash:SetScript("OnClick", function(self) if FBA and FBA.db then FBA.db.showAlert = self:GetChecked() end end)

local cbCountdown = CreateFrame("CheckButton", "FBA_CBCountdown", frame, "UICheckButtonTemplate")
cbCountdown:SetPoint("TOPLEFT", 20, -96)
FBA_CBCountdownText:SetText("Show live countdown text")
cbCountdown:SetScript("OnClick", function(self)
  if FBA and FBA.db then
    FBA.db.alertCountdown = self:GetChecked()
    if not self:GetChecked() then FBA:HideAlert() end
  end
end)

local cbMinimap = CreateFrame("CheckButton", "FBA_CBMinimap", frame, "UICheckButtonTemplate")
cbMinimap:SetPoint("TOPLEFT", 20, -120)
FBA_CBMinimapText:SetText("Show minimap button")
cbMinimap:SetScript("OnClick", function(self)
  if FBA and FBA.db then
    FBA.db.minimap.show = self:GetChecked()
    FBA:UI_PositionMinimapButton()
  end
end)

-- Tabs
local tabTracked = CreateFrame("Button", "FBA_TabTracked", frame, "UIPanelButtonTemplate")
tabTracked:SetWidth(100); tabTracked:SetHeight(22)
tabTracked:SetPoint("TOPLEFT", 20, -150)
tabTracked:SetText("Tracked")

local tabBook = CreateFrame("Button", "FBA_TabBook", frame, "UIPanelButtonTemplate")
tabBook:SetWidth(100); tabBook:SetHeight(22)
tabBook:SetPoint("LEFT", tabTracked, "RIGHT", 8, 0)
tabBook:SetText("Spellbook")

-- Left list (tracked OR spellbook)
local listBG = CreateFrame("Frame", nil, frame)
listBG:SetWidth(300); listBG:SetHeight(260)
listBG:SetPoint("TOPLEFT", 20, -180)
listBG:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                     edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                     tile = true, tileSize = 16, edgeSize = 12,
                     insets = { left=3, right=3, top=3, bottom=3 } })
listBG:SetBackdropColor(0,0,0,0.5)

local listTitle = listBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
listTitle:SetPoint("TOPLEFT", 8, -6)
listTitle:SetText("Tracked Buffs")

local rows, visibleRows = {}, 10
for i=1,visibleRows do
  local b = CreateFrame("Button", nil, listBG, "UIPanelButtonTemplate")
  b:SetWidth(260); b:SetHeight(22)
  b:SetPoint("TOPLEFT", 10, -20 - (i-1)*24)
  b:SetText("")
  b:SetScript("OnClick", function(self)
    FBA.UI_selectedKey = self._key
    FBA:UI_RefreshDetail()
  end)
  rows[i] = b
end

local btnPrev = CreateFrame("Button", nil, listBG, "UIPanelButtonTemplate")
btnPrev:SetWidth(60); btnPrev:SetHeight(20)
btnPrev:SetPoint("BOTTOMLEFT", 10, 8)
btnPrev:SetText("<")
btnPrev:SetScript("OnClick", function()
  FBA.UI_page = (FBA.UI_page or 1) - 1
  if FBA.UI_page < 1 then FBA.UI_page = 1 end
  FBA:UI_Refresh()
end)

local btnNext = CreateFrame("Button", nil, listBG, "UIPanelButtonTemplate")
btnNext:SetWidth(60); btnNext:SetHeight(20)
btnNext:SetPoint("BOTTOMRIGHT", -10, 8)
btnNext:SetText(">")
btnNext:SetScript("OnClick", function()
  FBA.UI_page = (FBA.UI_page or 1) + 1
  FBA:UI_Refresh()
end)

-- Add/custom box
local addBox = CreateFrame("EditBox", "FBA_AddBox", frame, "InputBoxTemplate")
addBox:SetWidth(260); addBox:SetHeight(20)
addBox:SetPoint("TOPLEFT", 20, -450)
addBox:SetAutoFocus(false)

local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
addBtn:SetWidth(80); addBtn:SetHeight(20)
addBtn:SetPoint("LEFT", addBox, "RIGHT", 8, 0)
addBtn:SetText("+ Add")
addBtn:SetScript("OnClick", function()
  local nm = FBA_AddBox:GetText()
  if nm and nm ~= "" and FBA and FBA.db then
    local key = string.lower(nm)
    if not FBA.db.spells[key] then
      FBA.db.spells[key] = { name = nm, enabled = true, threshold = 4, sound = "default", combatOnly=false, useLongReminder=true }
      FBA_AddBox:SetText("")
      FBA:UI_Refresh()
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r Already tracking '"..nm.."'")
    end
  end
end)

-- Right detail panel
local detBG = CreateFrame("Frame", nil, frame)
detBG:SetWidth(340); detBG:SetHeight(260)
detBG:SetPoint("TOPLEFT", 360, -180)
detBG:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12,
                    insets = { left=3, right=3, top=3, bottom=3 } })
detBG:SetBackdropColor(0,0,0,0.5)

local detTitle = detBG:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
detTitle:SetPoint("TOPLEFT", 8, -8)
detTitle:SetText("Buff Settings")

local lblName = detBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblName:SetPoint("TOPLEFT", 8, -36)
lblName:SetText("Name: ")

local txtName = detBG:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
txtName:SetPoint("LEFT", lblName, "RIGHT", 4, 0)
txtName:SetText("—")

local cbSpellEnabled = CreateFrame("CheckButton", "FBA_CBSpellEnabled", detBG, "UICheckButtonTemplate")
cbSpellEnabled:SetPoint("TOPLEFT", 8, -60)
FBA_CBSpellEnabledText:SetText("Enable this buff")
cbSpellEnabled:SetScript("OnClick", function(self)
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    FBA.db.spells[key].enabled = self:GetChecked()
    FBA:UI_Refresh()
  end
end)

local cbCombat = CreateFrame("CheckButton", "FBA_CBCombat", detBG, "UICheckButtonTemplate")
cbCombat:SetPoint("TOPLEFT", 8, -84)
FBA_CBCombatText:SetText("Only alert in combat")
cbCombat:SetScript("OnClick", function(self)
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    FBA.db.spells[key].combatOnly = self:GetChecked()
  end
end)

local cbLong = CreateFrame("CheckButton", "FBA_CBLong", detBG, "UICheckButtonTemplate")
cbLong:SetPoint("TOPLEFT", 8, -108)
FBA_CBLongText:SetText("5m reminder for ≥9m buffs")
cbLong:SetScript("OnClick", function(self)
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    FBA.db.spells[key].useLongReminder = self:GetChecked()
  end
end)

local lblDelay = detBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblDelay:SetPoint("TOPLEFT", 8, -136)
lblDelay:SetText("Delay (seconds):")

local ebDelay = CreateFrame("EditBox", "FBA_EBDelay", detBG, "InputBoxTemplate")
ebDelay:SetWidth(80); ebDelay:SetHeight(20)
ebDelay:SetPoint("LEFT", lblDelay, "RIGHT", 8, 0)
ebDelay:SetAutoFocus(false)
ebDelay:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

local lblSound = detBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblSound:SetPoint("TOPLEFT", 8, -166)
lblSound:SetText("Sound:")

local ddSound = CreateFrame("Button", "FBA_DDSound", detBG, "UIPanelButtonTemplate")
ddSound:SetWidth(100); ddSound:SetHeight(20)
ddSound:SetPoint("LEFT", lblSound, "RIGHT", 8, 0)
ddSound._mode = "default"
ddSound:SetText("default")
ddSound:SetScript("OnClick", function(self)
  local m = self._mode
  if m == "default" then m = "none"
  elseif m == "none" then m = "custom"
  else m = "default" end
  self._mode = m
  self:SetText(m)
  if m == "custom" then FBA_EBSoundPath:Show() else FBA_EBSoundPath:Hide() end
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    if m == "custom" then
      local p = FBA_EBSoundPath:GetText()
      FBA.db.spells[key].sound = (p and p ~= "" and p) or "default"
    else
      FBA.db.spells[key].sound = m
    end
  end
end)

local ebSound = CreateFrame("EditBox", "FBA_EBSoundPath", detBG, "InputBoxTemplate")
ebSound:SetWidth(200); ebSound:SetHeight(20)
ebSound:SetPoint("LEFT", FBA_DDSound, "RIGHT", 8, 0)
ebSound:SetAutoFocus(false)
ebSound:Hide()
ebSound:SetScript("OnTextChanged", function(self)
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] and FBA_DDSound._mode == "custom" then
    local v = self:GetText()
    FBA.db.spells[key].sound = (v and v ~= "" and v) or "default"
  end
end)

local btnTest = CreateFrame("Button", nil, detBG, "UIPanelButtonTemplate")
btnTest:SetWidth(80); btnTest:SetHeight(20)
btnTest:SetPoint("TOPLEFT", 8, -196)
btnTest:SetText("Test")
btnTest:SetScript("OnClick", function()
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    local sp = FBA.db.spells[key]
    local mode = sp.sound or "default"
    if mode == "default" then PlaySoundFile("Sound\\Doodad\\BellTollHorde.wav")
    elseif mode ~= "none" then
      local ok = PlaySoundFile(mode); if not ok then PlaySoundFile("Sound\\Doodad\\BellTollHorde.wav") end
    end
    if FBA.db.showAlert then
      if FBA.db.alertCountdown then
        FBA:StartCountdown(sp.name, sp.threshold or 4)
      else
        local secs = math.floor((sp.threshold or 4) + 0.5)
        FBA:ShowStatic(sp.name.." expiring in "..secs.." seconds")
      end
    end
  end
end)

local btnRemove = CreateFrame("Button", nil, detBG, "UIPanelButtonTemplate")
btnRemove:SetWidth(80); btnRemove:SetHeight(20)
btnRemove:SetPoint("LEFT", btnTest, "RIGHT", 8, 0)
btnRemove:SetText("Remove")
btnRemove:SetScript("OnClick", function()
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    local nm = FBA.db.spells[key].name
    FBA.db.spells[key] = nil
    FBA.rt[key] = nil
    FBA.UI_selectedKey = nil
    FBA:UI_Refresh()
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r Removed '"..nm.."'")
  end
end)

-- Spellbook view in left panel (reuses the same button slots)
local bookList, bookRows = {}, {}
for i=1,visibleRows do
  local b = CreateFrame("Button", nil, listBG, "UIPanelButtonTemplate")
  b:SetWidth(260); b:SetHeight(22)
  b:SetPoint("TOPLEFT", 10, -20 - (i-1)*24)
  b:SetText("")
  b:SetScript("OnClick", function(self)
    FBA_AddBox:SetText(self._name or "")
  end)
  b:Hide()
  bookRows[i] = b
end

local bookFilter = CreateFrame("EditBox", "FBA_BookFilter", frame, "InputBoxTemplate")
bookFilter:SetWidth(260); bookFilter:SetHeight(20)
bookFilter:SetPoint("TOPLEFT", 20, -450)
bookFilter:SetAutoFocus(false)
bookFilter:Hide()
bookFilter:SetScript("OnTextChanged", function(self)
  FBA:UI_RebuildBookList(self:GetText())
end)

-- Tab switch
function FBA:UI_SwitchTab(which)
  FBA.UI_tab = which
  if which == "tracked" then
    listTitle:SetText("Tracked Buffs")
    FBA_AddBox:Show(); addBtn:Show()
    FBA_BookFilter:Hide()
    for i=1,visibleRows do rows[i]:Show(); bookRows[i]:Hide() end
  else
    listTitle:SetText("Spellbook (click name, then + Add)")
    FBA_AddBox:Hide(); addBtn:Show()
    FBA_BookFilter:Show()
    for i=1,visibleRows do rows[i]:Hide(); bookRows[i]:Show() end
    FBA:UI_RebuildBookList(FBA_BookFilter:GetText())
  end
  FBA.UI_page = 1
  FBA:UI_Refresh()
end

tabTracked:SetScript("OnClick", function() FBA:UI_SwitchTab("tracked") end)
tabBook:SetScript("OnClick", function() FBA:UI_SwitchTab("book") end)

-- Populate / refresh
function FBA:UI_Refresh()
  if not FBA or not FBA.db then return end

  FBA_CBEnabled:SetChecked(FBA.db.enabled and 1 or 0)
  FBA_CBSplash:SetChecked(FBA.db.showAlert and 1 or 0)
  FBA_CBCountdown:SetChecked(FBA.db.alertCountdown and 1 or 0)
  FBA_CBMinimap:SetChecked(FBA.db.minimap.show and 1 or 0)

  local page = FBA.UI_page or 1
  local start = (page-1)*visibleRows + 1

  if FBA.UI_tab == "book" then
    FBA:UI_RefreshDetail()
    return
  end

  local all = {}
  for key, sp in pairs(FBA.db.spells) do
    table.insert(all, { key=key, name=sp.name, enabled=sp.enabled })
  end
  table.sort(all, function(a,b) return string.lower(a.name) < string.lower(b.name) end)

  for row=1,visibleRows do
    local idx = start + (row-1)
    local entry = all[idx]
    local btnRow = rows[row]
    if entry then
      btnRow._key = entry.key
      local label = entry.name .. (entry.enabled and " |cff55ff55[ON]|r" or " |cffff5555[OFF]|r")
      btnRow:SetText(label)
      btnRow:Show()
    else
      btnRow._key = nil
      btnRow:SetText("")
      btnRow:Hide()
    end
  end

  FBA:UI_RefreshDetail()
end

function FBA:UI_RefreshDetail()
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    local sp = FBA.db.spells[key]
    txtName:SetText(sp.name or "—")
    FBA_CBSpellEnabled:SetChecked(sp.enabled and 1 or 0)
    FBA_CBCombat:SetChecked(sp.combatOnly and 1 or 0)
    FBA_CBLong:SetChecked(sp.useLongReminder and 1 or 0)
    FBA_EBDelay:SetText(tostring(sp.threshold or 4))
    local m = sp.sound or "default"
    FBA_DDSound._mode = (m == "default" or m == "none") and m or "custom"
    FBA_DDSound:SetText(FBA_DDSound._mode)
    if FBA_DDSound._mode == "custom" then
      FBA_EBSoundPath:Show()
      FBA_EBSoundPath:SetText((m ~= "default" and m ~= "none") and m or "")
    else
      FBA_EBSoundPath:Hide()
    end
  else
    txtName:SetText("—")
    FBA_CBSpellEnabled:SetChecked(0)
    FBA_CBCombat:SetChecked(0)
    FBA_CBLong:SetChecked(1)
    FBA_EBDelay:SetText("")
    FBA_DDSound._mode = "default"
    FBA_DDSound:SetText("default")
    FBA_EBSoundPath:Hide()
  end
end

function FBA:UI_RebuildBookList(filter)
  local names = FBA:GatherSpellbookNames()
  bookList = {}
  local fl = filter and string.lower(filter) or nil
  for i=1,table.getn(names) do
    local nm = names[i]
    if (not fl) or string.find(string.lower(nm), fl, 1, true) then
      table.insert(bookList, nm)
    end
  end
  table.sort(bookList, function(a,b) return string.lower(a) < string.lower(b) end)

  local page = FBA.UI_page or 1
  local start = (page-1)*visibleRows + 1
  for row=1,visibleRows do
    local idx = start + (row-1)
    local nm = bookList[idx]
    local b = bookRows[row]
    if nm then
      b._name = nm
      b:SetText(nm)
      b:Show()
    else
      b._name = nil
      b:SetText("")
      b:Hide()
    end
  end
end

function FBA:UI_Show()
  frame:Show()
  FBA:UI_SwitchTab(FBA.UI_tab or "tracked")
end
function FBA:UI_Hide() frame:Hide() end

function FBA:UI_Init()
  -- write-through delay
  FBA_EBDelay:SetScript("OnTextChanged", function(self)
    local key = FBA.UI_selectedKey
    if key and FBA.db and FBA.db.spells[key] then
      local t = tonumber(self:GetText())
      if t then
        if t < 0 then t = 0 end
        if t > 600 then t = 600 end
        FBA.db.spells[key].threshold = t
      end
    end
  end)
  FBA:UI_SwitchTab("tracked")
  FBA:UI_PositionMinimapButton()
end
