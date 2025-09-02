-- FatherBuffAlerts - Settings UI + Minimap button (WoW 1.12 / Lua 5.0)
-- Version: 2.1.7

-- =======================
-- Minimap Button (standard ring style)
-- =======================
local iconPathPrimary  = "Interface\\Icons\\Ability_Druid_CatForm"
local iconPathFallback = "Interface\\Icons\\INV_Misc_QuestionMark"

local btn = CreateFrame("Button", "FBA_MinimapButton", Minimap)
btn:SetWidth(31); btn:SetHeight(31)
btn:SetFrameStrata("HIGH")
btn:SetFrameLevel(9)
btn:RegisterForClicks("LeftButtonUp")
btn:RegisterForDrag("LeftButton")
btn:EnableMouse(true)
btn:SetMovable(false) -- we position via angle, not by moving
btn:SetClampedToScreen(true)

-- highlight ring (default Blizzard)
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- circular border overlay (gives the standard round look)
local border = btn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(53); border:SetHeight(53)
border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

-- optional tracking background (dim circle behind icon)
local back = btn:CreateTexture(nil, "BACKGROUND")
back:SetTexture("Interface\\Minimap\\MiniMap-TrackingBackground")
back:SetWidth(20); back:SetHeight(20)
back:SetPoint("CENTER", btn, "CENTER", 0, 0)

-- the actual icon
local ic = btn:CreateTexture("FBA_MinimapButtonIcon", "ARTWORK")
ic:SetWidth(20); ic:SetHeight(20)
ic:SetPoint("CENTER", btn, "CENTER", 0, 0)
ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
ic:SetTexture(iconPathPrimary)
if not ic:GetTexture() or ic:GetTexture() == "" then ic:SetTexture(iconPathFallback) end

btn:SetScript("OnClick", function()
  if FBA and FBA.UI_Show then FBA:UI_Show()
  else DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r UI not ready.") end
end)

-- Drag around the ring by updating angle each frame
local function deg2rad(d) return d * math.pi / 180 end
local function updateAngleFromCursor()
  if not (FBA and FBA.db and FBA.db.minimap) then return end
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  local dx = (px / scale) - mx
  local dy = (py / scale) - my
  local angle = math.deg(math.atan2(dy, dx))
  if angle < 0 then angle = angle + 360 end
  FBA.db.minimap.angle = math.floor(angle + 0.5)
  FBA:UI_PositionMinimapButton()
end

btn:SetScript("OnDragStart", function()
  this:SetScript("OnUpdate", updateAngleFromCursor)
end)
btn:SetScript("OnDragStop", function()
  this:SetScript("OnUpdate", nil)
end)

function FBA:UI_PositionMinimapButton()
  if not FBA.db or not FBA.db.minimap then return end
  local a = FBA.db.minimap.angle or 220
  local r = (Minimap:GetWidth() / 2) - 10
  local x = math.cos(deg2rad(a)) * r
  local y = math.sin(deg2rad(a)) * r
  FBA_MinimapButton:ClearAllPoints()
  FBA_MinimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
  if FBA.db.minimap.show then FBA_MinimapButton:Show() else FBA_MinimapButton:Hide() end
end

-- =======================
-- Settings Window
-- =======================
local frame = CreateFrame("Frame", "FBA_Config", UIParent)
frame:SetWidth(760); frame:SetHeight(540)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                    tile = true, tileSize = 32, edgeSize = 32,
                    insets = { left=8, right=8, top=8, bottom=8 } })
frame:Hide()
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

-- ESC close support
tinsert(UISpecialFrames, "FBA_Config")

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
title:SetPoint("TOP", frame, "TOP", 0, -16)
title:SetText("FatherBuffAlerts — Settings")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

-- Global toggles
local cbEnabled = CreateFrame("CheckButton", "FBA_CBEnabled", frame, "UICheckButtonTemplate")
cbEnabled:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -48)
FBA_CBEnabledText:SetText("Enabled (per-character)")
cbEnabled:SetScript("OnClick", function() if FBA and FBA.db then FBA.db.enabled = FBA_CBEnabled:GetChecked() end end)

local cbSplash = CreateFrame("CheckButton", "FBA_CBSplash", frame, "UICheckButtonTemplate")
cbSplash:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -72)
FBA_CBSplashText:SetText("Show on-screen splash")
cbSplash:SetScript("OnClick", function() if FBA and FBA.db then FBA.db.showAlert = FBA_CBSplash:GetChecked() end end)

local cbCountdown = CreateFrame("CheckButton", "FBA_CBCountdown", frame, "UICheckButtonTemplate")
cbCountdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -96)
FBA_CBCountdownText:SetText("Show live countdown text")
cbCountdown:SetScript("OnClick", function()
  if FBA and FBA.db then
    FBA.db.alertCountdown = FBA_CBCountdown:GetChecked()
    if not FBA_CBCountdown:GetChecked() then FBA:HideAlert() end
  end
end)

local cbMinimap = CreateFrame("CheckButton", "FBA_CBMinimap", frame, "UICheckButtonTemplate")
cbMinimap:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -120)
FBA_CBMinimapText:SetText("Show minimap button")
cbMinimap:SetScript("OnClick", function()
  if FBA and FBA.db then
    FBA.db.minimap.show = FBA_CBMinimap:GetChecked()
    FBA:UI_PositionMinimapButton()
  end
end)

-- Tabs
local tabTracked = CreateFrame("Button", "FBA_TabTracked", frame, "UIPanelButtonTemplate")
tabTracked:SetWidth(100); tabTracked:SetHeight(22)
tabTracked:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -150)
tabTracked:SetText("Tracked")

local tabBook = CreateFrame("Button", "FBA_TabBook", frame, "UIPanelButtonTemplate")
tabBook:SetWidth(100); tabBook:SetHeight(22)
tabBook:SetPoint("LEFT", tabTracked, "RIGHT", 8, 0)
tabBook:SetText("Spellbook")

-- Left list container (reused by both tabs)
local listBG = CreateFrame("Frame", nil, frame)
listBG:SetWidth(340); listBG:SetHeight(320)
listBG:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -180)
listBG:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                     edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                     tile = true, tileSize = 16, edgeSize = 12,
                     insets = { left=3, right=3, top=3, bottom=3 } })
listBG:SetBackdropColor(0,0,0,0.5)
listBG:EnableMouseWheel(1)

local listTitle = listBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
listTitle:SetPoint("TOPLEFT", listBG, "TOPLEFT", 8, -6)
listTitle:SetText("Tracked Buffs")

-- Page indicator + Prev/Next (works like scroll)
local pageText = listBG:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
pageText:SetPoint("BOTTOM", listBG, "BOTTOM", 0, 8)
pageText:SetText("Page 1/1")

local btnPrev = CreateFrame("Button", nil, listBG, "UIPanelButtonTemplate")
btnPrev:SetWidth(28); btnPrev:SetHeight(20)
btnPrev:SetPoint("RIGHT", pageText, "LEFT", -6, 0)
btnPrev:SetText("<")

local btnNext = CreateFrame("Button", nil, listBG, "UIPanelButtonTemplate")
btnNext:SetWidth(28); btnNext:SetHeight(20)
btnNext:SetPoint("LEFT", pageText, "RIGHT", 6, 0)
btnNext:SetText(">")

-- Rows with optional icon
local visibleRows = 11
local trackedRows, bookRows = {}, {}

-- tracked rows (text only)
for i=1,visibleRows do
  local b = CreateFrame("Button", nil, listBG, "UIPanelButtonTemplate")
  b:SetWidth(300); b:SetHeight(22)
  b:SetPoint("TOPLEFT", listBG, "TOPLEFT", 18, -24 - (i-1)*26)
  b:SetText("")
  b:SetScript("OnClick", function() FBA.UI_selectedKey = b._key; FBA:UI_RefreshDetail() end)
  trackedRows[i] = b
end

-- spellbook rows (icon + name)
for i=1,visibleRows do
  local row = CreateFrame("Button", nil, listBG, "UIPanelButtonTemplate")
  row:SetWidth(300); row:SetHeight(22)
  row:SetPoint("TOPLEFT", listBG, "TOPLEFT", 18, -24 - (i-1)*26)
  row._icon = row:CreateTexture(nil, "OVERLAY") -- ensure above button skin
  row._icon:SetWidth(18); row._icon:SetHeight(18)
  row._icon:SetPoint("LEFT", row, "LEFT", 6, 0)
  row._label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row._label:SetPoint("LEFT", row._icon, "RIGHT", 6, 0)
  row:SetScript("OnClick", function()
    if row._name then FBA_AddBox:SetText(row._name) end
  end)
  row:Hide()
  bookRows[i] = row
end

-- Add/custom and Add Next Cast
local addBox = CreateFrame("EditBox", "FBA_AddBox", frame, "InputBoxTemplate")
addBox:SetWidth(280); addBox:SetHeight(20)
addBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -515)
addBox:SetAutoFocus(false)

local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
addBtn:SetWidth(80); addBtn:SetHeight(22)
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
      DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r Added '"..nm.."'")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r Already tracking '"..nm.."'")
    end
  end
end)

local addNextBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
addNextBtn:SetWidth(120); addNextBtn:SetHeight(22)
addNextBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
addNextBtn:SetText("Add Next Cast")
addNextBtn:SetScript("OnClick", function()
  FBA.UI_waitNextCast = true
  DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r Watching your next cast...")
end)

-- Right detail panel
local detBG = CreateFrame("Frame", nil, frame)
detBG:SetWidth(360); detBG:SetHeight(320)
detBG:SetPoint("TOPLEFT", frame, "TOPLEFT", 380, -180)
detBG:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12,
                    insets = { left=3, right=3, top=3, bottom=3 } })
detBG:SetBackdropColor(0,0,0,0.5)

local detTitle = detBG:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
detTitle:SetPoint("TOPLEFT", detBG, "TOPLEFT", 8, -8)
detTitle:SetText("Buff Settings")

local lblName = detBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblName:SetPoint("TOPLEFT", detBG, "TOPLEFT", 8, -36)
lblName:SetText("Name: ")

local txtName = detBG:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
txtName:SetPoint("LEFT", lblName, "RIGHT", 4, 0)
txtName:SetText("—")

local cbSpellEnabled = CreateFrame("CheckButton", "FBA_CBSpellEnabled", detBG, "UICheckButtonTemplate")
cbSpellEnabled:SetPoint("TOPLEFT", detBG, "TOPLEFT", 8, -60)
FBA_CBSpellEnabledText:SetText("Enable this buff")
cbSpellEnabled:SetScript("OnClick", function()
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    FBA.db.spells[key].enabled = FBA_CBSpellEnabled:GetChecked()
    FBA:UI_Refresh()
  end
end)

local cbCombat = CreateFrame("CheckButton", "FBA_CBCombat", detBG, "UICheckButtonTemplate")
cbCombat:SetPoint("TOPLEFT", detBG, "TOPLEFT", 8, -84)
FBA_CBCombatText:SetText("Only alert in combat")
cbCombat:SetScript("OnClick", function()
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    FBA.db.spells[key].combatOnly = FBA_CBCombat:GetChecked()
  end
end)

local cbLong = CreateFrame("CheckButton", "FBA_CBLong", detBG, "UICheckButtonTemplate")
cbLong:SetPoint("TOPLEFT", detBG, "TOPLEFT", 8, -108)
FBA_CBLongText:SetText("5m reminder for ≥9m buffs")
cbLong:SetScript("OnClick", function()
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    FBA.db.spells[key].useLongReminder = FBA_CBLong:GetChecked()
  end
end)

local lblDelay = detBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblDelay:SetPoint("TOPLEFT", detBG, "TOPLEFT", 8, -136)
lblDelay:SetText("Delay (seconds):")

local ebDelay = CreateFrame("EditBox", "FBA_EBDelay", detBG, "InputBoxTemplate")
ebDelay:SetWidth(80); ebDelay:SetHeight(20)
ebDelay:SetPoint("LEFT", lblDelay, "RIGHT", 8, 0)
ebDelay:SetAutoFocus(false)
ebDelay:SetScript("OnEnterPressed", function() this:ClearFocus() end)

local lblSound = detBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblSound:SetPoint("TOPLEFT", detBG, "TOPLEFT", 8, -166)
lblSound:SetText("Sound:")

local ddSound = CreateFrame("Button", "FBA_DDSound", detBG, "UIPanelButtonTemplate")
ddSound:SetWidth(100); ddSound:SetHeight(20)
ddSound:SetPoint("LEFT", lblSound, "RIGHT", 8, 0)
ddSound._mode = "default"
ddSound:SetText("default")
ddSound:SetScript("OnClick", function()
  local m = FBA_DDSound._mode
  if m == "default" then m = "none"
  elseif m == "none" then m = "custom"
  else m = "default" end
  FBA_DDSound._mode = m
  FBA_DDSound:SetText(m)
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
ebSound:SetWidth(220); ebSound:SetHeight(20)
ebSound:SetPoint("LEFT", ddSound, "RIGHT", 8, 0)
ebSound:SetAutoFocus(false)
ebSound:Hide()
ebSound:SetScript("OnTextChanged", function()
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] and FBA_DDSound._mode == "custom" then
    local v = FBA_EBSoundPath:GetText()
    FBA.db.spells[key].sound = (v and v ~= "" and v) or "default"
  end
end)

local btnTest = CreateFrame("Button", nil, detBG, "UIPanelButtonTemplate")
btnTest:SetWidth(80); btnTest:SetHeight(20)
btnTest:SetPoint("TOPLEFT", detBG, "TOPLEFT", 8, -196)
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
        FBA:StartCountdownSim(sp.name, sp.threshold or 4)
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

-- Data / paging
FBA.UI_tab = "tracked"
FBA.UI_page = 1
FBA.UI_book = {}  -- { {name=, texture=, active?=} ... }
local function updatePageIndicator(totalCount)
  local per = visibleRows
  local totalPages = math.max(1, math.ceil((totalCount or 0) / per))
  if FBA.UI_page > totalPages then FBA.UI_page = totalPages end
  pageText:SetText("Page "..FBA.UI_page.."/"..totalPages)
end

-- Tab switch
function FBA:UI_SwitchTab(which)
  FBA.UI_tab = which
  if which == "tracked" then
    listTitle:SetText("Tracked Buffs")
    if FBA_BookFilter then FBA_BookFilter:Hide() end
    for i=1,visibleRows do trackedRows[i]:Show(); bookRows[i]:Hide() end
  else
    listTitle:SetText("Spellbook (actives first; click a spell, then + Add)")
    if FBA_BookFilter then FBA_BookFilter:Show() end
    -- build book list with actives first
    FBA.UI_book = FBA:BuildBookList(nil)
    for i=1,visibleRows do trackedRows[i]:Hide(); bookRows[i]:Show() end
  end
  FBA.UI_page = 1
  FBA:UI_Refresh()
end
tabTracked:SetScript("OnClick", function() FBA:UI_SwitchTab("tracked") end)
tabBook:SetScript("OnClick", function() FBA:UI_SwitchTab("book") end)

-- Mouse wheel to change page
listBG:SetScript("OnMouseWheel", function()
  if arg1 > 0 then
    FBA.UI_page = math.max(1, (FBA.UI_page or 1) - 1)
  else
    FBA.UI_page = (FBA.UI_page or 1) + 1
  end
  FBA:UI_Refresh()
end)
btnPrev:SetScript("OnClick", function()
  FBA.UI_page = math.max(1, (FBA.UI_page or 1) - 1)
  FBA:UI_Refresh()
end)
btnNext:SetScript("OnClick", function()
  FBA.UI_page = (FBA.UI_page or 1) + 1
  FBA:UI_Refresh()
end)

-- Refresh lists
function FBA:UI_Refresh()
  if not FBA or not FBA.db then return end

  FBA_CBEnabled:SetChecked(FBA.db.enabled and 1 or 0)
  FBA_CBSplash:SetChecked(FBA.db.showAlert and 1 or 0)
  FBA_CBCountdown:SetChecked(FBA.db.alertCountdown and 1 or 0)
  FBA_CBMinimap:SetChecked(FBA.db.minimap.show and 1 or 0)

  if FBA.UI_tab == "book" then
    -- (re)build with filter
    local filter = FBA_BookFilter and FBA_BookFilter:GetText() or ""
    local fl = (filter and filter ~= "" and string.lower(filter)) or nil
    FBA.UI_book = FBA:BuildBookList(fl)

    local all = FBA.UI_book or {}
    local per = visibleRows
    updatePageIndicator(table.getn(all))
    local start = ((FBA.UI_page or 1)-1)*per + 1
    for row=1,visibleRows do
      local idx = start + (row-1)
      local entry = all[idx]
      local w = bookRows[row]
      if entry then
        w._name = entry.name
        w._icon:SetTexture(entry.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        local label = entry.name
        if entry.active then label = label.." |cff55ff55(active)|r" end
        w._label:SetText(label)
        w:Show()
      else
        w._name = nil
        w._label:SetText("")
        w._icon:SetTexture(nil)
        w:Hide()
      end
    end
    FBA:UI_RefreshDetail()
    return
  end

  -- tracked
  local all = {}
  for key, sp in pairs(FBA.db.spells) do
    table.insert(all, { key=key, name=sp.name, enabled=sp.enabled })
  end
  table.sort(all, function(a,b) return string.lower(a.name) < string.lower(b.name) end)

  local per = visibleRows
  updatePageIndicator(table.getn(all))
  local start = ((FBA.UI_page or 1)-1)*per + 1

  for row=1,visibleRows do
    local idx = start + (row-1)
    local entry = all[idx]
    local btnRow = trackedRows[row]
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

-- Spellbook filter box
local bookFilter = CreateFrame("EditBox", "FBA_BookFilter", frame, "InputBoxTemplate")
bookFilter:SetWidth(300); bookFilter:SetHeight(20)
bookFilter:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -510)
bookFilter:SetAutoFocus(false)
bookFilter:Hide()
bookFilter:SetScript("OnTextChanged", function() FBA:UI_Refresh() end)

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

function FBA:UI_Show()
  FBA_Config:Show()
  FBA:UI_SwitchTab(FBA.UI_tab or "tracked")
end
function FBA:UI_Hide() FBA_Config:Hide() end

function FBA:UI_Init()
  -- write-through delay
  FBA_EBDelay:SetScript("OnTextChanged", function()
    local key = FBA.UI_selectedKey
    if key and FBA.db and FBA.db.spells[key] then
      local t = tonumber(FBA_EBDelay:GetText())
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
