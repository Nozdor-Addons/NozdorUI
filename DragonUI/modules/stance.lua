-- Get addon reference - either from XML parameter or global
local addon = select(2, ...);
local config = addon.config;
local event = addon.package;
local class = addon._class;
local pUiMainBar = addon.pUiMainBar;
local unpack = unpack;
local select = select;
local pairs = pairs;
local _G = getfenv(0);

-- ============================================================================
-- STANCE MODULE FOR NozdorUI
-- ============================================================================

-- Module state tracking
local StanceModule = {
    initialized = false,
    applied = false,
    originalStates = {},     -- Store original states for restoration
    registeredEvents = {},   -- Track registered events
    hooks = {},             -- Track hooked functions
    stateDrivers = {},      -- Track state drivers
    frames = {}             -- Track created frames
}

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.stance
end

local function IsModuleEnabled()
    local cfg = GetModuleConfig()
    return cfg and cfg.enabled
end

-- ============================================================================
-- CONSTANTS AND VARIABLES
-- ============================================================================

-- const
local InCombatLockdown = InCombatLockdown;
local GetNumShapeshiftForms = GetNumShapeshiftForms;
local GetShapeshiftFormInfo = GetShapeshiftFormInfo;
local GetShapeshiftFormCooldown = GetShapeshiftFormCooldown;
local CreateFrame = CreateFrame;
local UIParent = UIParent;
local hooksecurefunc = hooksecurefunc;
local UnitAffectingCombat = UnitAffectingCombat;

-- WOTLK 3.3.5a Constants
local NUM_SHAPESHIFT_SLOTS = 10; -- Fixed value for 3.3.5a compatibility

local stance = {
	['DEATHKNIGHT'] = 'show',
	['DRUID'] = 'show',
	['PALADIN'] = 'show',
	['PRIEST'] = 'show',
	['ROGUE'] = 'show',
	['WARLOCK'] = 'show',
	['WARRIOR'] = 'show',
	['SHAMAN'] = 'show'  -- Show for Shaman to display totem bar
};

-- Module frames (created only when enabled)
local anchor, stancebar

-- Initialize MultiBar references
local MultiBarBottomLeft = _G["MultiBarBottomLeft"]
local MultiBarBottomRight = _G["MultiBarBottomRight"]

-- Simple initialization tracking
local stanceBarInitialized = false;

-- Function to hide totem square textures (for Shaman)
local function HideTotemSquareTextures()
    if not MultiCastActionBarFrame or class ~= 'SHAMAN' then return end
    
    for i = 1, 4 do
        local slotButton = _G["MultiCastSlotButton"..i]
        if slotButton then
            if slotButton.background then
                slotButton.background:Hide()
                slotButton.background:SetAlpha(0)
            end
            if slotButton.overlay then
                slotButton.overlay:Hide()
                slotButton.overlay:SetAlpha(0)
            end
            for j = 1, slotButton:GetNumRegions() do
                local region = select(j, slotButton:GetRegions())
                if region and region:GetObjectType() == "Texture" then
                    local texture = region:GetTexture()
                    local texturePath = texture and tostring(texture) or ""
                    local textureLower = string.lower(texturePath)
                    local drawLayer = region:GetDrawLayer()
                    if string.find(textureLower, "totembar") or 
                       (drawLayer == "BACKGROUND" or drawLayer == "OVERLAY") then
                        region:Hide()
                        region:SetAlpha(0)
                    end
                end
            end
        end
        
        local actionButton = _G["MultiCastActionButton"..i]
        if actionButton then
            if actionButton.overlay then
                actionButton.overlay:Hide()
                actionButton.overlay:SetAlpha(0)
            end
            for j = 1, actionButton:GetNumRegions() do
                local region = select(j, actionButton:GetRegions())
                if region and region:GetObjectType() == "Texture" then
                    local texture = region:GetTexture()
                    local texturePath = texture and tostring(texture) or ""
                    local textureLower = string.lower(texturePath)
                    if string.find(textureLower, "totembar") or 
                       (not string.find(textureLower, "icon") and 
                        not string.find(textureLower, "spell") and
                        not string.find(textureLower, "ability")) then
                        region:Hide()
                        region:SetAlpha(0)
                    end
                end
            end
        end
    end
end

-- Function to hide square textures around stance button icons
local function HideStanceSquareTextures()
    for index = 1, NUM_SHAPESHIFT_SLOTS do
        local button = _G['ShapeshiftButton'..index]
        if button then
            -- Hide via GetRegions - hide ALL textures except icon
            for j = 1, button:GetNumRegions() do
                local region = select(j, button:GetRegions())
                if region and region:GetObjectType() == "Texture" then
                    local texture = region:GetTexture()
                    local texturePath = texture and tostring(texture) or ""
                    local textureLower = string.lower(texturePath)
                    local drawLayer = region:GetDrawLayer()
                    local regionName = region:GetName() or ""
                    local regionNameLower = string.lower(regionName)
                    
                    -- Get icon texture name for comparison
                    local icon = _G['ShapeshiftButton'..index..'Icon']
                    local isIcon = (region == icon)
                    
                    -- Hide if it's background/overlay/border layer AND not the icon
                    if not isIcon and (drawLayer == "BACKGROUND" or drawLayer == "OVERLAY" or drawLayer == "BORDER") then
                        region:Hide()
                        region:SetAlpha(0)
                    elseif not isIcon and (string.find(textureLower, "border") or 
                                           string.find(textureLower, "background") or
                                           string.find(textureLower, "frame") or
                                           string.find(regionNameLower, "border") or
                                           string.find(regionNameLower, "background") or
                                           string.find(regionNameLower, "normal")) then
                        region:Hide()
                        region:SetAlpha(0)
                    end
                end
            end
            
            -- Also hide specific textures if they exist
            if button:GetNormalTexture() then
                local normalTex = button:GetNormalTexture()
                if normalTex ~= icon then
                    normalTex:Hide()
                    normalTex:SetAlpha(0)
                end
            end
            if button:GetPushedTexture() then
                button:GetPushedTexture():SetAlpha(0.3) -- Keep but make subtle
            end
            if button:GetHighlightTexture() then
                button:GetHighlightTexture():SetAlpha(0.3) -- Keep but make subtle
            end
        end
    end
end

-- SIMPLE STATIC POSITIONING - NO DYNAMIC LOGIC
local function stancebar_update()
    if not IsModuleEnabled() then return end
    
    -- Ensure default settings are loaded
    StanceModule:LoadDefaultSettings()
    
    -- Apply position from widgets config (like player frame)
    local stanceFrame = StanceModule.frames.stanceFrame
    if stanceFrame then
        local widgetConfig = addon:GetConfigValue("widgets", "stance")
        if widgetConfig and widgetConfig.anchor and widgetConfig.posX and widgetConfig.posY then
            stanceFrame:ClearAllPoints()
            stanceFrame:SetPoint(widgetConfig.anchor, UIParent, widgetConfig.anchor, widgetConfig.posX, widgetConfig.posY)
            return
        end
        
        -- Fallback to default position if widgets config doesn't exist
        stanceFrame:ClearAllPoints()
        stanceFrame:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', 20, 180)
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Simple update function - no queues needed
local function UpdateStanceBar()
    if not IsModuleEnabled() then return end
    stancebar_update()
end

-- ============================================================================
-- POSITIONING FUNCTIONS
-- ============================================================================


-- ============================================================================
-- FRAME CREATION FUNCTIONS
-- ============================================================================

local function CreateStanceFrames()
    if StanceModule.frames.stanceFrame or not IsModuleEnabled() then return end
    
    -- Update class dynamically
    if UnitClass then
        local _, playerClass = UnitClass("player")
        if playerClass then
            class = playerClass
        end
    end
    
    -- Calculate frame size based on button size and spacing
    local stanceConfig = addon.db.profile.additional.stance
    local additionalConfig = addon.db.profile.additional
    local btnsize = stanceConfig.button_size or additionalConfig.size or 29
    local space = stanceConfig.button_spacing or additionalConfig.spacing or 3
    -- For Shaman with totems, calculate width for 4 totem slots + summon/recall buttons
    -- For other classes, assume max 10 buttons
    local maxButtons = (class == 'SHAMAN') and 6 or 10
    local frameWidth = (btnsize * maxButtons) + (space * (maxButtons - 1)) + 20  -- 20px padding on each side
    local frameHeight = btnsize + 10  -- 10px padding top and bottom
    
    -- Create editor frame using CreateUIFrame (like player frame) - larger size for green background
    local stanceFrame = addon.CreateUIFrame(frameWidth, frameHeight, "stance")
    StanceModule.frames.stanceFrame = stanceFrame
    
    -- Create simple anchor frame
    anchor = CreateFrame('Frame', 'pUiStanceHolder', stanceFrame)
    anchor:SetAllPoints(stanceFrame)
    anchor:SetSize(frameWidth, frameHeight)
    -- Ensure anchor is below editor frame (green overlay)
    anchor:SetFrameStrata("MEDIUM")
    anchor:SetFrameLevel(1)
    StanceModule.frames.anchor = anchor
    
    -- Create stance bar frame
    stancebar = CreateFrame('Frame', 'pUiStanceBar', anchor, 'SecureHandlerStateTemplate')
    stancebar:SetAllPoints(anchor)
    -- Ensure stancebar is below editor frame (green overlay)
    stancebar:SetFrameStrata("MEDIUM")
    stancebar:SetFrameLevel(2)
    StanceModule.frames.stancebar = stancebar
    
    -- Expose globally for compatibility
    _G.pUiStanceBar = stancebar
    
    -- Apply static positioning immediately
    stancebar_update()
    
    -- Load default settings if needed
    StanceModule:LoadDefaultSettings()
    
    -- Register in editor system (like player frame - immediately after creation)
    if addon.RegisterEditableFrame and stanceFrame then
        addon:RegisterEditableFrame({
            name = "StanceBar",
            frame = stanceFrame,
            configPath = {"widgets", "stance"},
            onHide = function()
                StanceModule:UpdateWidgets()
                if addon.RefreshStance then
                    addon.RefreshStance()
                end
            end,
            LoadDefaultSettings = function() StanceModule:LoadDefaultSettings() end,
            UpdateWidgets = function() StanceModule:UpdateWidgets() end
        })
    end
end

-- ============================================================================
-- POSITIONING FUNCTIONS
-- ============================================================================

--



-- ============================================================================
-- STANCE BUTTON FUNCTIONS
-- ============================================================================

local function stancebutton_update()
    if not IsModuleEnabled() or not anchor then return end
    
	if not InCombatLockdown() then
		_G.ShapeshiftButton1:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
	end
end

local function stancebutton_position()
    if not IsModuleEnabled() or not stancebar or not anchor then return end
    
    -- READ VALUES FROM DATABASE - Scale approach
    local stanceConfig = addon.db.profile.additional.stance
    local additionalConfig = addon.db.profile.additional
    local btnsize = stanceConfig.button_size or additionalConfig.size or 29  -- Base size 29
    local space = stanceConfig.button_spacing or additionalConfig.spacing or 3
    local scale = btnsize / 29  -- Calculate scale factor from base size 29
    
    -- Update frame size to make green background larger
    local stanceFrame = StanceModule.frames.stanceFrame
    if stanceFrame then
        -- Calculate new frame size based on button size and spacing
        local frameWidth = (btnsize * 10) + (space * 9) + 20  -- 20px padding on each side
        local frameHeight = btnsize + 10  -- 10px padding top and bottom
        stanceFrame:SetSize(frameWidth, frameHeight)
        anchor:SetSize(frameWidth, frameHeight)
    end
    
    -- CLEAN SETUP - Avoid duplications
	for index=1, NUM_SHAPESHIFT_SLOTS do
		local button = _G['ShapeshiftButton'..index]
		if button then
		    -- Only modify parent if not already configured
		    if button:GetParent() ~= stancebar then
			    button:ClearAllPoints()
			    button:SetParent(stancebar)
		    end
		    -- Ensure buttons are below editor frame (green overlay)
		    button:SetFrameStrata("MEDIUM")
		    button:SetFrameLevel(3)
		    -- Use scale instead of SetSize for better border scaling
		    button:SetSize(29, 29)  -- Keep base size
		    button:SetScale(scale)  -- Apply scale factor
		    
		    -- Always update positioning
		    if index == 1 then
			    button:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
		    else
			    local previous = _G['ShapeshiftButton'..index-1]
			    button:SetPoint('LEFT', previous, 'RIGHT', space, 0)
		    end
		    
		    -- Show/hide based on forms
		    local _,name = GetShapeshiftFormInfo(index)
		    if name then
			    button:Show()
		    else
			    button:Hide()
		    end
		    
		    -- CRITICAL: Register stance buttons for keybinding
		    if addon.KeyBindingModule and addon.KeyBindingModule.enabled and 
		       not addon.KeyBindingModule.registeredButtons[button] then
		        addon.KeyBindingModule:MakeButtonBindable(button, "SHAPESHIFT" .. index, "Стойка " .. index)
		    end
		    
		    -- Hide square textures around icon
		    C_Timer.After(0.1, HideStanceSquareTextures)
		end
	end
	
	-- Hide square textures after positioning
	HideStanceSquareTextures()
	C_Timer.After(0.2, HideStanceSquareTextures)
	
	-- Register state driver only once
	-- For Shaman, always show to display totem bar
	if not StanceModule.stateDrivers.visibility then
	    local visibilityCondition = stance[class] or 'hide'
	    -- For Shaman, always show stancebar to display totem bar
	    if class == 'SHAMAN' then
	        visibilityCondition = 'show'
	    end
	    StanceModule.stateDrivers.visibility = {frame = stancebar, state = 'visibility', condition = visibilityCondition}
	    RegisterStateDriver(stancebar, 'visibility', visibilityCondition)
	end
end

local function stancebutton_updatestate()
    if not IsModuleEnabled() then return end
    
	local numForms = GetNumShapeshiftForms()
	local texture, name, isActive, isCastable;
	local button, icon, cooldown;
	local start, duration, enable;
	for index=1, NUM_SHAPESHIFT_SLOTS do
		button = _G['ShapeshiftButton'..index]
		icon = _G['ShapeshiftButton'..index..'Icon']
		if index <= numForms then
			texture, name, isActive, isCastable = GetShapeshiftFormInfo(index)
			icon:SetTexture(texture)
			cooldown = _G['ShapeshiftButton'..index..'Cooldown']
			if texture then
				cooldown:SetAlpha(1)
			else
				cooldown:SetAlpha(0)
			end
			start, duration, enable = GetShapeshiftFormCooldown(index)
			CooldownFrame_SetTimer(cooldown, start, duration, enable)
			if isActive then
				ShapeshiftBarFrame.lastSelected = button:GetID()
				button:SetChecked(1)
			else
				button:SetChecked(0)
			end
			if isCastable then
				icon:SetVertexColor(255/255, 255/255, 255/255)
			else
				icon:SetVertexColor(102/255, 102/255, 102/255)
			end
		end
	end
	
	-- Hide square textures after update
	C_Timer.After(0.1, HideStanceSquareTextures)
end

local function stancebutton_setup()
    if not IsModuleEnabled() then return end
    
	if InCombatLockdown() then return end
	for index=1, NUM_SHAPESHIFT_SLOTS do
		local button = _G['ShapeshiftButton'..index]
		if button then
			local _, name = GetShapeshiftFormInfo(index)
			if name then
				button:Show()
			else
				button:Hide()
			end
			
			-- CRITICAL: Register stance buttons for keybinding
			if addon.KeyBindingModule and addon.KeyBindingModule.enabled and 
			   not addon.KeyBindingModule.registeredButtons[button] then
				addon.KeyBindingModule:MakeButtonBindable(button, "SHAPESHIFT" .. index, "Стойка " .. index)
			end
		end
	end
	stancebutton_updatestate();
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local function OnEvent(self,event,...)
    if not IsModuleEnabled() then return end
    
	if GetNumShapeshiftForms() < 1 then return; end
	if event == 'PLAYER_LOGIN' then
		stancebutton_position();
	elseif event == 'UPDATE_SHAPESHIFT_FORMS' then
		stancebutton_setup();
	elseif event == 'PLAYER_ENTERING_WORLD' then
		self:UnregisterEvent('PLAYER_ENTERING_WORLD');
		if addon.stancebuttons_template then
		    addon.stancebuttons_template();
		end
	else
		stancebutton_updatestate();
	end
end

-- ============================================================================
-- INITIALIZATION FUNCTIONS
-- ============================================================================

-- Setup totem bar for Shaman (similar to stance bar)
local function SetupTotemBar()
    -- Update class dynamically
    if UnitClass then
        local _, playerClass = UnitClass("player")
        if playerClass then
            class = playerClass
        end
    end
    
    if not MultiCastActionBarFrame or class ~= 'SHAMAN' then return end
    
    -- Track MultiCastActionBarFrame
    StanceModule.frames.multiCastActionBarFrame = MultiCastActionBarFrame
    
    -- Remove default scripts that might interfere
    MultiCastActionBarFrame:SetScript('OnUpdate', nil)
    MultiCastActionBarFrame:SetScript('OnShow', nil)
    MultiCastActionBarFrame:SetScript('OnHide', nil)
    
    -- Hide immediately and with delay
    HideTotemSquareTextures()
    
    -- Parent and position the MultiCastActionBarFrame to anchor frame
    -- Use anchor instead of stanceFrame to ensure proper layering and real-time updates
    if anchor then
        if not InCombatLockdown() then
            MultiCastActionBarFrame:SetParent(anchor)
            MultiCastActionBarFrame:ClearAllPoints()
            MultiCastActionBarFrame:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
        end
        -- Set proper frame level to be below green editor frame (which is 100)
        MultiCastActionBarFrame:SetFrameStrata("MEDIUM")
        MultiCastActionBarFrame:SetFrameLevel(3)  -- Below green overlay (100), same as stance buttons
    end
    
    -- Force show and make visible
    if not InCombatLockdown() then
        -- Disable the hide function to prevent it from being hidden
        if HideMultiCastActionBar then
            _G.HideMultiCastActionBar = function() end
        end
        
        -- Call the show function if it exists
        if ShowMultiCastActionBar then
            ShowMultiCastActionBar(true) -- true = doNotSlide
        end
    end
    
    -- Force show multiple times to ensure visibility
    MultiCastActionBarFrame:Show()
    MultiCastActionBarFrame:SetAlpha(1)
    
    -- Ensure it stays visible with delayed checks
    C_Timer.After(0.1, function()
        if MultiCastActionBarFrame then
            MultiCastActionBarFrame:Show()
            MultiCastActionBarFrame:SetAlpha(1)
            if ShowMultiCastActionBar then
                ShowMultiCastActionBar(true)
            end
        end
    end)
    
    C_Timer.After(0.5, function()
        if MultiCastActionBarFrame then
            MultiCastActionBarFrame:Show()
            MultiCastActionBarFrame:SetAlpha(1)
            if ShowMultiCastActionBar then
                ShowMultiCastActionBar(true)
            end
        end
    end)
    
    -- Hide square textures with delay to ensure buttons are created
    C_Timer.After(0.2, HideTotemSquareTextures)
    C_Timer.After(0.5, HideTotemSquareTextures)
    C_Timer.After(1.0, HideTotemSquareTextures)
    
    -- Hook MultiCastSlotButton_Update to hide squares every time buttons update
    if not StanceModule.hooks.MultiCastSlotButton_Update then
        StanceModule.hooks.MultiCastSlotButton_Update = true
        hooksecurefunc('MultiCastSlotButton_Update', function(self, slot)
            if self and self:IsShown() then
                C_Timer.After(0.1, function()
                    if self.background then
                        self.background:Hide()
                        self.background:SetAlpha(0)
                    end
                    if self.overlay then
                        self.overlay:Hide()
                        self.overlay:SetAlpha(0)
                    end
                    -- Also hide via GetRegions
                    for j = 1, self:GetNumRegions() do
                        local region = select(j, self:GetRegions())
                        if region and region:GetObjectType() == "Texture" then
                            local texture = region:GetTexture()
                            local texturePath = texture and tostring(texture) or ""
                            local textureLower = string.lower(texturePath)
                            local drawLayer = region:GetDrawLayer()
                            if string.find(textureLower, "totembar") or 
                               (drawLayer == "BACKGROUND" or drawLayer == "OVERLAY") then
                                region:Hide()
                                region:SetAlpha(0)
                            end
                        end
                    end
                end)
            end
        end)
    end
    
    -- Hook stanceFrame movement to update totem position in real-time
    local stanceFrame = StanceModule.frames.stanceFrame
    if stanceFrame and not StanceModule.hooks.totemPositionUpdate then
        StanceModule.hooks.totemPositionUpdate = true
        
        -- Hook OnDragStart to update totem position when dragging starts
        local originalOnDragStart = stanceFrame:GetScript('OnDragStart')
        stanceFrame:SetScript('OnDragStart', function(self)
            -- Call original OnDragStart if it exists
            if originalOnDragStart then
                originalOnDragStart(self)
            end
            
            -- Start updating totem position in real-time during drag
            if MultiCastActionBarFrame and anchor then
                -- Create update frame for real-time position updates
                if not StanceModule.totemUpdateFrame then
                    StanceModule.totemUpdateFrame = CreateFrame('Frame')
                    StanceModule.totemUpdateFrame:SetScript('OnUpdate', function()
                        if MultiCastActionBarFrame and anchor and not InCombatLockdown() then
                            MultiCastActionBarFrame:ClearAllPoints()
                            MultiCastActionBarFrame:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
                        end
                    end)
                end
                StanceModule.totemUpdateFrame:Show()
            end
        end)
        
        -- Hook OnDragStop to stop real-time updates
        local originalOnDragStop = stanceFrame:GetScript('OnDragStop')
        stanceFrame:SetScript('OnDragStop', function(self)
            -- Stop real-time updates
            if StanceModule.totemUpdateFrame then
                StanceModule.totemUpdateFrame:Hide()
            end
            
            -- Call original OnDragStop if it exists
            if originalOnDragStop then
                originalOnDragStop(self)
            end
            
            -- Final update of totem position after drag
            if MultiCastActionBarFrame and anchor then
                if not InCombatLockdown() then
                    MultiCastActionBarFrame:ClearAllPoints()
                    MultiCastActionBarFrame:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
                end
            end
        end)
    end
    
    -- Prevent the frame from being moved by other addons (but allow our system)
    if not StanceModule.hooks.totemProtection then
        StanceModule.hooks.totemProtection = true
        local originalSetParent = MultiCastActionBarFrame.SetParent
        local originalSetPoint = MultiCastActionBarFrame.SetPoint
        
        MultiCastActionBarFrame.SetParent = function(self, parent)
            -- Allow setting parent to anchor or stanceFrame
            if parent == anchor or parent == StanceModule.frames.stanceFrame or parent == stancebar then
                originalSetParent(self, parent)
            end
        end
        
        MultiCastActionBarFrame.SetPoint = function(self, point, relativeTo, relativePoint, x, y)
            -- Allow setting point relative to anchor
            if relativeTo == anchor then
                originalSetPoint(self, point, relativeTo, relativePoint, x, y)
            end
        end
    end
    
    -- Also protect the recall button if it exists
    if MultiCastRecallSpellButton and not StanceModule.hooks.recallButtonProtection then
        StanceModule.hooks.recallButtonProtection = true
        -- Don't block SetPoint for recall button, let it position naturally
    end
end

-- Simple initialization function
local function InitializeStanceBar()
    if not IsModuleEnabled() then return end
    
    -- Simple setup - no complex checks
    stancebutton_position()
    stancebar_update()
    
    if stancebar then
        stancebar:Show()
        stancebar:SetAlpha(1)
    end
    if anchor then
        anchor:Show()
        anchor:SetAlpha(1)
    end
    
    -- Ensure stance buttons are visible (for classes with stances)
    local numForms = GetNumShapeshiftForms()
    if numForms > 0 then
        for index = 1, NUM_SHAPESHIFT_SLOTS do
            local button = _G['ShapeshiftButton'..index]
            if button then
                local _, name = GetShapeshiftFormInfo(index)
                if name then
                    button:Show()
                end
            end
        end
    end
    
    -- For Shaman, setup totem bar (even if no stances)
    if class == 'SHAMAN' then
        -- Ensure frames are visible for totem bar
        local stanceFrame = StanceModule.frames.stanceFrame
        if stanceFrame then
            stanceFrame:Show()
            stanceFrame:SetAlpha(1)
        end
        if anchor then
            anchor:Show()
            anchor:SetAlpha(1)
        end
        if stancebar then
            stancebar:Show()
            stancebar:SetAlpha(1)
        end
        
        -- Setup totem bar
        if MultiCastActionBarFrame then
            SetupTotemBar()
        end
    end
    
    -- Hide square textures after initialization
    HideStanceSquareTextures()
    C_Timer.After(0.2, HideStanceSquareTextures)
    C_Timer.After(0.5, HideStanceSquareTextures)
    
    stanceBarInitialized = true
end

-- ============================================================================
-- APPLY/RESTORE FUNCTIONS
-- ============================================================================

local function ApplyStanceSystem()
    if StanceModule.applied or not IsModuleEnabled() then return end
    
    -- Create frames (this also registers in editor)
    CreateStanceFrames()
    
    if not StanceModule.frames.stanceFrame or not anchor or not stancebar then 
        -- Retry frame creation if failed
        CreateStanceFrames()
        if not StanceModule.frames.stanceFrame or not anchor or not stancebar then return end
    end
    
    -- Ensure frames are visible
    local stanceFrame = StanceModule.frames.stanceFrame
    if stanceFrame then
        stanceFrame:Show()
        stanceFrame:SetAlpha(1)
    end
    if anchor then
        anchor:Show()
        anchor:SetAlpha(1)
    end
    if stancebar then
        stancebar:Show()
        stancebar:SetAlpha(1)
    end
    
    -- Register only essential events
    local events = {
        'PLAYER_LOGIN',
        'UPDATE_SHAPESHIFT_FORMS',
        'UPDATE_SHAPESHIFT_FORM'
    }
    
    for _, eventName in ipairs(events) do
        stancebar:RegisterEvent(eventName)
        StanceModule.registeredEvents[eventName] = stancebar
    end
    stancebar:SetScript('OnEvent', OnEvent)
    
    -- Simple hook for Blizzard updates - REGISTER ONLY ONCE
    if not StanceModule.hooks.ShapeshiftBar_Update then
        StanceModule.hooks.ShapeshiftBar_Update = true
        hooksecurefunc('ShapeshiftBar_Update', function()
            if IsModuleEnabled() then
                stancebutton_update()
                -- Hide square textures after Blizzard update
                C_Timer.After(0.1, HideStanceSquareTextures)
            end
        end)
    end
    
    -- For Shaman, setup totem bar
    if MultiCastActionBarFrame and class == 'SHAMAN' then
        SetupTotemBar()
    end
    
    -- Hook ShapeshiftBar_UpdateState to hide squares on every update
    if _G.ShapeshiftBar_UpdateState and not StanceModule.hooks.ShapeshiftBar_UpdateState then
        StanceModule.hooks.ShapeshiftBar_UpdateState = true
        hooksecurefunc('ShapeshiftBar_UpdateState', function()
            if IsModuleEnabled() then
                C_Timer.After(0.1, HideStanceSquareTextures)
            end
        end)
    end
    
    -- Initial setup
    InitializeStanceBar()
    
    StanceModule.applied = true
end

local function RestoreStanceSystem()
    if not StanceModule.applied then return end
    
    -- Unregister all events
    for eventName, frame in pairs(StanceModule.registeredEvents) do
        if frame and frame.UnregisterEvent then
            frame:UnregisterEvent(eventName)
        end
    end
    StanceModule.registeredEvents = {}
    
    -- Unregister all state drivers
    for name, data in pairs(StanceModule.stateDrivers) do
        if data.frame then
            UnregisterStateDriver(data.frame, data.state)
        end
    end
    StanceModule.stateDrivers = {}
    
    -- Hide custom frames
    if anchor then anchor:Hide() end
    if stancebar then stancebar:Hide() end
    
    -- Reset stance button parents to default
    for index=1, NUM_SHAPESHIFT_SLOTS do
        local button = _G['ShapeshiftButton'..index]
        if button then
            button:SetParent(ShapeshiftBarFrame or UIParent)
            button:ClearAllPoints()
            -- Don't reset positions here - let Blizzard handle it
        end
    end
    
    -- Clear global reference
    _G.pUiStanceBar = nil
    
    -- Reset variables
    stanceBarInitialized = false
    
    StanceModule.applied = false
end

-- ============================================================================
-- FUNCTIONS REQUIRED BY CENTRALIZED SYSTEM
-- ============================================================================

function StanceModule:LoadDefaultSettings()
    -- Ensure configuration exists in widgets
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    
    if not addon.db.profile.widgets.stance then
        addon.db.profile.widgets.stance = {
            anchor = "BOTTOMLEFT",
            posX = 20,
            posY = 180
        }
    end
end

function StanceModule:UpdateWidgets()
    stancebar_update()
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Enhanced refresh function with module control
function addon.RefreshStanceSystem()
    if IsModuleEnabled() then
        ApplyStanceSystem()
        -- Call original refresh for settings
        if addon.RefreshStance then
            addon.RefreshStance()
        end
    else
        RestoreStanceSystem()
    end
end

-- Original refresh function for configuration changes
function addon.RefreshStance()
    if not IsModuleEnabled() then return end
    
	if InCombatLockdown() or UnitAffectingCombat('player') then 
		return 
	end
	
	-- Ensure frames exist
	if not anchor or not stancebar then
	    return
	end
	
	-- Update button scale and spacing with visual style
	local stanceConfig = addon.db.profile.additional.stance
	local additionalConfig = addon.db.profile.additional
	local btnsize = stanceConfig.button_size or additionalConfig.size or 29  -- Base size 29
	local space = stanceConfig.button_spacing or additionalConfig.spacing or 3
	local scale = btnsize / 29  -- Calculate scale factor
	
	-- Update frame size to make green background larger
	local stanceFrame = StanceModule.frames.stanceFrame
	if stanceFrame then
		-- Calculate new frame size based on button size and spacing
		local frameWidth = (btnsize * 10) + (space * 9) + 20  -- 20px padding on each side
		local frameHeight = btnsize + 10  -- 10px padding top and bottom
		stanceFrame:SetSize(frameWidth, frameHeight)
		if anchor then
			anchor:SetSize(frameWidth, frameHeight)
		end
	end
	
	-- Reposition stance buttons with scale refresh
	for i = 1, NUM_SHAPESHIFT_SLOTS do
		local button = _G["ShapeshiftButton"..i]
		if button then
			button:SetSize(29, 29)  -- Keep base size
			button:SetScale(scale)  -- Apply scale
			if i == 1 then
				button:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
			else
				local prevButton = _G["ShapeshiftButton"..(i-1)]
				if prevButton then
					button:SetPoint('LEFT', prevButton, 'RIGHT', space, 0)
				end
			end
		end
	end
	
	-- Update position
	stancebar_update()
	
	-- For Shaman, ensure totem bar is still visible after refresh
	if MultiCastActionBarFrame and class == 'SHAMAN' then
		if MultiCastActionBarFrame then
			MultiCastActionBarFrame:Show()
			MultiCastActionBarFrame:SetAlpha(1)
			if ShowMultiCastActionBar then
				ShowMultiCastActionBar(true)
			end
		end
	end
end

-- Debug function for troubleshooting stance bar issues
function addon.DebugStanceBar()
    if not IsModuleEnabled() then
        
        return {enabled = false}
    end
    
	local info = {
		stanceBarInitialized = stanceBarInitialized,
		moduleEnabled = IsModuleEnabled(),
		inCombat = InCombatLockdown(),
		unitInCombat = UnitAffectingCombat('player'),
		anchorExists = anchor and true or false,
		stanceBarExists = _G.pUiStanceBar and true or false,
		numShapeshiftForms = GetNumShapeshiftForms(),
		stanceConfig = addon.db.profile.additional.stance
	};
	
	
	for k, v in pairs(info) do
	
	end
	
	if anchor then
		local point, relativeTo, relativePoint, x, y = anchor:GetPoint();
	
	end
	
	return info;
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function Initialize()
    if StanceModule.initialized then return end
    
    -- Only apply if module is enabled
    if IsModuleEnabled() then
        ApplyStanceSystem()
    end
    
    StanceModule.initialized = true
end

-- Auto-initialize when addon loads (same pattern as petbar)
local stanceInitFrame = CreateFrame("Frame")
stanceInitFrame:RegisterEvent("ADDON_LOADED")
stanceInitFrame:RegisterEvent("PLAYER_LOGIN")
stanceInitFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
stanceInitFrame:RegisterEvent("VARIABLES_LOADED")
stanceInitFrame:SetScript("OnEvent", function(self, event, addonName)
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
        
        if IsModuleEnabled() then
            if not StanceModule.applied then
                ApplyStanceSystem()
            else
                -- Re-initialize to ensure visibility
                InitializeStanceBar()
            end
        end
        
        if event == "PLAYER_ENTERING_WORLD" then
            -- Final check for totem bar after entering world
            C_Timer.After(0.1, function()
                if IsModuleEnabled() and MultiCastActionBarFrame and class == 'SHAMAN' then
                    SetupTotemBar()
                end
            end)
            C_Timer.After(0.5, function()
                if IsModuleEnabled() and MultiCastActionBarFrame and class == 'SHAMAN' then
                    if MultiCastActionBarFrame then
                        MultiCastActionBarFrame:Show()
                        MultiCastActionBarFrame:SetAlpha(1)
                        if ShowMultiCastActionBar then
                            ShowMultiCastActionBar(true)
                        end
                    end
                end
            end)
        end
        
        if event == "PLAYER_LOGIN" then
            self:UnregisterAllEvents()
        end
    end
end)
-- End of stance module
