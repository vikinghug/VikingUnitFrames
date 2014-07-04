require "Window"
require "Unit"
require "GameLib"
require "Apollo"
require "ApolloColor"
require "Window"

local VikingUnitFrames = {
  _VERSION = 'VikingUnitFrames.lua 0.1.0',
  _URL     = 'https://github.com/vikinghug/VikingUnitFrames',
  _DESCRIPTION = '',
  _LICENSE = [[
    MIT LICENSE

    Copyright (c) 2014 Kevin Altman

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]]
}

-- GameLib.CodeEnumClass.Warrior      = 1
-- GameLib.CodeEnumClass.Engineer     = 2
-- GameLib.CodeEnumClass.Esper        = 3
-- GameLib.CodeEnumClass.Medic        = 4
-- GameLib.CodeEnumClass.Stalker      = 5
-- GameLib.CodeEnumClass.Spellslinger = 7

local tClassName = {
  [GameLib.CodeEnumClass.Warrior]      = "Warrior",
  [GameLib.CodeEnumClass.Engineer]     = "Engineer",
  [GameLib.CodeEnumClass.Esper]        = "Esper",
  [GameLib.CodeEnumClass.Medic]        = "Medic",
  [GameLib.CodeEnumClass.Stalker]      = "Stalker",
  [GameLib.CodeEnumClass.Spellslinger] = "Spellslinger"
}

function VikingUnitFrames:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function VikingUnitFrames:Init()
  Apollo.RegisterAddon(self, nil, nil, {"VikingLibrary"})
end

function VikingUnitFrames:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("VikingUnitFrames.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)

  Apollo.RegisterEventHandler("ActionBarLoaded", "OnRequiredFlagsChanged", self)

  Apollo.LoadSprites("VikingClassResourcesSprites.xml")
end

function VikingUnitFrames:OnDocumentReady()
  if self.xmlDoc == nil then
    return
  end

  Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
  Apollo.RegisterEventHandler("WindowManagementUpdate", "OnWindowManagementUpdate", self)
  Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterLoaded", self)
  Apollo.RegisterEventHandler("TargetUnitChanged", "OnTargetUnitChanged", self)
  Apollo.RegisterEventHandler("PlayerLevelChange", "OnUnitLevelChange", self)
  Apollo.RegisterEventHandler("UnitLevelChanged",  "OnUnitLevelChange", self)
  Apollo.RegisterEventHandler("AlternateTargetUnitChanged", "OnAlternateTargetUnitChanged", self)
  Apollo.RegisterEventHandler("VarChange_FrameCount", "OnFrame", self)

  self.bDocLoaded = true
  self:OnRequiredFlagsChanged()
end

function VikingUnitFrames:OnWindowManagementReady()
  Event_FireGenericEvent("WindowManagementAdd", { wnd = self.tPlayerFrame.wndUnitFrame, strName = Apollo.GetString("OptionsHUD_MyUnitFrameLabel") })
  Event_FireGenericEvent("WindowManagementAdd", { wnd = self.tTargetFrame.wndUnitFrame, strName = Apollo.GetString("OptionsHUD_TargetFrameLabel") })
end

function VikingUnitFrames:OnRequiredFlagsChanged()
  if g_wndActionBarResources and self.bDocLoaded then
    if GameLib.GetPlayerUnit() then
      self:OnCharacterCreated()
    else
      Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
    end
  end
end

function VikingUnitFrames:OnUnitLevelChange()
  self:SetUnitLevel(self.tPlayerFrame)
  self:SetUnitLevel(self.tTargetFrame)
end


--
-- CreateUnitFrame
--
--   Builds a UnitFrame instance

function VikingUnitFrames:CreateUnitFrame(name)

  local wndUnitFrame = Apollo.LoadForm(self.xmlDoc, "UnitFrame", "FixedHudStratumLow" , self)

  local tFrame = {
    name         = name,
    wndUnitFrame = wndUnitFrame,
    wndHealthBar = wndUnitFrame:FindChild("Bars:Health"),
    wndShieldBar = wndUnitFrame:FindChild("Bars:Shield"),
    wndAbsorbBar = wndUnitFrame:FindChild("Bars:Absorb"),
    wndCastBar   = wndUnitFrame:FindChild("Bars:Cast"),
    unit         = nil
  }

  self:InitColors(tFrame)

  return tFrame

end


--
-- OnCharacterCreated
--
--
function VikingUnitFrames:OnCharacterCreated()
  local unitPlayer = GameLib.GetPlayerUnit()
  if not unitPlayer then
    return
  end

  self.VL = Apollo.GetAddon("VikingLibrary")

  if self.VL then
    self.db = VL.GetDatabase("VikingUnitFrames")
    -- self.wndSettings = self.VL.RegisterSettings(self, self.xmlDoc)
  end

  -- My Unit Frame
  self.tPlayerFrame = self:CreateUnitFrame("Player")
  self:SetUnit(self.tPlayerFrame, unitPlayer)
  self:SetUnitName(self.tPlayerFrame, unitPlayer:GetName())
  self:SetUnitLevel(self.tPlayerFrame)

  self.tPlayerFrame.locDefaultPosition = WindowLocation.new(self.db.position.playerFrame)
  self.tPlayerFrame.wndUnitFrame:MoveToLocation(self.tPlayerFrame.locDefaultPosition)


  -- Target Frame
  self.tTargetFrame = self:CreateUnitFrame("Target")
  self.tTargetFrame.locDefaultPosition = WindowLocation.new(self.db.position.targetFrame)
  self.tTargetFrame.wndUnitFrame:MoveToLocation(self.tTargetFrame.locDefaultPosition)


  self.eClassID =  unitPlayer:GetClassId()
end


--
-- OnTargetUnitChanged
--

function VikingUnitFrames:OnTargetUnitChanged(unitTarget)

  self.tTargetFrame.wndUnitFrame:Show(unitTarget ~= nil)

  if unitTarget ~= nil then
    self:SetUnit(self.tTargetFrame, unitTarget)
    self:SetUnitName(self.tTargetFrame, unitTarget:GetName())
  end

  self.unitTarget = unitTarget
end

--
-- OnFrame
--
-- Render loop

function VikingUnitFrames:OnFrame()

  if self.tPlayerFrame ~= nil and self.tTargetFrame ~= nil then

    -- UnitFrame
    self:UpdateBars(self.tPlayerFrame)

    -- TargetFrame
    self:UpdateBars(self.tTargetFrame)
    self:SetUnitLevel(self.tTargetFrame)


  end

end

--
-- UpdateBars
--
-- Update the bars for a unit on UnitFrame

function VikingUnitFrames:UpdateBars(tFrame)

  local tHealthMap = {
    bar     = "Health",
    current = "GetHealth",
    max     = "GetMaxHealth"
  }

  local tShieldMap = {
    bar     = "Shield",
    current = "GetShieldCapacity",
    max     = "GetShieldCapacityMax"

  }

  local tAbsorbMap = {
    bar     = "Absorb",
    current = "GetAbsorptionValue",
    max     = "GetAbsorptionMax"
  }

  self:UpdateCastBar(tFrame)
  self:SetBar(tFrame, tHealthMap)
  self:SetBar(tFrame, tShieldMap)
  self:SetBar(tFrame, tAbsorbMap)
end


function VikingUnitFrames:UpdateCastBar(tFrame)
  if tFrame.unit == nil then return end
  local unit = tFrame.unit
  local isCasting = unit:ShouldShowCastBar()

  if isCasting then
    local nDuration = unit:GetCastDuration()
    if nDuration == nil then return end
    self:CreateCastProgress(tFrame, unit:GetCastDuration())
  elseif tFrame.CastTimerDone ~= nil then
    self:KillTimer(tFrame)
    tFrame.bNotCasting = true
  end
end

-- SetBar
--
-- Set Bar Value on UnitFrame

function VikingUnitFrames:SetBar(tFrame, tMap)
  if tFrame.unit ~= nil and tMap ~= nil then
    local unit        = tFrame.unit
    local nCurrent    = unit[tMap.current](unit)
    local nMax        = unit[tMap.max](unit)
    local wndBar      = tFrame["wnd" .. tMap.bar .. "Bar"]
    local wndProgress = wndBar:FindChild("ProgressBar")

    local isValidBar = (nMax ~= nil and nMax ~= 0) and true or false
    wndProgress:Show(isValidBar)

    if isValidBar then

      wndProgress:Show(true)

      wndProgress:SetMax(nMax)
      wndProgress:SetProgress(nCurrent)

      local nLowBar     = 0.3
      local nAverageBar = 0.5

      -- Set our bar color based on the percent full
      local tColors = self.db.colors[tMap.bar]
      local color   = tColors.high

      if nCurrent / nMax <= nLowBar then
        color = tColors.low
      elseif nCurrent / nMax <= nAverageBar then
        color = tColors.average
      end

      wndProgress:SetBarColor(ApolloColor.new(color))
    end
  end
end


--
-- SetDisposition
--
-- Set Disposition on UnitFrame

function VikingUnitFrames:SetDisposition(tFrame, unitTarget)
  tFrame.disposition = unitTarget:GetDispositionTo(self.tPlayerFrame.unit)
  local dispositionColor = ApolloColor.new(self.db.General.dispositionColors[tFrame.disposition])
  tFrame.wndUnitFrame:FindChild("TargetInfo:TargetName"):SetTextColor(dispositionColor)
end

--
-- SetUnit
--
-- Set Unit on UnitFrame

function VikingUnitFrames:SetUnit(tFrame, uUnit)
  tFrame.unit = uUnit
  tFrame.wndUnitFrame:FindChild("Good"):SetUnit(uUnit)
  tFrame.wndUnitFrame:FindChild("Bad"):SetUnit(uUnit)
  self:SetDisposition(tFrame, uUnit)

  -- Set the Data to the unit, for mouse events
  tFrame.wndUnitFrame:SetData(tFrame.unit)
end

--
-- SetUnitName
--
-- Set Name on UnitFrame

function VikingUnitFrames:SetUnitName(tFrame, sName)
  tFrame.wndUnitFrame:FindChild("TargetName"):SetText(sName)
end


--
-- SetUnitLevel
--
-- Set Level on UnitFrame

function VikingUnitFrames:SetUnitLevel(tFrame)
  if tFrame.unit == nil then return end
  local sLevel = tFrame.unit:GetLevel()
  tFrame.wndUnitFrame:FindChild("TargetLevel"):SetText(sLevel)
end



--
-- InitColor
--
-- Let's initialize some colors from settings

function VikingUnitFrames:InitColors(tFrame)

  local colors = {
    background = {
      wnd   = tFrame.wndUnitFrame:FindChild("Background"),
      color = ApolloColor.new(self.db.General.colors.background)
    },
    gradient = {
      wnd   = tFrame.wndUnitFrame,
      color = ApolloColor.new(self.db.General.colors.gradient)
    }
  }

  for k,v in pairs(colors) do
    v.wnd:SetBGColor(v.color)
  end
  --
end


-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

--
-- CreateCastProgress
--
-- Casts that have timers use this method to indicate their progress

function VikingUnitFrames:CreateCastProgress(tFrame, nTimeMax)

  if tFrame.bNotCasting or tFrame.bNotCasting == nil then
    tFrame.bNotCasting = false

    local wndProgressBar = tFrame.wndCastBar:FindChild("ProgressBar")
    tFrame.nTimeMax = nTimeMax
    wndProgressBar:Show(true)
    wndProgressBar:SetProgress(0)
    wndProgressBar:SetMax(nTimeMax)


    tFrame.CastTimerTick = ApolloTimer.Create(0.01, true, "OnCast" .. tFrame.name .. "FrameTimerTick", self)
    tFrame.CastTimerDone = ApolloTimer.Create(nTimeMax / 1000, false, "OnCast" .. tFrame.name .. "FrameTimerDone", self)
  end

end

function VikingUnitFrames:OnCastPlayerFrameTimerTick()
  self:UpdateCastTimer(self.tPlayerFrame)
end

function VikingUnitFrames:OnCastTargetFrameTimerTick()
  self:UpdateCastTimer(self.tTargetFrame)
end

function VikingUnitFrames:UpdateCastTimer(tFrame)
  local wndProgressBar = tFrame.wndCastBar:FindChild("ProgressBar")
  local nCurrent = tFrame.unit:GetCastElapsed()
  wndProgressBar:SetProgress(nCurrent, tFrame.nTimeMax)
end

function VikingUnitFrames:OnCastPlayerFrameTimerDone()
  self:KillTimer(self.tPlayerFrame)
end

function VikingUnitFrames:OnCastTargetFrameTimerDone()
  self:KillTimer(self.tTargetFrame)
end

function VikingUnitFrames:KillTimer(tFrame)
  Print("Done")
  local wndProgressBar = tFrame.wndCastBar:FindChild("ProgressBar")
  wndProgressBar:SetProgress(tFrame.nTimeMax)
  tFrame.CastTimerDone:Stop()
  tFrame.CastTimerTick:Stop()
  tFrame.CastTimerDone = nil
  tFrame.CastTimerTick = nil
  wndProgressBar:Show(false)
end

--
-- ShowInnateIndicator
--
--   The animated sprite shown when your Innate is active

function VikingUnitFrames:ShowInnateIndicator()
  local bInnate = GameLib.IsCurrentInnateAbilityActive()
  self.wndMain:FindChild("InnateGlow"):Show(bInnate)
end


---------------------------------------------------------------------------------------------------
-- UnitFrame Functions
---------------------------------------------------------------------------------------------------

function VikingUnitFrames:OnMouseButtonDown( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
  local unit = wndHandler:GetData()

  -- Player Menu
  if eMouseButton == GameLib.CodeEnumInputMouse.Right and unit ~= nil then
    Event_FireGenericEvent("GenericEvent_NewContextMenuPlayerDetailed", nil, unit:GetName(), unit)
  end
end

local VikingClassResourcesInst = VikingUnitFrames:new()
VikingClassResourcesInst:Init()
