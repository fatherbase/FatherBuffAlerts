-- FatherBuffAlerts - Alerts (splash UI)
-- Version: 2.1.5

-- main alert frame
local alertFrame = CreateFrame("Frame", "FBA_AlertFrame", UIParent)
alertFrame:SetWidth(900); alertFrame:SetHeight(90)
alertFrame:Hide()

local text = alertFrame:CreateFontString(nil, "OVERLAY")
text:SetPoint("CENTER", alertFrame, "CENTER", 0, 0)
text:SetFont(STANDARD_TEXT_FONT, 32, "OUTLINE")
text:SetTextColor(1.0, 0.82, 0.0)
text:SetText("")

-- Movable anchor (Vanilla uses global `this` in handlers)
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
anchor:SetScript("OnDragStart", function() this:StartMoving() end)
anchor:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
  local cx, cy = this:GetCenter()
  local ux, uy = UIParent:GetCenter()
  FBA.db.alertPos = { x = math.floor(cx - ux + 0.5), y = math.floor(cy - uy + 0.5) }
  FBA:ApplyAlertPosition()
end)
anchor:Hide()

local anchorText = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
anchorText:SetPoint("CENTER", anchor, "CENTER", 0, 0)
anchorText:SetText("FatherBuffAlerts — Drag me, then /fba lock")

-- state
FBA.alertActive = false
FBA.alertModeCountdown = false
FBA.alertTimer = 0
FBA.alertHold = 1.2
FBA.alertFade = 1.0

-- countdown simulator (used by /fba test when countdown enabled)
FBA.cdSimActive = false
FBA.cdSimLabel  = nil
FBA.cdSimTL     = 0

local function Format1(s) if not s or s < 0 then s = 0 end return string.format("%.1f", s) end

function FBA:ApplyAlertPosition()
  local pos = self.db.alertPos or {x=0,y=0}
  FBA_AlertFrame:ClearAllPoints()
  FBA_AlertFrame:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
  FBA_Anchor:ClearAllPoints()
  FBA_Anchor:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
end

function FBA:ShowAnchor(show)
  if show then FBA_Anchor:Show() else FBA_Anchor:Hide() end
end

function FBA:ShowStatic(msg)
  if not self.db.showAlert then return end
  text:SetText(msg or "")
  FBA_AlertFrame:SetAlpha(1)
  FBA_AlertFrame:Show()
  self.alertActive = true
  self.alertModeCountdown = false
  self.alertTimer = 0
  self.cdSimActive = false
end

function FBA:StartCountdown(label, tl)
  if not self.db.showAlert then return end
  self.cdSimActive = false  -- external updates from Core
  local lbl = label or "Buff"
  text:SetText(lbl.." expiring in "..Format1(tl).."s")
  FBA_AlertFrame:SetAlpha(1)
  FBA_AlertFrame:Show()
  self.alertActive = true
  self.alertModeCountdown = true
end

-- simulated countdown for /fba test
function FBA:StartCountdownSim(label, seconds)
  if not self.db.showAlert then return end
  self.cdSimActive = true
  self.cdSimLabel = label or "Buff"
  self.cdSimTL = tonumber(seconds) or 4
  if self.cdSimTL < 0 then self.cdSimTL = 0 end
  text:SetText(self.cdSimLabel.." expiring in "..Format1(self.cdSimTL).."s")
  FBA_AlertFrame:SetAlpha(1)
  FBA_AlertFrame:Show()
  self.alertActive = true
  self.alertModeCountdown = true
end

function FBA:UpdateCountdown(label, tl)
  -- real countdown driven by Core; disable simulator
  self.cdSimActive = false
  if not self.alertModeCountdown then return end
  local lbl = label or "Buff"
  text:SetText(lbl.." expiring in "..Format1(tl).."s")
end

function FBA:HideAlert()
  FBA_AlertFrame:Hide()
  self.alertActive = false
  self.alertModeCountdown = false
  self.alertTimer = 0
  self.cdSimActive = false
end

function FBA:AlertOnUpdate(elapsed)
  if self.alertModeCountdown then
    -- if sim active, tick down ourselves
    if self.cdSimActive then
      self.cdSimTL = self.cdSimTL - elapsed
      if self.cdSimTL <= 0 then
        self:HideAlert()
      else
        text:SetText((self.cdSimLabel or "Buff").." expiring in "..Format1(self.cdSimTL).."s")
      end
    end
    return
  end

  -- fade static alerts
  if self.alertActive then
    self.alertTimer = self.alertTimer + elapsed
    local a
    if self.alertTimer <= self.alertHold then
      a = 1
    elseif self.alertTimer <= (self.alertHold + self.alertFade) then
      a = 1 - ((self.alertTimer - self.alertHold) / self.alertFade)
    else
      self:HideAlert()
      a = 0
    end
    if a and FBA_AlertFrame:IsShown() then FBA_AlertFrame:SetAlpha(a) end
  end
end

function FBA:InitAlerts()
  self:ApplyAlertPosition()
end
