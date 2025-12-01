-- Get addon reference - either from XML parameter or global
local addon = select(2, ...);
local class = addon._class;
local noop = addon._noop;
local InCombatLockdown = InCombatLockdown;
local UnitAffectingCombat = UnitAffectingCombat;
local hooksecurefunc = hooksecurefunc;
local UIParent = UIParent;
local NUM_POSSESS_SLOTS = NUM_POSSESS_SLOTS or 10;

-- ============================================================================
-- MULTICAST MODULE FOR NOZDORUI
-- ============================================================================

-- Module state tracking
local MulticastModule = {
    initialized = false,
    applied = false,
    originalStates = {},     -- Store original states for restoration
    registeredEvents = {},   -- Track registered events
    hooks = {},             -- Track hooked functions
    stateDrivers = {},      -- Track state drivers
    frames = {}             -- Track created frames
}

-- Note: Totem bar logic has been moved to stance.lua module

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.multicast
end

local function IsModuleEnabled()
    local cfg = GetModuleConfig()
    return cfg and cfg.enabled
end

-- =============================================================================
-- OPTIMIZED TIMER HELPER (with timer pool for better memory management)
-- =============================================================================
local timerPool = {}
local function DelayedCall(delay, func)
    local timer = table.remove(timerPool) or CreateFrame("Frame")
    timer.elapsed = 0
    timer:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            table.insert(timerPool, self) -- Recycle timer for reuse
            func()
        end
    end)
end

-- =============================================================================
-- CONFIG HELPER FUNCTIONS
-- =============================================================================
local function GetTotemConfig()
    if not (addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional.totem) then
        return 0, 0
    end
    local totemConfig = addon.db.profile.additional.totem
    return totemConfig.x_position or 0, totemConfig.y_offset or 0
end

local function GetAdditionalConfig()
    return addon:GetConfigValue("additional") or {}
end

-- =============================================================================
-- ANCHOR FRAME: Handles positioning for both Totem and Possess bars
-- =============================================================================
local anchor = CreateFrame('Frame', 'NozdorUI_MulticastAnchor', UIParent)
anchor:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, 52)
anchor:SetSize(37, 37)

-- Track created frames
MulticastModule.frames.anchor = anchor

-- =============================================================================
-- SMART POSITIONING FUNCTION
-- =============================================================================
function anchor:update_position()
    if not IsModuleEnabled() then return end

    if InCombatLockdown() or UnitAffectingCombat('player') then return end

    local offsetX, offsetY = GetTotemConfig()
    self:ClearAllPoints()

    -- Check if pretty_actionbar addon is loaded for special positioning logic
    if IsAddOnLoaded('pretty_actionbar') and _G.pUiMainBar then
        local leftbar = MultiBarBottomLeft and MultiBarBottomLeft:IsShown()
        local rightbar = MultiBarBottomRight and MultiBarBottomRight:IsShown()

        -- Get additional config for pretty_actionbar compatibility
        local nobar = 52
        local leftbarOffset = 90
        local rightbarOffset = 40

        -- Read values from database if available
        if addon.db and addon.db.profile and addon.db.profile.additional then
            local additionalConfig = addon.db.profile.additional
            leftbarOffset = additionalConfig.leftbar_offset or 90
            rightbarOffset = additionalConfig.rightbar_offset or 40
        end

        local yPosition = nobar

        if leftbar and rightbar then
            yPosition = nobar + leftbarOffset
        elseif leftbar then
            yPosition = nobar + rightbarOffset
        elseif rightbar then
            yPosition = nobar + leftbarOffset
        end

        self:SetPoint('BOTTOM', UIParent, 'BOTTOM', offsetX, yPosition + offsetY)
    else
        -- Standard positioning logic
        local leftbar = MultiBarBottomLeft and MultiBarBottomLeft:IsShown()
        local rightbar = MultiBarBottomRight and MultiBarBottomRight:IsShown()
        local anchorFrame, anchorPoint, relativePoint, yOffset

        if leftbar or rightbar then
            if leftbar and rightbar then
                anchorFrame = MultiBarBottomRight
            elseif leftbar then
                anchorFrame = MultiBarBottomLeft
            else
                anchorFrame = MultiBarBottomRight
            end
            anchorPoint = 'TOP'
            relativePoint = 'BOTTOM'
            yOffset = 5 + offsetY
        else
            anchorFrame = addon.pUiMainBar or MainMenuBar
            anchorPoint = 'TOP'
            relativePoint = 'BOTTOM'
            yOffset = 5 + offsetY
        end

        self:SetPoint(relativePoint, anchorFrame, anchorPoint, offsetX, yOffset)
    end
end

-- =============================================================================
-- POSSESS BAR SETUP
-- =============================================================================
local possessbar = CreateFrame('Frame', 'NozdorUI_PossessBar', UIParent, 'SecureHandlerStateTemplate')
possessbar:SetAllPoints(anchor)

-- Track created frames
MulticastModule.frames.possessbar = possessbar

-- =============================================================================
-- POSSESS BUTTON POSITIONING FUNCTION
-- =============================================================================
local function PositionPossessButtons()
    if not IsModuleEnabled() then return end

    if InCombatLockdown() then return end

    -- Get config values safely
    local additionalConfig = GetAdditionalConfig()
    local btnsize = additionalConfig.size or 37
    local space = additionalConfig.spacing or 4

    for index = 1, NUM_POSSESS_SLOTS do
        local button = _G['PossessButton'..index]
        if button then
            button:ClearAllPoints()
            button:SetParent(possessbar)
            button:SetSize(btnsize, btnsize)

            if index == 1 then
                button:SetPoint('BOTTOMLEFT', possessbar, 'BOTTOMLEFT', 0, 0)
            else
                local prevButton = _G['PossessButton'..(index-1)]
                if prevButton then
                    button:SetPoint('LEFT', prevButton, 'RIGHT', space, 0)
                end
            end

            button:Show()
            possessbar:SetAttribute('addchild', button)
        end
    end

    -- Apply custom button template if available
    if addon.possessbuttons_template then
        addon.possessbuttons_template()
    end

    -- Set visibility driver for vehicle UI
    RegisterStateDriver(possessbar, 'visibility', '[vehicleui][@vehicle,exists] hide; show')

    -- Track state driver for cleanup
    MulticastModule.stateDrivers.possessbar_visibility = {frame = possessbar, state = 'visibility', condition = '[vehicleui][@vehicle,exists] hide; show'}
end

-- Note: Totem bar setup has been moved to stance.lua module

-- =============================================================================
-- HOOK ACTION BAR VISIBILITY CHANGES
-- =============================================================================
local function HookActionBarEvents()
    local bars = {MultiBarBottomLeft, MultiBarBottomRight}

    for _, bar in pairs(bars) do
        if bar then
            -- Safely hook without causing self-reference errors
            if not bar.__NozdorUI_Hooked then
                bar:HookScript('OnShow', function()
                    DelayedCall(0.1, function() anchor:update_position() end)
                end)
                bar:HookScript('OnHide', function()
                    DelayedCall(0.1, function() anchor:update_position() end)
                end)
                bar.__NozdorUI_Hooked = true
            end
        end
    end
end

-- =============================================================================
-- INITIALIZATION FUNCTION
-- =============================================================================

local function InitializeMulticast()
    if not IsModuleEnabled() then return end
    
    -- Hook action bar events for dynamic positioning
    HookActionBarEvents()
    
    -- Update position
    anchor:update_position()
    
    -- Position possess buttons
    PositionPossessButtons()
    
    -- Ensure frames are visible
    if possessbar then
        possessbar:Show()
        possessbar:SetAlpha(1)
    end
    if anchor then
        anchor:Show()
        anchor:SetAlpha(1)
end

    -- Note: Totem bar initialization has been moved to stance.lua module
    
    MulticastModule.initialized = true
end

-- ============================================================================
-- APPLY/RESTORE FUNCTIONS
-- ============================================================================
local function RestoreMulticastSystem()
    if not MulticastModule.applied then return end

    -- Unregister all state drivers
    for name, data in pairs(MulticastModule.stateDrivers) do
        if data.frame then
            UnregisterStateDriver(data.frame, data.state)
        end
    end
    MulticastModule.stateDrivers = {}

    -- Hide custom frames
    if anchor then anchor:Hide() end
    if possessbar then possessbar:Hide() end

    -- Restore PossessBarFrame to original state
    if PossessBarFrame and MulticastModule.originalStates.possessBarFrame then
        local original = MulticastModule.originalStates.possessBarFrame
        PossessBarFrame:SetParent(original.parent or UIParent)
        PossessBarFrame:ClearAllPoints()

        -- Restore original anchor points
        for _, pointData in ipairs(original.points) do
            local point, relativeTo, relativePoint, x, y = unpack(pointData)
            if relativeTo then
                PossessBarFrame:SetPoint(point, relativeTo, relativePoint, x, y)
            else
                PossessBarFrame:SetPoint(point, relativePoint, x, y)
            end
        end
    end

    -- Note: Totem bar restoration has been moved to stance.lua module

    -- Reset possess button parents to default
    for index = 1, NUM_POSSESS_SLOTS do
        local button = _G['PossessButton'..index]
        if button then
            button:SetParent(PossessBarFrame or UIParent)
            button:ClearAllPoints()
            -- Don't reset positions here - let Blizzard handle it
        end
    end

    MulticastModule.applied = false
end

local function ApplyMulticastSystem()
    if MulticastModule.applied or not IsModuleEnabled() then return end

    -- Ensure frames are created
    if not anchor then
        anchor = CreateFrame('Frame', 'NozdorUI_MulticastAnchor', UIParent)
        anchor:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, 52)
        anchor:SetSize(37, 37)
        MulticastModule.frames.anchor = anchor
    end
    
    if not possessbar then
        possessbar = CreateFrame('Frame', 'NozdorUI_PossessBar', UIParent, 'SecureHandlerStateTemplate')
        possessbar:SetAllPoints(anchor)
        MulticastModule.frames.possessbar = possessbar
    end

    -- Store original states for restoration
    if PossessBarFrame then
        MulticastModule.originalStates.possessBarFrame = {
            parent = PossessBarFrame:GetParent(),
            points = {}
        }
        -- Store all anchor points
        for i = 1, PossessBarFrame:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = PossessBarFrame:GetPoint(i)
            table.insert(MulticastModule.originalStates.possessBarFrame.points, {point, relativeTo, relativePoint, x, y})
        end

        -- Parent and position the PossessBarFrame
        PossessBarFrame:SetParent(possessbar)
        PossessBarFrame:ClearAllPoints()
            PossessBarFrame:SetPoint('BOTTOMLEFT', possessbar, 'BOTTOMLEFT', -68, 0)
        end
    
    -- Note: Totem bar setup has been moved to stance.lua module

    -- Hook action bar events for dynamic positioning
    HookActionBarEvents()

    -- Initialize the system
    InitializeMulticast()

    MulticastModule.applied = true
end

-- =============================================================================
-- UNIFIED REFRESH FUNCTION
-- =============================================================================

-- Enhanced refresh function with module control
function addon.RefreshMulticastSystem()
    if IsModuleEnabled() then
        ApplyMulticastSystem()
        -- Call original refresh for settings
        if addon.RefreshMulticast then
            addon.RefreshMulticast()
        end
    else
        RestoreMulticastSystem()
    end
end

-- Fast refresh: Only updates size and spacing WITHOUT repositioning
function addon.RefreshMulticast(fullRefresh)
    if not IsModuleEnabled() then return end

    if InCombatLockdown() or UnitAffectingCombat("player") then
        -- Schedule refresh after combat
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        frame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            addon.RefreshMulticast(fullRefresh)
        end)
        return
    end

    -- Only update anchor position if NOT a full refresh (X/Y changes)
    if not fullRefresh then
        if anchor and anchor.update_position then
            anchor:update_position()
        end
        return -- Exit here for X/Y changes
    end

    -- Get config values once (cached for performance)
    local additionalConfig = GetAdditionalConfig()
    local btnsize = additionalConfig.size or 37
    local space = additionalConfig.spacing or 4

    --  UPDATE POSSESS BUTTONS - ONLY SIZE, NO REPOSITIONING
    for index = 1, NUM_POSSESS_SLOTS do
        local button = _G["PossessButton"..index]
        if button then
            button:SetSize(btnsize, btnsize)
            -- DO NOT reposition - keep existing positions
        end
    end

    -- Note: Totem button updates have been moved to stance.lua module
end

-- Full rebuild: Only for major changes (profile changes, etc.)
function addon.RefreshMulticastFull()
    if not IsModuleEnabled() then return end

    if InCombatLockdown() or UnitAffectingCombat("player") then return end

    -- Reinitialize everything from scratch
    InitializeMulticast()
end

-- =============================================================================
-- PROFILE CHANGE HANDLER
-- =============================================================================
local function OnProfileChanged()
    -- Delay to ensure profile data is fully loaded
    DelayedCall(0.2, function()
        if InCombatLockdown() or UnitAffectingCombat("player") then
            -- Schedule for after combat if in combat
            local frame = CreateFrame("Frame")
            frame:RegisterEvent("PLAYER_REGEN_ENABLED")
            frame:SetScript("OnEvent", function(self)
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                OnProfileChanged()
            end)
            return
        end

        -- Use the same refresh that works for X/Y sliders (prevents ghost elements)
        addon.RefreshMulticast()
    end)
end

-- =============================================================================
-- INITIALIZATION (same pattern as petbar and stance)
-- =============================================================================
local multicastInitFrame = CreateFrame("Frame")
multicastInitFrame:RegisterEvent("ADDON_LOADED")
multicastInitFrame:RegisterEvent("PLAYER_LOGIN")
multicastInitFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
multicastInitFrame:RegisterEvent("VARIABLES_LOADED")
multicastInitFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "NozdorUI" then
        self.addonLoaded = true
    elseif event == "VARIABLES_LOADED" or event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- Check if class is available and update it
        if UnitClass then
            local _, playerClass = UnitClass("player")
            if playerClass then
                class = playerClass
            end
        end
        
        -- Try to apply system if module is enabled (only for possess bar now)
        if IsModuleEnabled() then
            if PossessBarFrame then
                -- Apply for possess bar
                if not MulticastModule.applied then
                    ApplyMulticastSystem()
                end
            end
        end
    end
end)

-- =============================================================================
-- CENTRALIZED EVENT HANDLER (optimized event management)
-- =============================================================================
local eventFrame = CreateFrame("Frame")
local function RegisterEvents()
                    eventFrame:RegisterEvent("PLAYER_LOGOUT")
                    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_LOGOUT" then
            -- Profile callbacks cleanup removed - using C_CacheSystem instead of AceDB
            
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Update position after combat ends (with delay for stability)
            DelayedCall(0.5, function()
                if anchor and anchor.update_position then
                    anchor:update_position()
                end
            end)
        end
    end)
end

-- Initialize event system
RegisterEvents()

-- Register profile change handler
DelayedCall(0.5, function()
    if addon.core and addon.core.RegisterMessage then
        addon.core.RegisterMessage(addon, "NOZDORUI_PROFILE_CHANGED", OnProfileChanged)
    end
end)
