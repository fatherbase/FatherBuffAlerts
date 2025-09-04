-- FatherBuffAlerts - Alerts (splash UI)
-- Version: 2.3.0

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

-- countdown stepping
FBA.cdStep = 0.1           -- 0.1 (≤10s), 1 (>10s), 10 (>30s)
FBA.cdLastBucket = nil     -- last displayed bucket value

-- countdown simulator (used by /fba test when countdown enabled)
FBA.cdSimActive = false
FBA.cdSimLabel  = nil
FBA.cdSimTL     = 0

local function FormatNum(step, v)
  if step >= 10 then
    return tostring(math.floor(v + 0.5))
  elseif step >= 1 then
    return tostring(math.floor(v + 0.0001))
  else
    return string.format("%.1f", v)
  end
end

local function quantize(step, tl)
  if step <= 0.11 then
    return math.floor(tl*10+0.0001)/10
  else
    return math.floor(tl/step) * step
  end
end

function FBA:SetCountdownStep(step)
  if not step or step <= 0 then step = 0.1 end
  self.cdStep = step
  self.cdLastBucket = nil
end

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

-- optional totalDur (seconds) to make the static alert disappear within that time
function FBA:ShowStatic(msg, totalDur)
  if not self.db.showAlert then return end
  text:SetText(msg or "")
  FBA_AlertFrame:SetAlpha(1)
  FBA_AlertFrame:Show()
  self.alertActive = true
  self.alertModeCountdown = false
  self.alertTimer = 0
  self.cdSimActive = false
  if totalDur and totalDur > 0 then
    local hold = math.max(0.8, totalDur - 1.5)
    local fade = totalDur - hold
    if fade < 0.5 then fade = 0.5 end
    self.alertHold = hold
    self.alertFade = fade
  else
    self.alertHold = 1.2
    self.alertFade = 1.0
  end
end

function FBA:StartCountdown(label, tl)
  if not self.db.showAlert then return end
  self.cdSimActive = false  -- external updates from Core
  self.cdLastBucket = nil
  local lbl = label or "Buff"
  local b = quantize(self.cdStep, tl or 0)
  text:SetText(lbl.." expiring in "..FormatNum(self.cdStep, b).."s")
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
  self.cdLastBucket = nil
  local b = quantize(self.cdStep, self.cdSimTL)
  text:SetText(self.cdSimLabel.." expiring in "..FormatNum(self.cdStep, b).."s")
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
  local b = quantize(self.cdStep, tl or 0)
  if self.cdLastBucket == nil or b ~= self.cdLastBucket then
    local s = FormatNum(self.cdStep, b)
    _G["FBA_AlertFrame"]:Show()
    _G["FBA_AlertFrame"]:SetAlpha(1)
    _G["FBA_Anchor"]:Hide()
    text:SetText(lbl.." expiring in "..s.."s")
    self.cdLastBucket = b
  end
end

function FBA:HideAlert()
  FBA_AlertFrame:Hide()
  self.alertActive = false
  self.alertModeCountdown = false
  self.alertTimer = 0
  self.cdSimActive = false
  self.cdLastBucket = nil
end

function FBA:AlertOnUpdate(elapsed)
  if self.alertModeCountdown then
    -- if sim active, tick down ourselves
    if self.cdSimActive then
      self.cdSimTL = self.cdSimTL - elapsed
      if self.cdSimTL <= 0 then
        self:HideAlert()
      else
        local lbl = self.cdSimLabel or "Buff"
        local b = quantize(self.cdStep, self.cdSimTL)
        if self.cdLastBucket == nil or b ~= self.cdLastBucket then
          text:SetText(lbl.." expiring in "..FormatNum(self.cdStep, b).."s")
          self.cdLastBucket = b
        end
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
