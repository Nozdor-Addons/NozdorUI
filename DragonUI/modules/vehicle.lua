-- Get addon reference - either from XML parameter or global
local addon = select(2, ...);
local config = addon.config;
local class = addon._class;
local unpack = unpack;
local ipairs = ipairs;
local RegisterStateDriver = RegisterStateDriver;
local UnitVehicleSkin = UnitVehicleSkin;
local UIParent = UIParent;
local _G = getfenv(0);

-- ============================================================================
-- VEHICLE MODULE FOR NozdorUI
-- ============================================================================

-- Module state tracking
local VehicleModule = {
    initialized = false,
    applied = false,
    stateDrivers = {},       -- Track registered state drivers
    events = {},             -- Track registered events
    frames = {}              -- Track created frames
}

-- Frame variables (only created when enabled)
local pUiMainBar = nil;
local vehicleType = nil;
local vehicleBarBackground = nil;
local vehiclebar = nil;
local vehicleExit = nil;
local vehicleLeave = nil;

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.vehicle
end

local function IsModuleEnabled()
    local cfg = GetModuleConfig()
    return cfg and cfg.enabled
end

local function IsMainbarsModuleEnabled()
    local cfg = addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.mainbars
    return cfg and cfg.enabled
end

local function CheckDependencies()
    -- Vehicle leave button can work independently, but other vehicle features need mainbars
    -- Always return true to allow vehicle leave button to be created
    return true
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

local function CreateVehicleFrames()
    if VehicleModule.frames.created then return true end
    
    -- Get mainbar reference (optional for vehicle leave button)
    pUiMainBar = addon.pUiMainBar or _G.pUiMainBar
    
    -- Always create vehicleLeave button, even if pUiMainBar doesn't exist
    vehicleLeave = CreateFrame(
        'CheckButton',
        'NozdorUI_VehicleLeaveButton',
        UIParent,
        'SecureHandlerClickTemplate'
    )
    vehicleLeave:Hide()
    
    -- Only create other frames if pUiMainBar exists
    if pUiMainBar then
    vehicleType = UnitVehicleSkin('player')
    
    vehicleBarBackground = CreateFrame(
        'Frame',
        'NozdorUI_VehicleBarBackground',
        UIParent,
        'VehicleBarUiTemplate'
    )
    
    vehiclebar = CreateFrame(
        'Frame',
        'NozdorUI_VehicleBar',
        vehicleBarBackground,
        'SecureHandlerStateTemplate'
    )
    
    vehicleExit = CreateFrame(
        'CheckButton',
        'NozdorUI_VehicleExit',
        UIParent,
        'SecureHandlerClickTemplate,SecureHandlerStateTemplate'
    )
    
    -- Set initial properties
    vehicleBarBackground:SetScale(config.mainbars.scale_vehicle)
    vehiclebar:ClearAllPoints()
    vehiclebar:SetAllPoints(vehicleBarBackground)
    
    -- Hide frames by default
    vehicleBarBackground:Hide()
    vehiclebar:Hide()
    vehicleExit:Hide()
    end
    
    -- Store frames for cleanup
    VehicleModule.frames = {
        created = true,
        vehicleBarBackground = vehicleBarBackground,
        vehiclebar = vehiclebar,
        vehicleExit = vehicleExit,
        vehicleLeave = vehicleLeave
    }
    
    return true
end

local function CleanupVehicleFrames()
    -- Clean up global frames that might conflict
    local globalFrames = {
        'mixin2template',
        'pUiVehicleBar',
        'vehicleExit',
        'pUiVehicleLeaveButton'
    }
    
    for _, frameName in ipairs(globalFrames) do
        local frame = _G[frameName]
        if frame and frame.Hide then
            frame:Hide()
            frame:SetParent(nil)
            if frame.UnregisterAllEvents then
                frame:UnregisterAllEvents()
            end
            _G[frameName] = nil
        end
    end
end

-- ============================================================================
-- VEHICLE SETUP FUNCTIONS
-- ============================================================================

local function vehiclebar_power_setup()
    if not vehiclebar then return end
    
    VehicleMenuBarLeaveButton:SetParent(vehiclebar)
    VehicleMenuBarLeaveButton:SetSize(47, 50)
    VehicleMenuBarLeaveButton:SetClearPoint('BOTTOMRIGHT', -178, 14)
    VehicleMenuBarLeaveButton:SetHighlightTexture('Interface\\Vehicles\\UI-Vehicles-Button-Highlight')
    VehicleMenuBarLeaveButton:GetHighlightTexture():SetTexCoord(0.130625, 0.879375, 0.130625, 0.879375)
    VehicleMenuBarLeaveButton:GetHighlightTexture():SetBlendMode('ADD')
    VehicleMenuBarLeaveButton:SetScript('OnClick', VehicleExit)

    VehicleMenuBarHealthBar:SetParent(vehiclebar)
    VehicleMenuBarHealthBarOverlay:SetParent(VehicleMenuBarHealthBar)
    VehicleMenuBarHealthBarOverlay:SetSize(46, 105)
    VehicleMenuBarHealthBarOverlay:SetClearPoint('BOTTOMLEFT', -5, -9)
    VehicleMenuBarHealthBarBackground:SetParent(VehicleMenuBarHealthBar)
    VehicleMenuBarHealthBarBackground:SetTexture([[Interface\Tooltips\UI-Tooltip-Background]])
    VehicleMenuBarHealthBarBackground:SetTexCoord(0.0, 1.0, 0.0, 1.0)
    VehicleMenuBarHealthBarBackground:SetVertexColor(
        TOOLTIP_DEFAULT_BACKGROUND_COLOR.r,
        TOOLTIP_DEFAULT_BACKGROUND_COLOR.g,
        TOOLTIP_DEFAULT_BACKGROUND_COLOR.b
    )

    VehicleMenuBarPowerBar:SetParent(vehiclebar)
    VehicleMenuBarPowerBarOverlay:SetParent(VehicleMenuBarPowerBar)
    VehicleMenuBarPowerBarOverlay:SetSize(46, 105)
    VehicleMenuBarPowerBarOverlay:SetClearPoint('BOTTOMLEFT', -5, -9)
    VehicleMenuBarPowerBarBackground:SetParent(VehicleMenuBarPowerBar)
    VehicleMenuBarPowerBarBackground:SetTexture([[Interface\Tooltips\UI-Tooltip-Background]])
    VehicleMenuBarPowerBarBackground:SetTexCoord(0.5390625, 0.953125, 0.0, 1.0)
    VehicleMenuBarPowerBarBackground:SetVertexColor(
        TOOLTIP_DEFAULT_BACKGROUND_COLOR.r,
        TOOLTIP_DEFAULT_BACKGROUND_COLOR.g,
        TOOLTIP_DEFAULT_BACKGROUND_COLOR.b
    )
end

local function vehiclebar_mechanical_setup()
    if not vehicleBarBackground then return end
    
    vehicleBarBackground.OrganicUi:Hide()
    vehicleBarBackground.MechanicUi:Show()
    
    VehicleMenuBarLeaveButton:SetNormalTexture(addon._dir..'mechanical2')
    VehicleMenuBarLeaveButton:GetNormalTexture():SetTexCoord(45/512, 84/512, 185/512, 224/512)
    VehicleMenuBarLeaveButton:SetPushedTexture(addon._dir..'mechanical2')
    VehicleMenuBarLeaveButton:GetPushedTexture():SetTexCoord(2/512, 40/512, 185/512, 223/512)
    
    VehicleMenuBarHealthBar:SetSize(38, 84)
    VehicleMenuBarPowerBar:SetSize(38, 84)
    VehicleMenuBarPowerBar:SetClearPoint('BOTTOMRIGHT', -94, 6)
    VehicleMenuBarHealthBar:SetClearPoint('BOTTOMLEFT', 74, 6)
    VehicleMenuBarHealthBarBackground:SetSize(40, 92)
    VehicleMenuBarPowerBarBackground:SetSize(40, 92)
    VehicleMenuBarHealthBarBackground:SetClearPoint('BOTTOMLEFT', -2, -6)
    VehicleMenuBarPowerBarBackground:SetClearPoint('BOTTOMLEFT', -2, -6)
    VehicleMenuBarHealthBarOverlay:SetTexture(addon._dir..'mechanical2')
    VehicleMenuBarHealthBarOverlay:SetTexCoord(4/512, 44/512, 263/512, 354/512)
    VehicleMenuBarPowerBarOverlay:SetTexture(addon._dir..'mechanical2')
    VehicleMenuBarPowerBarOverlay:SetTexCoord(4/512, 44/512, 263/512, 354/512)
    
    VehicleMenuBarPitchUpButton:SetParent(vehicleBarBackground.MechanicUi)
    VehicleMenuBarPitchUpButton:SetSize(32, 31)
    VehicleMenuBarPitchUpButton:SetClearPoint('BOTTOMLEFT', 156, 46)
    VehicleMenuBarPitchUpButton:SetNormalTexture(addon._dir..'mechanical2')
    VehicleMenuBarPitchUpButton:SetPushedTexture(addon._dir..'mechanical2')
    VehicleMenuBarPitchUpButton:GetNormalTexture():SetTexCoord(1/512, 34/512, 227/512, 259/512)
    VehicleMenuBarPitchUpButton:GetPushedTexture():SetTexCoord(36/512, 69/512, 227/512, 259/512)

    VehicleMenuBarPitchDownButton:SetParent(vehicleBarBackground.MechanicUi)
    VehicleMenuBarPitchDownButton:SetSize(32, 31)
    VehicleMenuBarPitchDownButton:SetClearPoint('BOTTOMLEFT', 156, 8)
    VehicleMenuBarPitchDownButton:SetNormalTexture(addon._dir..'mechanical2')
    VehicleMenuBarPitchDownButton:SetPushedTexture(addon._dir..'mechanical2')
    VehicleMenuBarPitchDownButton:GetNormalTexture():SetTexCoord(148/512, 180/512, 289/512, 320/512)
    VehicleMenuBarPitchDownButton:GetPushedTexture():SetTexCoord(148/512, 180/512, 323/512, 354/512)

    VehicleMenuBarPitchSlider:SetParent(vehicleBarBackground.MechanicUi)
    VehicleMenuBarPitchSlider:SetSize(20, 82)
    VehicleMenuBarPitchSlider:SetClearPoint('BOTTOMLEFT', 124, 2)
    
    local bg1 = _G['NozdorUI_VehicleBarBackgroundBACKGROUND1']
    if bg1 then
        bg1:SetDrawLayer('BACKGROUND', -1)
    end
    
    VehicleMenuBarPitchSliderBG:SetTexture([[Interface\Vehicles\UI-Vehicles-Endcap]])
    VehicleMenuBarPitchSliderBG:SetTexCoord(0.46875, 0.50390625, 0.31640625, 0.62109375)
    VehicleMenuBarPitchSliderBG:SetVertexColor(0, 0.85, 0.99)

    VehicleMenuBarPitchSliderMarker:SetWidth(20)
    VehicleMenuBarPitchSliderMarker:SetTexture([[Interface\Vehicles\UI-Vehicles-Endcap]])
    VehicleMenuBarPitchSliderMarker:SetTexCoord(0.46875, 0.50390625, 0.45, 0.55)
    VehicleMenuBarPitchSliderMarker:SetVertexColor(1, 0, 0)
    
    VehicleMenuBarPitchSliderOverlayThing:SetPoint('TOPLEFT', -5, 2)
    VehicleMenuBarPitchSliderOverlayThing:SetPoint('BOTTOMRIGHT', 3, -4)
end

local function vehiclebar_organic_setup()
    if not vehicleBarBackground then return end
    
    vehicleBarBackground.OrganicUi:Show()
    vehicleBarBackground.MechanicUi:Hide()
    VehicleMenuBarHealthBar:SetSize(38, 74)
    VehicleMenuBarPowerBar:SetSize(38, 74)
    VehicleMenuBarPowerBar:SetClearPoint('BOTTOMRIGHT', -119, 3)
    VehicleMenuBarHealthBar:SetClearPoint('BOTTOMLEFT', 119, 3)
    VehicleMenuBarHealthBarBackground:SetSize(40, 83)
    VehicleMenuBarPowerBarBackground:SetSize(40, 83)
    VehicleMenuBarHealthBarBackground:SetClearPoint('BOTTOMLEFT', -2, -9)
    VehicleMenuBarPowerBarBackground:SetClearPoint('BOTTOMLEFT', -2, -9)
    VehicleMenuBarLeaveButton:SetNormalTexture('Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up')
    VehicleMenuBarLeaveButton:GetNormalTexture():SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    VehicleMenuBarLeaveButton:SetPushedTexture('Interface\\Vehicles\\UI-Vehicles-Button-Exit-Down')
    VehicleMenuBarLeaveButton:GetPushedTexture():SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    VehicleMenuBarHealthBarOverlay:SetTexture([[Interface\Vehicles\UI-Vehicles-Endcap-Organic-bottle]])
    VehicleMenuBarHealthBarOverlay:SetTexCoord(0.46484375, 0.66015625, 0.0390625, 0.9375)
    VehicleMenuBarPowerBarOverlay:SetTexture([[Interface\Vehicles\UI-Vehicles-Endcap-Organic-bottle]])
    VehicleMenuBarPowerBarOverlay:SetTexCoord(0.46484375, 0.66015625, 0.0390625, 0.9375)
end

local function vehiclebar_layout_setup()
    if IsVehicleAimAngleAdjustable() then
        vehiclebar_mechanical_setup()
    else
        vehiclebar_organic_setup()
    end
end

local function vehiclebutton_position()
    if not vehiclebar then return end
    
    local button
    if vehiclebar:IsShown() or (vehicleBarBackground and vehicleBarBackground:IsShown()) then
        for index=1, VEHICLE_MAX_ACTIONBUTTONS do
            button = _G['VehicleMenuBarActionButton'..index]
            if button then
                button:ClearAllPoints()
                button:SetParent(vehiclebar)
                button:SetSize(52, 52)
                button:Show()
                if index == 1 then
                    button:SetPoint('BOTTOMLEFT', vehiclebar, 'BOTTOMRIGHT', -594, 21)
                else
                    local previous = _G['VehicleMenuBarActionButton'..(index-1)]
                    if previous then
                        button:SetPoint('LEFT', previous, 'RIGHT', 6, 0)
                    end
                end
            end
        end
    end
end

local function vehiclebutton_state(self)
    if not self then return end
    
    local button
    for index=1, VEHICLE_MAX_ACTIONBUTTONS do
        button = _G['VehicleMenuBarActionButton'..index]
        if button then
            self:SetFrameRef('VehicleMenuBarActionButton'..index, button)
        end
    end	
    self:SetAttribute('_onstate-vehicleupdate', [[
        if newstate == 's1' then
            self:GetParent():Show()
        else
            self:GetParent():Hide()
        end
    ]])
    
    VehicleModule.stateDrivers.vehiclebarUpdate = {frame = self, state = 'vehicleupdate'}
    RegisterStateDriver(self, 'vehicleupdate', '[vehicleui] s1; s2')
end

-- ============================================================================
-- VEHICLE LEAVE BUTTON SETUP
-- ============================================================================

local function SetupVehicleLeaveButton()
    if not vehicleLeave then return end
    
    -- Create editor frame for editing (like stance bar)
    local btnSize = config.additional.size or 40
    if not VehicleModule.frames.vehicleLeaveFrame then
        local vehicleLeaveFrame = addon.CreateUIFrame(btnSize, btnSize, "vehicleleave")
        VehicleModule.frames.vehicleLeaveFrame = vehicleLeaveFrame
        
        -- Create anchor frame inside editor frame
        local anchor = CreateFrame('Frame', 'NozdorUI_VehicleLeaveAnchor', vehicleLeaveFrame)
        anchor:SetAllPoints(vehicleLeaveFrame)
        anchor:SetSize(btnSize, btnSize)
        anchor:SetFrameStrata("MEDIUM")
        anchor:SetFrameLevel(1)
        VehicleModule.frames.vehicleLeaveAnchor = anchor
        
        -- Parent button to anchor
        vehicleLeave:SetParent(anchor)
        vehicleLeave:SetAllPoints(anchor)
    end
    
    local vehicleLeaveFrame = VehicleModule.frames.vehicleLeaveFrame
    local anchor = VehicleModule.frames.vehicleLeaveAnchor
    
    -- Set button size
    vehicleLeave:SetSize(btnSize, btnSize)
    vehicleLeaveFrame:SetSize(btnSize, btnSize)
    if anchor then
        anchor:SetSize(btnSize, btnSize)
    end
    
    -- Set FrameStrata and FrameLevel to ensure button is above all panels
    vehicleLeave:SetFrameStrata("HIGH")
    vehicleLeave:SetFrameLevel(200)
    
    -- Load position from database or use default
    local widgetConfig = addon.db.profile.widgets and addon.db.profile.widgets.vehicleleave
    
    -- Calculate default position: left of main bar (300px to the left)
    local mainBarConfig = addon.db.profile.widgets and addon.db.profile.widgets.mainbar
    local defaultPosX = -300
    local defaultPosY = 22
    local defaultAnchor = "BOTTOM"
    
    if mainBarConfig then
        defaultPosX = (mainBarConfig.posX or 0) - 300
        defaultPosY = mainBarConfig.posY or 22
        defaultAnchor = mainBarConfig.anchor or "BOTTOM"
    end
    
    -- Always apply default position (user can move it manually in editor mode)
    -- This ensures the button is always positioned correctly on first load
    if not widgetConfig or widgetConfig.posX == -100 or widgetConfig.posX == -150 or (widgetConfig.posX and widgetConfig.posX > -200) then
        -- Update to new default position if using old default or no config
        if not addon.db.profile.widgets then
            addon.db.profile.widgets = {}
        end
        addon.db.profile.widgets.vehicleleave = {
            anchor = defaultAnchor,
            posX = defaultPosX,
            posY = defaultPosY
        }
        widgetConfig = addon.db.profile.widgets.vehicleleave
    end
    
    -- Apply position
    vehicleLeaveFrame:ClearAllPoints()
    vehicleLeaveFrame:SetPoint(widgetConfig.anchor or defaultAnchor, UIParent, widgetConfig.anchor or defaultAnchor, widgetConfig.posX or defaultPosX, widgetConfig.posY or defaultPosY)
    
    -- Set button textures
    vehicleLeave:SetNormalTexture('Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up')
    vehicleLeave:GetNormalTexture():SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    vehicleLeave:SetPushedTexture('Interface\\Vehicles\\UI-Vehicles-Button-Exit-Down')
    vehicleLeave:GetPushedTexture():SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    vehicleLeave:SetHighlightTexture('Interface\\Vehicles\\UI-Vehicles-Button-Highlight')
    vehicleLeave:GetHighlightTexture():SetTexCoord(0.130625, 0.879375, 0.130625, 0.879375)
    vehicleLeave:GetHighlightTexture():SetBlendMode('ADD')
    vehicleLeave:RegisterForClicks('AnyUp')
    
    -- Set button scripts
    vehicleLeave:SetScript('OnEnter', function(self)
        GameTooltip_AddNewbieTip(self, LEAVE_VEHICLE, 1.0, 1.0, 1.0, nil)
    end)
    vehicleLeave:SetScript('OnLeave', GameTooltip_Hide)
    vehicleLeave:SetScript('OnClick', function(self)
        VehicleExit()
        self:SetChecked(true)
    end)
    vehicleLeave:SetScript('OnShow', function(self)
        self:SetChecked(false)
    end)
    
    -- Hide button by default
    vehicleLeave:Hide()
    
    -- Use periodic check instead of StateDriver - more reliable
    local checkFrame = CreateFrame("Frame")
    local checkTimer = 0
    checkFrame:SetScript("OnUpdate", function(self, elapsed)
        checkTimer = checkTimer + elapsed
        if checkTimer >= 0.1 then -- Check every 0.1 seconds
            checkTimer = 0
                if vehicleLeave then
                local hasVehicleUI = UnitHasVehicleUI("player")
                local inVehicle = UnitInVehicle("player")
                local hasVehicleActionBar = HasVehicleActionBar and HasVehicleActionBar()
                
                -- Show button if any vehicle indicator is true
                if hasVehicleUI or inVehicle or hasVehicleActionBar then
                    if not vehicleLeave:IsShown() then
                        vehicleLeave:Show()
                    end
                    else
                    if vehicleLeave:IsShown() then
                        vehicleLeave:Hide()
                    end
                end
            end
        end
    end)
    
    -- Register as editable frame (register the editor frame, not the button)
    if addon.RegisterEditableFrame and vehicleLeaveFrame then
        addon:RegisterEditableFrame({
            name = "vehicleleave",
            frame = vehicleLeaveFrame,
            blizzardFrame = vehicleLeave,  -- The actual button
            configPath = {"widgets", "vehicleleave"},
            module = VehicleModule
        })
    end
end

local function SetupVehicleExitButton()
    if not vehicleExit or not pUiMainBar then return end
    
    -- Keep button independent from panels - parent to UIParent for proper layering
    vehicleExit:SetParent(UIParent)
    
    -- Set FrameStrata and FrameLevel to ensure button is above all panels
    vehicleExit:SetFrameStrata("HIGH")
    vehicleExit:SetFrameLevel(200) -- Very high level to be above everything
    
    -- Position relative to stance bar or main bar, but don't parent to them
    local stanceBar = addon.pUiStanceBar or _G.pUiStanceBar
    local referenceFrame = stanceBar or pUiMainBar
    
    if referenceFrame then
        vehicleExit:SetSize(config.additional.size, config.additional.size)
        -- Position button to the left of the reference frame to avoid overlapping with abilities
        local xOffset = config.additional.vehicle.x_position or -50 -- Default: 50px to the left
        vehicleExit:ClearAllPoints()
        vehicleExit:SetPoint('TOPRIGHT', referenceFrame, 'TOPLEFT', xOffset, 0)
    else
        vehicleExit:SetSize(config.additional.size, config.additional.size)
        local xOffset = config.additional.vehicle.x_position or -50
        vehicleExit:SetPoint('TOPRIGHT', pUiMainBar, 'TOPLEFT', xOffset, 0)
    end
    vehicleExit:SetNormalTexture('Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up')
    vehicleExit:GetNormalTexture():SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    vehicleExit:SetPushedTexture('Interface\\Vehicles\\UI-Vehicles-Button-Exit-Down')
    vehicleExit:GetPushedTexture():SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    vehicleExit:SetHighlightTexture('Interface\\Vehicles\\UI-Vehicles-Button-Highlight')
    vehicleExit:GetHighlightTexture():SetTexCoord(0.130625, 0.879375, 0.130625, 0.879375)
    vehicleExit:GetHighlightTexture():SetBlendMode('ADD')
    vehicleExit:RegisterForClicks('AnyUp')
    vehicleExit:SetScript('OnEnter', function(self)
        GameTooltip_AddNewbieTip(self, LEAVE_VEHICLE, 1.0, 1.0, 1.0, nil)
    end)
    vehicleExit:SetScript('OnLeave', GameTooltip_Hide)
    vehicleExit:SetScript('OnClick', function(self)
        VehicleExit()
        self:SetChecked(true)
    end)
    vehicleExit:SetScript('OnShow', function(self)
        self:SetChecked(false)
    end)
    
    -- Hide button by default
    vehicleExit:Hide()
    
    -- Hook into vehicle events to update button visibility
    local vehicleExitEventFrame = CreateFrame("Frame")
    vehicleExitEventFrame:RegisterEvent("UNIT_ENTERING_VEHICLE")
    vehicleExitEventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
    vehicleExitEventFrame:RegisterEvent("UNIT_EXITING_VEHICLE")
    vehicleExitEventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
    vehicleExitEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    vehicleExitEventFrame:SetScript("OnEvent", function(self, event, unit)
        if unit == "player" or not unit then
            -- Small delay to ensure CanExitVehicle returns correct value
            C_Timer.After(0.1, function()
                if vehicleExit then
                    if CanExitVehicle() then
                        vehicleExit:Show()
                    else
                        vehicleExit:Hide()
                    end
                end
            end)
        end
    end)
    
    -- Use StateDriver with vehicleui condition - more reliable
    VehicleModule.stateDrivers.vehicleExitVisibility = {frame = vehicleExit, state = 'visibility'}
    RegisterStateDriver(vehicleExit, 'visibility', '[vehicleui] show; hide')
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local function OnEvent(self, event, ...)
    if event == 'PLAYER_LOGIN' then
        vehiclebutton_state(self)
    elseif event == 'PLAYER_ENTERING_WORLD' then
        vehiclebutton_position()
    elseif event == 'UNIT_ENTERED_VEHICLE' then
        vehiclebar_layout_setup()
        if addon.vehiclebuttons_template then
            addon.vehiclebuttons_template()
        end
        UnitFrameHealthBar_Update(VehicleMenuBarHealthBar, 'vehicle')
        UnitFrameManaBar_Update(VehicleMenuBarPowerBar, 'vehicle')
        -- Update vehicle leave/exit buttons visibility
        -- StateDriver should handle this, but ensure button is visible if vehicle UI is active
        C_Timer.After(0.1, function()
            if vehicleLeave then
                local hasVehicleUI = UnitHasVehicleUI("player")
                if hasVehicleUI then
                    -- Force show if vehicle UI is active (StateDriver should handle this, but ensure it)
                    vehicleLeave:Show()
                end
            end
            if vehicleExit then
                if CanExitVehicle() then
                    vehicleExit:Show()
                else
                    vehicleExit:Hide()
                end
            end
        end)
    elseif event == 'UNIT_DISPLAYPOWER' then
        UnitFrameManaBar_Update(VehicleMenuBarPowerBar, 'vehicle')
        vehiclebutton_position()
    elseif event == 'UNIT_EXITED_VEHICLE' then
        -- Hide vehicle leave/exit buttons when exiting vehicle
        if vehicleLeave then
            vehicleLeave:Hide()
        end
        if vehicleExit then
            vehicleExit:Hide()
        end
    elseif event == 'UNIT_EXITING_VEHICLE' then
        -- StateDriver will handle vehicleLeave visibility automatically
        -- Just ensure vehicleExit is updated
        if vehicleExit then
            if CanExitVehicle() then
                vehicleExit:Show()
            else
                vehicleExit:Hide()
            end
        end
    end
end

-- ============================================================================
-- STANCE/BONUS BAR HANDLING
-- ============================================================================

local stance = {
    ['DRUID'] = '[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10;',
    ['WARRIOR'] = '[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9;',
    ['PRIEST'] = '[bonusbar:1] 7;',
    ['ROGUE'] = '[bonusbar:1] 7; [form:3] 7;',
    ['DEFAULT'] = '[bonusbar:5] 11; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6;',
}

local function getbarpage()
    local condition = stance['DEFAULT']
    local page = stance[class]
    if page then
        condition = condition..' '..page
    end
    condition = condition..' 1'
    return condition
end

local function SetupBonusBarVehicle()
    if not pUiMainBar or not vehicleExit then return end
    
    -- вњ… Pasar TODAS las referencias al entorno seguro primero
    pUiMainBar:SetFrameRef('vehicleExit', vehicleExit)
    
    -- вњ… Obtener referencias a los ActionButtons tambiГ©n
    for i = 1, 12 do
        local actionButton = _G['ActionButton'..i]
        if actionButton then
            pUiMainBar:SetFrameRef('ActionButton'..i, actionButton)
        end
    end
    
    pUiMainBar:Execute([[
        vehicleExit = self:GetFrameRef('vehicleExit')
        buttons = newtable()
        for i = 1, 12 do
            local button = self:GetFrameRef('ActionButton'..i)
            if button then
                table.insert(buttons, button)
            end
        end
    ]])
    
    pUiMainBar:SetAttribute('_onstate-page', [[
        for i, button in ipairs(buttons) do
            button:SetAttribute('actionpage', tonumber(newstate))
        end
    ]])
    
    VehicleModule.stateDrivers.bonusBarPage = {frame = pUiMainBar, state = 'page'}
    RegisterStateDriver(pUiMainBar, 'page', getbarpage())
end

-- ============================================================================
-- APPLY/RESTORE FUNCTIONS
-- ============================================================================
local function SetupVehicleExitStateDriver()
    if not pUiMainBar or not vehicleExit then return end
    
    -- Use vehicleui condition instead of canexitvehicle (which is not a valid macro parameter)
    -- The event handler in SetupVehicleExitButton will handle visibility
    -- This state driver is kept for compatibility but may not be needed
    VehicleModule.stateDrivers.vehicleExitBar = {frame = pUiMainBar, state = 'vehicle'}
    RegisterStateDriver(pUiMainBar, 'vehicle', '[vehicleui] 1; 0')
end
local function ApplyVehicleSystem()
    if VehicleModule.applied or not IsModuleEnabled() then return end
    
    -- Cleanup any existing frames first
    CleanupVehicleFrames()
    
    -- Create frames (always succeeds now, even without pUiMainBar)
    CreateVehicleFrames()
    
    -- Always setup vehicle leave button first
    SetupVehicleLeaveButton()
    
    -- Setup based on art style (only if pUiMainBar exists)
    if config.additional.vehicle.artstyle and pUiMainBar and vehiclebar then
        -- Register events
        local events = {
            'UNIT_ENTERING_VEHICLE',
            'UNIT_EXITED_VEHICLE',
            'UNIT_EXITING_VEHICLE',
            'UNIT_ENTERED_VEHICLE',
            'UNIT_DISPLAYPOWER',
            'PLAYER_LOGIN',
            'PLAYER_ENTERING_WORLD'
        }
        
        for _, event in ipairs(events) do
            vehiclebar:RegisterEvent(event)
            VehicleModule.events[event] = vehiclebar
        end
        
        vehiclebar:SetScript('OnEvent', OnEvent)
        vehiclebar_power_setup()
        
        -- Setup main bar state driver
        VehicleModule.stateDrivers.mainBarVehicle = {frame = pUiMainBar, state = 'vehicleupdate'}
        pUiMainBar:SetAttribute('_onstate-vehicleupdate', [[
            if newstate == '1' then
                self:Hide()
            else
                self:Show()
            end
        ]])
        RegisterStateDriver(pUiMainBar, 'vehicleupdate', '[vehicleui] 1; 2')
    else
        -- Hide art style vehicle bar
        if vehicleBarBackground then
            vehicleBarBackground:Hide()
        end
        if pUiMainBar then
        SetupVehicleExitButton()
        
        -- вњ… FIX: Configurar correctamente el state driver
        SetupVehicleExitStateDriver()
        end
    end
    
    -- Vehicle leave button is already set up above
    if pUiMainBar then
    SetupBonusBarVehicle()
    end
    
    -- StateDriver will handle vehicleLeave visibility automatically
    -- Just ensure vehicleExit is hidden if not in vehicle
    C_Timer.After(0.5, function()
        if vehicleExit then
            if not CanExitVehicle() then
                vehicleExit:Hide()
            end
        end
    end)
    
    VehicleModule.applied = true
end

local function RestoreVehicleSystem()
    if not VehicleModule.applied then return end
    
    -- Unregister all events
    for event, frame in pairs(VehicleModule.events) do
        if frame and frame.UnregisterEvent then
            frame:UnregisterEvent(event)
        end
    end
    VehicleModule.events = {}
    
    -- Unregister all state drivers  
    for name, data in pairs(VehicleModule.stateDrivers) do
        if data.frame and UnregisterStateDriver then
            UnregisterStateDriver(data.frame, data.state)
        end
    end
    VehicleModule.stateDrivers = {}
    
    -- Hide and cleanup custom frames (skip boolean values)
    for name, frame in pairs(VehicleModule.frames) do
        if name ~= "created" and frame and type(frame) == "table" and frame.Hide then
            frame:Hide()
            frame:SetParent(nil)
        end
    end
    
    -- Cleanup global frames
    CleanupVehicleFrames()
    
    -- Restore default vehicle UI
    if VehicleMenuBar then
        VehicleMenuBar:Show()
    end
    
    -- Reset variables
    VehicleModule.frames = {}
    vehicleBarBackground = nil
    vehiclebar = nil
    vehicleExit = nil
    vehicleLeave = nil
    pUiMainBar = nil
    
    VehicleModule.applied = false
    
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function addon.RefreshVehicleSystem()
    if IsModuleEnabled() then
        if not VehicleModule.applied then
            ApplyVehicleSystem()
        else
            -- If already applied, just refresh settings
            if addon.RefreshVehicle then
                addon.RefreshVehicle()
            end
        end
    else
        RestoreVehicleSystem()
    end
end

function addon.RefreshVehicle()
    if not IsModuleEnabled() or not VehicleModule.applied then return end
    
    local btnsize = config.additional.size
    local barstyle = config.additional.vehicle.artstyle
    local x_position = config.additional.vehicle.x_position
    
    -- Update vehicle leave button if it exists
    if vehicleLeave and VehicleModule.frames.vehicleLeaveFrame then
        local vehicleLeaveFrame = VehicleModule.frames.vehicleLeaveFrame
        local anchor = VehicleModule.frames.vehicleLeaveAnchor
        
        vehicleLeave:SetSize(btnsize, btnsize)
        vehicleLeaveFrame:SetSize(btnsize, btnsize)
        if anchor then
            anchor:SetSize(btnsize, btnsize)
        end
        
        -- Ensure button stays above panels
        vehicleLeave:SetFrameStrata("HIGH")
        vehicleLeave:SetFrameLevel(200)
        
        -- Load position from database
        local widgetConfig = addon.db.profile.widgets and addon.db.profile.widgets.vehicleleave
        
        -- Calculate default position: left of main bar (300px to the left)
        local mainBarConfig = addon.db.profile.widgets and addon.db.profile.widgets.mainbar
        local defaultPosX = -300
        local defaultPosY = 22
        local defaultAnchor = "BOTTOM"
        
        if mainBarConfig then
            defaultPosX = (mainBarConfig.posX or 0) - 300
            defaultPosY = mainBarConfig.posY or 22
            defaultAnchor = mainBarConfig.anchor or "BOTTOM"
        end
        
        if widgetConfig then
            -- If using old default (-100 or -150), update to new default (-300)
            if widgetConfig.posX == -100 or widgetConfig.posX == -150 then
                widgetConfig.posX = defaultPosX
            end
            vehicleLeaveFrame:ClearAllPoints()
            vehicleLeaveFrame:SetPoint(widgetConfig.anchor or defaultAnchor, UIParent, widgetConfig.anchor or defaultAnchor, widgetConfig.posX or defaultPosX, widgetConfig.posY or defaultPosY)
        else
            -- Use default position
            vehicleLeaveFrame:ClearAllPoints()
            vehicleLeaveFrame:SetPoint(defaultAnchor, UIParent, defaultAnchor, defaultPosX, defaultPosY)
        end
    end
    
    -- Update vehicle exit button if it exists
    if vehicleExit then
        vehicleExit:SetSize(btnsize, btnsize)
        -- Ensure button stays independent and above panels
        vehicleExit:SetParent(UIParent)
        vehicleExit:SetFrameStrata("HIGH")
        vehicleExit:SetFrameLevel(200)
        
        -- Position relative to reference frame (to the left to avoid overlapping)
        local stanceBar = addon.pUiStanceBar or _G.pUiStanceBar
        local referenceFrame = stanceBar or pUiMainBar
        if referenceFrame then
            vehicleExit:ClearAllPoints()
            -- Use x_position as offset from left edge (negative = more to the left)
            local xOffset = x_position or -50
            vehicleExit:SetPoint('TOPRIGHT', referenceFrame, 'TOPLEFT', xOffset, 0)
        end
    end
    
    -- Update vehicle bar background scale
    if vehicleBarBackground then
        vehicleBarBackground:SetScale(config.mainbars.scale_vehicle)
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function WaitForDependencies(callback, attempts)
    attempts = attempts or 0
    
    if attempts > 20 then -- Give up after 10 seconds
        
        return
    end
    
    if CheckDependencies() then
        callback()
    else
        addon.core:ScheduleTimer(function()
            WaitForDependencies(callback, attempts + 1)
        end, 0.5)
    end
end

-- Auto-initialize when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "NozdorUI" then
        VehicleModule.initialized = true
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- Wait for dependencies and apply if enabled
        if IsModuleEnabled() then
            WaitForDependencies(function()
                ApplyVehicleSystem()
            end)
        end
        
        -- Profile callbacks removed - using AceDB
        -- Changes are automatically saved via AceDB
        
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
