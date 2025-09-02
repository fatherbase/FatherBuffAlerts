-- FatherBuffAlerts - Settings UI + Minimap button (WoW 1.12 / Lua 5.0)
-- Version: 2.1.10

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
btn:SetMovable(false) -- positioned via angle
btn:SetClampedToScreen(true)

btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local border = btn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(53); border:SetHeight(53)
border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

local back = btn:CreateTexture(nil, "BACKGROUND")
back:SetTexture("Interface\\Minimap\\MiniMap-TrackingBackground")
back:SetWidth(20); back:SetHeight(20)
back:SetPoint("CENTER", btn, "CENTER", 0, 0)

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

btn:SetScript("OnDragStart", function() this:SetScript("OnUpdate", updateAngleFromCursor) end)
btn:SetScript("OnDragStop",  function() this:SetScript("OnUpdate", nil) end)

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
-- Settings Window (Buff Settings strip under toggles; Spellbook left; Tracked right)
-- =======================
local frame = CreateFrame("Frame", "FBA_Config", UIParent)
frame:SetWidth(880); frame:SetHeight(600)
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
tinsert(UISpecialFrames, "FBA_Config")

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
title:SetPoint("TOP", frame, "TOP", 0, -16)
title:SetText("FatherBuffAlerts — Settings")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

-- Global toggles (top)
local cbEnabled = CreateFrame("CheckButton", "FBA_CBEnabled", frame, "UICheckButtonTemplate")
cbEnabled:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -48)
FBA_CBEnabledText:SetText("Enabled")
cbEnabled:SetScript("OnClick", function() if FBA and FBA.db then FBA.db.enabled = FBA_CBEnabled:GetChecked() end end)

local cbSplash = CreateFrame("CheckButton", "FBA_CBSplash", frame, "UICheckButtonTemplate")
cbSplash:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -72)
FBA_CBSplashText:SetText("Show on-screen splash (global)")
cbSplash:SetScript("OnClick", function() if FBA and FBA.db then FBA.db.showAlert = FBA_CBSplash:GetChecked() end end)

local cbCountdown = CreateFrame("CheckButton", "FBA_CBCountdown", frame, "UICheckButtonTemplate")
cbCountdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -96)
FBA_CBCountdownText:SetText("Enable live countdown (global)")
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

-- ===== Buff Settings STRIP (under toggles; no overlap)
local detBG = CreateFrame("Frame", nil, frame)
detBG:SetWidth(840); detBG:SetHeight(126)
detBG:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -150)  -- pushed a bit lower to avoid any overlap
detBG:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12,
                    insets = { left=3, right=3, top=3, bottom=3 } })
detBG:SetBackdropColor(0,0,0,0.5)

local detTitle = detBG:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
detTitle:SetPoint("TOPLEFT", detBG, "TOPLEFT", 8, -8)
detTitle:SetText("Buff Settings")

local lblName = detBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblName:SetPoint("TOPLEFT", detBG, "TOPLEFT", 8, -34)
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

local cbBuffSplash = CreateFrame("CheckButton", "FBA_CBBuffSplash", detBG, "UICheckButtonTemplate")
cbBuffSplash:SetPoint("LEFT", FBA_CBSpellEnabled, "RIGHT", 140, 0)
FBA_CBBuffSplashText:SetText("On-screen splash for this buff")
cbBuffSplash:SetScript("OnClick", function()
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    FBA.db.spells[key].showSplash = FBA_CBBuffSplash:GetChecked()
  end
end)

local cbCombat = CreateFrame("CheckButton", "FBA_CBCombat", detBG, "UICheckButtonTemplate")
cbCombat:SetPoint("LEFT", FBA_CBBuffSplash, "RIGHT", 140, 0)
FBA_CBCombatText:SetText("Only alert in combat")
cbCombat:SetScript("OnClick", function()
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    FBA.db.spells[key].combatOnly = FBA_CBCombat:GetChecked()
  end
end)

local cbLong = CreateFrame("CheckButton", "FBA_CBLong", detBG, "UICheckButtonTemplate")
cbLong:SetPoint("TOPLEFT", detBG, "TOPLEFT", 8, -86)
FBA_CBLongText:SetText("5m reminder for ≥9m buffs")
cbLong:SetScript("OnClick", function()
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    FBA.db.spells[key].useLongReminder = FBA_CBLong:GetChecked()
  end
end)

local cbCD = CreateFrame("CheckButton", "FBA_CBCDown", detBG, "UICheckButtonTemplate")
cbCD:SetPoint("LEFT", FBA_CBLong, "RIGHT", 140, 0)
FBA_CBCDownText:SetText("Live countdown for this buff")
cbCD:SetScript("OnClick", function()
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] then
    FBA.db.spells[key].showCountdown = FBA_CBCDown:GetChecked()
  end
end)

local lblDelay = detBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblDelay:SetPoint("LEFT", FBA_CBCDown, "RIGHT", 140, 0)
lblDelay:SetText("Delay (s):")

local ebDelay = CreateFrame("EditBox", "FBA_EBDelay", detBG, "InputBoxTemplate")
ebDelay:SetWidth(60); ebDelay:SetHeight(20)
ebDelay:SetPoint("LEFT", lblDelay, "RIGHT", 6, 0)
ebDelay:SetAutoFocus(false)
ebDelay:SetScript("OnEnterPressed", function() this:ClearFocus() end)

local lblSound = detBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblSound:SetPoint("LEFT", FBA_EBDelay, "RIGHT", 16, 0)
lblSound:SetText("Sound:")

local ddSound = CreateFrame("Button", "FBA_DDSound", detBG, "UIPanelButtonTemplate")
ddSound:SetWidth(100); ddSound:SetHeight(20)
ddSound:SetPoint("LEFT", lblSound, "RIGHT", 6, 0)
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
ebSound:SetPoint("LEFT", ddSound, "RIGHT", 6, 0)
ebSound:SetAutoFocus(false)
ebSound:Hide()
ebSound:SetScript("OnTextChanged", function()
  local key = FBA.UI_selectedKey
  if key and FBA.db and FBA.db.spells[key] and FBA_DDSound._mode == "custom" then
    local v = FBA_EBSoundPath:GetText()
    FBA.db.spells[key].sound = (v and v ~= "" and v) or "default"
  end
end)

-- ===== Lists (Spellbook left + Tracked right)
-- Left: Spellbook panel
local bookBG = CreateFrame("Frame", nil, frame)
bookBG:SetWidth(380); bookBG:SetHeight(320)
bookBG:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -290)
bookBG:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                     edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                     tile = true, tileSize = 16, edgeSize = 12,
                     insets = { left=3, right=3, top=3, bottom=3 } })
bookBG:SetBackdropColor(0,0,0,0.5)
bookBG:EnableMouseWheel(1)

local bookTitle = bookBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bookTitle:SetPoint("TOPLEFT", bookBG, "TOPLEFT", 8, -6)
bookTitle:SetText("Spellbook (actives first) — click to add")

-- Page at TOP RIGHT (so it never goes under the main panel)
local bookPageText = bookBG:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bookPageText:SetPoint("TOPRIGHT", bookBG, "TOPRIGHT", -8, -8)
bookPageText:SetText("Page 1/1")

local bookPrev = CreateFrame("Button", nil, bookBG, "UIPanelButtonTemplate")
bookPrev:SetWidth(22); bookPrev:SetHeight(20)
bookPrev:SetPoint("RIGHT", bookPageText, "LEFT", -4, 0)
bookPrev:SetText("<")

local bookNext = CreateFrame("Button", nil, bookBG, "UIPanelButtonTemplate")
bookNext:SetWidth(22); bookNext:SetHeight(20)
bookNext:SetPoint("LEFT", bookPageText, "RIGHT", 4, 0)
bookNext:SetText(">")

-- Filter box INSIDE the spellbook panel (not under lists)
local bookFilter = CreateFrame("EditBox", "FBA_BookFilter", bookBG, "InputBoxTemplate")
bookFilter:SetWidth(340); bookFilter:SetHeight(20)
bookFilter:SetPoint("TOPLEFT", bookBG, "TOPLEFT", 18, -30)
bookFilter:SetAutoFocus(false)
bookFilter:SetText("")
bookFilter:SetScript("OnTextChanged", function() FBA:UI_Refresh() end)

-- Right: Tracked panel
local trackedBG = CreateFrame("Frame", nil, frame)
trackedBG:SetWidth(380); trackedBG:SetHeight(320)
trackedBG:SetPoint("TOPLEFT", frame, "TOPLEFT", 480, -290)
trackedBG:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                        tile = true, tileSize = 16, edgeSize = 12,
                        insets = { left=3, right=3, top=3, bottom=3 } })
trackedBG:SetBackdropColor(0,0,0,0.5)
trackedBG:EnableMouseWheel(1)

local trackedTitle = trackedBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
trackedTitle:SetPoint("TOPLEFT", trackedBG, "TOPLEFT", 8, -6)
trackedTitle:SetText("Tracked Buffs")

-- Page at TOP RIGHT
local trackedPageText = trackedBG:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
trackedPageText:SetPoint("TOPRIGHT", trackedBG, "TOPRIGHT", -8, -8)
trackedPageText:SetText("Page 1/1")

local trackedPrev = CreateFrame("Button", nil, trackedBG, "UIPanelButtonTemplate")
trackedPrev:SetWidth(22); trackedPrev:SetHeight(20)
trackedPrev:SetPoint("RIGHT", trackedPageText, "LEFT", -4, 0)
trackedPrev:SetText("<")

local trackedNext = CreateFrame("Button", nil, trackedBG, "UIPanelButtonTemplate")
trackedNext:SetWidth(22); trackedNext:SetHeight(20)
trackedNext:SetPoint("LEFT", trackedPageText, "RIGHT", 4, 0)
trackedNext:SetText(">")

-- Add-by-name + Next Cast INSIDE the tracked panel (not under lists)
local addBox = CreateFrame("EditBox", "FBA_AddBox", trackedBG, "InputBoxTemplate")
addBox:SetWidth(210); addBox:SetHeight(20)
addBox:SetPoint("TOPLEFT", trackedBG, "TOPLEFT", 18, -30)
addBox:SetAutoFocus(false)

local addBtn = CreateFrame("Button", nil, trackedBG, "UIPanelButtonTemplate")
addBtn:SetWidth(100); addBtn:SetHeight(20)
addBtn:SetPoint("LEFT", addBox, "RIGHT", 6, 0)
addBtn:SetText("Add by name")
addBtn:SetScript("OnClick", function()
  local nm = FBA_AddBox:GetText()
  if nm and nm ~= "" and FBA and FBA.db then
    local key = string.lower(nm)
    if not FBA.db.spells[key] then
      FBA.db.spells[key] = { name = nm, enabled = true, threshold = 4, sound = "default",
                             combatOnly=false, useLongReminder=true, showCountdown=true, showSplash=true }
      FBA_AddBox:SetText("")
      FBA:UI_Refresh()
      DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r Added '"..nm.."'")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r Already tracking '"..nm.."'")
    end
  end
end)

local addNextBtn = CreateFrame("Button", nil, trackedBG, "UIPanelButtonTemplate")
addNextBtn:SetWidth(120); addNextBtn:SetHeight(20)
addNextBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)
addNextBtn:SetText("Add Next Cast")
addNextBtn:SetScript("OnClick", function()
  FBA.UI_waitNextCast = true
  DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r Watching your next cast; the next spell you cast will be added to Tracked automatically.")
end)

-- Rows (start LOWER so they don't overlap the top controls)
local visibleRows = 10
local bookRows, trackedRows = {}, {}

local function makeIconRow(parent)
  local row = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  row:SetWidth(340); row:SetHeight(22)
  row._icon = row:CreateTexture(nil, "OVERLAY")
  row._icon:SetWidth(18); row._icon:SetHeight(18)
  row._icon:SetPoint("LEFT", row, "LEFT", 6, 0)
  row._label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row._label:SetPoint("LEFT", row._icon, "RIGHT", 6, 0)
  return row
end

for i=1,visibleRows do
  local r = makeIconRow(bookBG)
  r:SetPoint("TOPLEFT", bookBG, "TOPLEFT", 18, -56 - (i-1)*26) -- was -24; lowered for filter row
  r:SetScript("OnClick", function()
    if r._name and FBA and FBA.db then
      local key = string.lower(r._name)
      if not FBA.db.spells[key] then
        FBA.db.spells[key] = { name = r._name, enabled = true, threshold = 4, sound = "default",
                               combatOnly=false, useLongReminder=true, showCountdown=true, showSplash=true }
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r Added '"..r._name.."'")
        FBA:UI_Refresh()
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9933FatherBuffAlerts:|r Already tracking '"..r._name.."'")
      end
    end
  end)
  r:Hide(); bookRows[i] = r
end

for i=1,visibleRows do
  local r = makeIconRow(trackedBG)
  r:SetPoint("TOPLEFT", trackedBG, "TOPLEFT", 18, -56 - (i-1)*26) -- lowered for add controls
  r:SetScript("OnClick", function() FBA.UI_selectedKey = r._key; FBA:UI_RefreshDetail() end)
  r:Hide(); trackedRows[i] = r
end

-- Paging state
FBA.UI_bookPage = 1
FBA.UI_trackPage = 1
FBA.UI_book = {}  -- { {name=, texture=, active?=} ... }

local function updatePageText(whichCount, whichPageText, pageVarName)
  local per = visibleRows
  local totalPages = math.max(1, math.ceil((whichCount or 0) / per))
  if FBA[pageVarName] > totalPages then FBA[pageVarName] = totalPages end
  whichPageText:SetText("Page "..FBA[pageVarName].."/"..totalPages)
end

bookPrev:SetScript("OnClick", function()
  FBA.UI_bookPage = math.max(1, FBA.UI_bookPage - 1); FBA:UI_Refresh()
end)
bookNext:SetScript("OnClick", function()
  FBA.UI_bookPage = FBA.UI_bookPage + 1; FBA:UI_Refresh()
end)
trackedPrev:SetScript("OnClick", function()
  FBA.UI_trackPage = math.max(1, FBA.UI_trackPage - 1); FBA:UI_Refresh()
end)
trackedNext:SetScript("OnClick", function()
  FBA.UI_trackPage = FBA.UI_trackPage + 1; FBA:UI_Refresh()
end)

-- Refresh UI
function FBA:UI_Refresh()
  if not FBA or not FBA.db then return end

  FBA_CBEnabled:SetChecked(FBA.db.enabled and 1 or 0)
  FBA_CBSplash:SetChecked(FBA.db.showAlert and 1 or 0)
  FBA_CBCountdown:SetChecked(FBA.db.alertCountdown and 1 or 0)
  FBA_CBMinimap:SetChecked(FBA.db.minimap.show and 1 or 0)

  -- left: book
  local filter = FBA_BookFilter and FBA_BookFilter:GetText() or ""
  local fl = (filter and filter ~= "" and string.lower(filter)) or nil
  FBA.UI_book = FBA:BuildBookList(fl)

  local books = FBA.UI_book or {}
  updatePageText(table.getn(books), bookPageText, "UI_bookPage")
  local bstart = ((FBA.UI_bookPage or 1)-1)*visibleRows + 1

  for row=1,visibleRows do
    local idx = bstart + (row-1)
    local entry = books[idx]
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

  -- right: tracked
  local tracked = {}
  for key, sp in pairs(FBA.db.spells) do
    table.insert(tracked, { key=key, name=sp.name, enabled=sp.enabled })
  end
  table.sort(tracked, function(a,b) return string.lower(a.name) < string.lower(b.name) end)

  updatePageText(table.getn(tracked), trackedPageText, "UI_trackPage")
  local tstart = ((FBA.UI_trackPage or 1)-1)*visibleRows + 1

  for row=1,visibleRows do
    local idx = tstart + (row-1)
    local entry = tracked[idx]
    local w = trackedRows[row]
    if entry then
      w._key = entry.key
      w._name = entry.name
      w._icon:SetTexture(FBA:GetSpellTextureByName(entry.name))
      local label = entry.name .. (entry.enabled and " |cff55ff55[ON]|r" or " |cffff5555[OFF]|r")
      w._label:SetText(label)
      w:Show()
    else
      w._key = nil
      w._name = nil
      w._label:SetText("")
      w._icon:SetTexture(nil)
      w:Hide()
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
    FBA_CBBuffSplash:SetChecked((sp.showSplash ~= false) and 1 or 0)
    FBA_CBCombat:SetChecked(sp.combatOnly and 1 or 0)
    FBA_CBLong:SetChecked(sp.useLongReminder and 1 or 0)
    FBA_CBCDown:SetChecked((sp.showCountdown ~= false) and 1 or 0)
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
    FBA_CBBuffSplash:SetChecked(1)
    FBA_CBCombat:SetChecked(0)
    FBA_CBLong:SetChecked(1)
    FBA_CBCDown:SetChecked(1)
    FBA_EBDelay:SetText("")
    FBA_DDSound._mode = "default"
    FBA_DDSound:SetText("default")
    FBA_EBSoundPath:Hide()
  end
end

function FBA:UI_Show()
  FBA_Config:Show()
  FBA:UI_Refresh()
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
  FBA:UI_PositionMinimapButton()
  FBA:UI_Refresh()
end

-- UI callback from "add next cast"
function FBA:UI_OnAddedFromCast(spellName)
  local key = string.lower(spellName or "")
  if self.db and self.db.spells[key] then
    self.UI_selectedKey = key
  end
  self:UI_Refresh()
end
