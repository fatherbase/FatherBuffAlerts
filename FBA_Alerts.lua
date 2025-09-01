-- FatherBuffAlerts - Alerts (splash UI)
-- Requires FBA_Core.lua

-- Build the splash
local alertFrame = CreateFrame("Frame", "FBA_AlertFrame", UIParent)
alertFrame:SetWidth(900); alertFrame:SetHeight(90)
alertFrame:Hide()

local text = alertFrame:CreateFontString(nil, "OVERLAY")
text:SetPoint("CENTER", alertFrame, "CENTER", 0, 0)
text:SetFont(STANDARD_TEXT_FONT, 32, "OUTLINE")
text:SetTextColor(1.0, 0.82, 0.0)
text:SetText("")

-- Movable anchor
local anchor = CreateFrame("Button", "FBA_Anchor", UIParent)
anchor:SetWidth(300); anchor:SetHeight(40)
anchor:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                     edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                     tile = true, tileSize = 16, edgeSize = 12,
                     insets = { left=3, right=3, top=3, bottom=3 } })
anchor:SetBackdropColor(0, 0, 0, 0.5)
anchor:EnableMouse(true)
anchor:SetMovable(true)
anchor:RegisterForDrag("LeftButton")
anchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
anchor:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local cx, cy = self:GetCenter()
  local ux, uy = UIParent:GetCenter()
  FBA.db.alertPos = { x = math.floor(cx - ux + 0.5), y = math.floor(cy - uy + 0.5) }
  FBA:ApplyAlertPosition()
end)
anchor:Hide()

local anchorText = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
anchorText:SetPoint("CENTER", anchor, "CENTER", 0, 0)
anchorText:SetText("FatherBuffAlerts — Drag me, then /fba lock")

-- State for fade (non-countdown)
FBA.alertActive = false
FBA.alertModeCountdown = false
FBA.alertTimer = 0
FBA.alertHold = 1.2
FBA.alertFade = 1.0

function FBA:ApplyAlertPosition()
  local pos = self.db.alertPos or {x=0,y=0}
  alertFrame:ClearAllPoints()
  alertFrame:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
  anchor:ClearAllPoints()
  anchor:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
end

function FBA:ShowAnchor(show)
  if show then anchor:Show() else anchor:Hide() end
end

local function Format1(s)
  if not s or s < 0 then s = 0 end
  return string.format("%.1f", s)
end

function FBA:ShowStatic(msg)
  if not self.db.showAlert then return end
  text:SetText(msg or "")
  alertFrame:SetAlpha(1)
  alertFrame:Show()
  self.alertActive = true
  self.alertModeCountdown = false
  self.alertTimer = 0
end

function FBA:StartCountdown(label, tl)
  if not self.db.showAlert then return end
  local lbl = label or "Buff"
  text:SetText(lbl.." expiring in "..Format1(tl).."s")
  alertFrame:SetAlpha(1)
  alertFrame:Show()
  self.alertActive = true
  self.alertModeCountdown = true
end

function FBA:UpdateCountdown(label, tl)
  if not self.alertModeCountdown then return end
  local lbl = label or "Buff"
  text:SetText(lbl.." expiring in "..Format1(tl).."s")
end

function FBA:HideAlert()
  alertFrame:Hide()
  self.alertActive = false
  self.alertModeCountdown = false
  self.alertTimer = 0
end

function FBA:AlertOnUpdate(elapsed)
  if self.alertActive and (not self.alertModeCountdown) then
    self.alertTimer = self.alertTimer + elapsed
    local a
    if self.alertTimer <= self.alertHold then
      a = 1
    elseif self.alertTimer <= (self.alertHold + self.alertFade) then
      local t = (self.alertTimer - self.alertHold) / self.alertFade
      a = 1 - t
    else
      self:HideAlert()
      a = 0
    end
    if a and FBA_AlertFrame:IsShown() then
      FBA_AlertFrame:SetAlpha(a)
    end
  end
end

function FBA:InitAlerts()
  self:ApplyAlertPosition()
end
