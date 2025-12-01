-- ===============================================================
-- NOZDORUI ARENA ENEMY FRAMES MODULE
-- ===============================================================
-- Get addon reference - either from XML parameter or global
local addon = select(2, ...);

-- ===============================================================
-- EARLY EXIT CHECK
-- ===============================================================
if not addon or not addon.db then
    return -- Exit early if database not ready
end

-- ===============================================================
-- IMPORTS AND GLOBALS
-- ===============================================================

local _G = _G
local MAX_ARENA_ENEMIES = MAX_ARENA_ENEMIES or 5

-- ===============================================================
-- MODULE NAMESPACE AND STORAGE
-- ===============================================================

local ArenaFrames = {}
addon.ArenaFrames = ArenaFrames

ArenaFrames.anchor = nil
ArenaFrames.initialized = false
ArenaFrames.styledFrames = {}

-- ===============================================================
-- CONSTANTS AND CONFIGURATION
-- ===============================================================

-- Texture paths for arena enemy frames (using party frame textures as base)
local TEXTURES = {
    healthBarStatus = "Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status",
    frame = "Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\uipartyframe",
    border = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER",
    healthBar = "Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health",
    manaBar = "Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Mana",
    focusBar = "Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Focus",
    rageBar = "Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Rage",
    energyBar = "Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Energy",
    runicPowerBar = "Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-RunicPower"
}

-- Power types
local POWER_MAP = {
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [6] = "RunicPower"
}

-- ===============================================================
-- CENTRALIZED SYSTEM INTEGRATION
-- ===============================================================

-- Create auxiliary frame for anchoring (similar to party.lua)
local function CreateArenaAnchorFrame()
    if ArenaFrames.anchor then
        return ArenaFrames.anchor
    end

    -- Use centralized function from core.lua
    ArenaFrames.anchor = addon.CreateUIFrame(120, 200, "arena")

    -- Customize text for arena frames
    if ArenaFrames.anchor.editorText then
        ArenaFrames.anchor.editorText:SetText("Рамки арены")
    end

    return ArenaFrames.anchor
end

-- Function to apply position from widgets (similar to party.lua)
local function ApplyWidgetPosition(skipSave)
    skipSave = skipSave or false
    if not ArenaFrames.anchor then
        return
    end

    -- Ensure configuration exists
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets then
        return
    end

    local widgetConfig = addon.db.profile.widgets.arena

    if widgetConfig and widgetConfig.posX and widgetConfig.posY then
        -- Use saved anchor, not always TOPRIGHT
        local anchor = widgetConfig.anchor or "TOPRIGHT"
        
        ArenaFrames.anchor:ClearAllPoints()
        ArenaFrames.anchor:SetPoint(anchor, UIParent, anchor, widgetConfig.posX, widgetConfig.posY)
    else
        -- Create default configuration if it doesn't exist
        if not addon.db.profile.widgets.arena then
            addon.db.profile.widgets.arena = {
                anchor = "TOPRIGHT",
                posX = -90,
                posY = -240
            }
        end
        
        ArenaFrames.anchor:ClearAllPoints()
        ArenaFrames.anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -90, -240)
    end
end

-- ===============================================================
-- CONFIGURATION
-- ===============================================================

local function GetConfig()
    local config = addon:GetConfigValue("unitframe", "arena") or {}
    local defaults = addon.defaults and addon.defaults.profile.unitframe.arena or {}
    return setmetatable(config, {
        __index = defaults
    })
end

-- ===============================================================
-- VISIBILITY AND TEST FUNCTIONS
-- ===============================================================

-- Function to check if arena frames should be visible
local function ShouldArenaFramesBeVisible()
    return GetNumArenaOpponents() > 0
end

-- Test functions for the editor
local function ShowArenaFramesTest()
    -- Display arena frames even if not in arena
    local arenaFrames = _G["ArenaEnemyFrames"]
    if arenaFrames then
        arenaFrames:Show()
    end
    
    for i = 1, MAX_ARENA_ENEMIES do
        local frame = _G["ArenaEnemyFrame" .. i]
        if frame then
            frame:Show()
        end
    end
end

local function HideArenaFramesTest()
    -- Hide frames when not in arena
    for i = 1, MAX_ARENA_ENEMIES do
        local frame = _G["ArenaEnemyFrame" .. i]
        if frame and not UnitExists("arena" .. i) then
            frame:Hide()
        end
    end
end

-- ===============================================================
-- STYLING FUNCTIONS
-- ===============================================================

-- Get texture coordinates for arena frame elements (same as party)
local function GetArenaCoords(type)
    if type == "background" then
        return 0.480469, 0.949219, 0.222656, 0.414062
    elseif type == "flash" then
        return 0.480469, 0.925781, 0.453125, 0.636719
    elseif type == "status" then
        return 0.00390625, 0.472656, 0.453125, 0.644531
    end
    return 0, 1, 0, 1
end

-- Get power bar texture for arena
local function GetArenaPowerBarTexture(unit)
    if not unit or not UnitExists(unit) then
        return TEXTURES.manaBar
    end

    local powerType = UnitPowerType(unit)
    if powerType == 0 then -- MANA
        return TEXTURES.manaBar
    elseif powerType == 1 then -- RAGE
        return TEXTURES.rageBar
    elseif powerType == 2 then -- FOCUS
        return TEXTURES.focusBar
    elseif powerType == 3 then -- ENERGY
        return TEXTURES.energyBar
    elseif powerType == 6 then -- RUNIC_POWER
        return TEXTURES.runicPowerBar
    else
        return TEXTURES.manaBar
    end
end

-- Style individual arena enemy frame (similar to party frames)
local function StyleArenaEnemyFrame(frameIndex)
    local frameName = "ArenaEnemyFrame" .. frameIndex
    local frame = _G[frameName]
    
    if not frame then
        return
    end

    local config = GetConfig()
    local generalScale = (addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.scale) or 1
    local individualScale = config.scale or 1.0
    local scale = generalScale * individualScale
    local unit = "arena" .. frameIndex
    
    -- Apply scale
    frame:SetScale(scale)

    -- Position relative to anchor (like party frames)
    if ArenaFrames.anchor and not InCombatLockdown() then
        frame:ClearAllPoints()
        local yOffset = (frameIndex - 1) * -70 -- Stack vertically with 70px separation
        frame:SetPoint("TOPLEFT", ArenaFrames.anchor, "TOPLEFT", 0, yOffset)
    end

    -- Hide default background
    local bg = _G[frameName .. "Background"]
    if bg then
        bg:Hide()
    end

    -- Hide default texture
    local texture = _G[frameName .. "Texture"]
    if texture then
        texture:SetTexture()
        texture:Hide()
    end

    -- Health bar (like party frames)
    local healthBar = _G[frameName .. "HealthBar"]
    if healthBar and not InCombatLockdown() then
        healthBar:SetStatusBarTexture(TEXTURES.healthBar)
        healthBar:SetSize(71, 10)
        healthBar:ClearAllPoints()
        healthBar:SetPoint('TOPLEFT', 44, -19)
        healthBar:SetFrameLevel(frame:GetFrameLevel())
        healthBar:SetStatusBarColor(1, 1, 1, 1)

        -- Apply class color if enabled
        if config.classcolor and UnitIsPlayer(unit) then
            local healthTexture = healthBar:GetStatusBarTexture()
            if healthTexture then
                healthTexture:SetTexture(TEXTURES.healthBarStatus)
                local _, class = UnitClass(unit)
                local color = RAID_CLASS_COLORS[class]
                if color then
                    healthTexture:SetVertexColor(color.r, color.g, color.b, 1)
                else
                    healthTexture:SetVertexColor(1, 1, 1, 1)
                end
            end
        end

        -- Hook health bar updates for clipping
        if not healthBar.NozdorUI_Setup then
            hooksecurefunc(healthBar, "SetValue", function(self)
                local texture = self:GetStatusBarTexture()
                if texture then
                    local min, max = self:GetMinMaxValues()
                    local current = self:GetValue()
                    if max > 0 and current then
                        texture:SetTexCoord(0, current / max, 0, 1)
                    end
                end
            end)
            healthBar.NozdorUI_Setup = true
        end
    end

    -- Power bar (like party frames)
    local powerBar = _G[frameName .. "ManaBar"]
    if powerBar and not InCombatLockdown() then
        local powerTexturePath = GetArenaPowerBarTexture(unit)
        powerBar:SetStatusBarTexture(powerTexturePath)
        powerBar:SetSize(74, 6.5)
        powerBar:ClearAllPoints()
        powerBar:SetPoint('TOPLEFT', 41, -30.5)
        powerBar:SetFrameLevel(frame:GetFrameLevel())
        powerBar:SetStatusBarColor(1, 1, 1, 1)

        -- Hook power bar updates for clipping
        if not powerBar.NozdorUI_Setup then
            hooksecurefunc(powerBar, "SetValue", function(self)
                local texture = self:GetStatusBarTexture()
                if texture then
                    local min, max = self:GetMinMaxValues()
                    local current = self:GetValue()
                    if max > 0 and current then
                        texture:SetTexCoord(0, current / max, 0, 1)
                    end
                end
            end)
            powerBar.NozdorUI_Setup = true
        end
    end

    -- Portrait styling (like party frames)
    local portrait = _G[frameName .. "Portrait"]
    if portrait then
        -- Ensure portrait is visible and properly configured
        portrait:Show()
        portrait:SetAlpha(1.0)
        portrait:SetVertexColor(1, 1, 1, 1) -- Reset any color modifications
        if not InCombatLockdown() then
            portrait:ClearAllPoints()
            portrait:SetPoint('TOPLEFT', 2, -2)
            portrait:SetSize(40, 40)
        end
        -- Force portrait update - always try to update
        if UnitExists(unit) then
            SetPortraitTexture(portrait, unit)
            -- Also try SetPortraitToUnit if available
            if portrait.SetPortraitToUnit then
                portrait:SetPortraitToUnit(unit)
            end
        end
        -- Ensure portrait is visible and on correct layer
        portrait:SetDrawLayer('ARTWORK', 4)
        -- Make sure portrait is not hidden by parent
        portrait:SetParent(frame)
    end

    -- Name styling (like party frames)
    local name = _G[frameName .. "Name"] or _G[frameName .. "TextureFrameName"]
    if name then
        name:Show()
        name:SetFont("Fonts\\FRIZQT__.TTF", 10)
        name:SetShadowOffset(1, -1)
        name:SetTextColor(1, 0.82, 0, 1) -- Yellow like party frames

        if not InCombatLockdown() then
            name:ClearAllPoints()
            name:SetPoint('TOPLEFT', 46, -5)
            name:SetSize(57, 12)
        end
    end

    -- Flash setup (like party frames)
    local flash = _G[frameName .. "Flash"]
    if flash then
        flash:SetSize(114, 47)
        flash:SetTexture(TEXTURES.frame)
        flash:SetTexCoord(GetArenaCoords("flash"))
        flash:SetPoint('TOPLEFT', 2, -2)
        flash:SetVertexColor(1, 0, 0, 1)
        flash:SetDrawLayer('ARTWORK', 5)
    end

    -- Create background and border (like party frames)
    if not frame.NozdorUIStyled then
        -- Background (behind)
        local background = frame:CreateTexture(nil, 'BACKGROUND', nil, 3)
        background:SetTexture(TEXTURES.frame)
        background:SetTexCoord(GetArenaCoords("background"))
        background:SetSize(120, 49)
        background:SetPoint('TOPLEFT', 1, -2)

        -- Border (above everything) - with forced framelevel
        local border = frame:CreateTexture(nil, 'ARTWORK', nil, 10)
        border:SetTexture(TEXTURES.border)
        border:SetTexCoord(0, 1, 0, 1) -- Full texture for border
        border:SetSize(128, 64)
        border:SetPoint('TOPLEFT', 1, -2)
        border:SetVertexColor(1, 1, 1, 1)

        -- Force the border to have a higher framelevel
        local borderFrame = CreateFrame("Frame", nil, frame)
        borderFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
        borderFrame:SetAllPoints(frame)
        border:SetParent(borderFrame)
        frame.NozdorUIBorderFrame = borderFrame -- Store for later use

        -- Move texts to the border frame so they are above
        if name then
            name:SetParent(borderFrame)
            name:SetDrawLayer('OVERLAY', 11)
        end

        local healthText = _G[frameName .. "HealthBarText"]
        if healthText then
            healthText:SetParent(borderFrame)
            healthText:SetDrawLayer('OVERLAY', 11)
            healthText:ClearAllPoints()
            healthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
            healthText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            healthText:SetTextColor(1, 1, 1, 1)
        end

        local manaText = _G[frameName .. "ManaBarText"]
        if manaText then
            manaText:SetParent(borderFrame)
            manaText:SetDrawLayer('OVERLAY', 11)
            manaText:ClearAllPoints()
            manaText:SetPoint("CENTER", powerBar, "CENTER", 0, 0)
            manaText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            manaText:SetTextColor(1, 1, 1, 1)
        end

        -- Create class icon (semi-transparent, above everything)
        -- Use borderFrame to ensure it's above everything
        local classIcon = frame.NozdorUIBorderFrame:CreateTexture(nil, 'OVERLAY', nil, 20)
        classIcon:SetSize(32, 32)
        classIcon:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -2, -2)
        classIcon:SetAlpha(0.6) -- Semi-transparent
        classIcon:Hide()
        frame.NozdorUIClassIcon = classIcon

        frame.NozdorUIStyled = true
    end

    -- Hide any class icons created by other addons/scripts
    -- Search for all textures on the frame that might be class icons
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region:GetObjectType() == "Texture" then
            local texture = region:GetTexture()
            if texture and texture:find("UI-Classes-Circles") then
                -- Check if it's not our icon
                if region ~= frame.NozdorUIClassIcon then
                    region:Hide()
                    -- Store reference to prevent it from showing again
                    if not frame.NozdorUI_HiddenClassIcons then
                        frame.NozdorUI_HiddenClassIcons = {}
                    end
                    table.insert(frame.NozdorUI_HiddenClassIcons, region)
                end
            end
        end
    end
    
    -- Also check child frames
    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())
        if child then
            for j = 1, child:GetNumRegions() do
                local region = select(j, child:GetRegions())
                if region and region:GetObjectType() == "Texture" then
                    local texture = region:GetTexture()
                    if texture and texture:find("UI-Classes-Circles") then
                        if region ~= frame.NozdorUIClassIcon then
                            region:Hide()
                            if not frame.NozdorUI_HiddenClassIcons then
                                frame.NozdorUI_HiddenClassIcons = {}
                            end
                            table.insert(frame.NozdorUI_HiddenClassIcons, region)
                        end
                    end
                end
            end
        end
    end
    
    -- Update our class icon
    if frame.NozdorUIClassIcon and UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if class then
            local classIconPath = "Interface\\TargetingFrame\\UI-Classes-Circles"
            local classCoords = CLASS_ICON_TCOORDS[class]
            if classCoords then
                frame.NozdorUIClassIcon:SetTexture(classIconPath)
                frame.NozdorUIClassIcon:SetTexCoord(unpack(classCoords))
                frame.NozdorUIClassIcon:Show()
            end
        else
            frame.NozdorUIClassIcon:Hide()
        end
    elseif frame.NozdorUIClassIcon then
        frame.NozdorUIClassIcon:Hide()
    end

    -- Style casting bar border
    local castingBar = _G[frameName .. "CastingBar"]
    if castingBar then
        -- Ensure casting bar has border (like TargetFrame)
        local castBorder = _G[frameName .. "CastingBarBorder"]
        if castBorder then
            -- Style the existing border
            castBorder:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border-Small")
            castBorder:SetWidth(197)
            castBorder:SetHeight(49)
            castBorder:ClearAllPoints()
            castBorder:SetPoint("TOP", frame, "TOP", 0, 20)
            castBorder:Show()
            castBorder:SetAlpha(1.0)
            castBorder:SetDrawLayer('ARTWORK', 2)
        else
            -- Create border if it doesn't exist
            if not castingBar.NozdorUIBorder then
                local border = castingBar:CreateTexture(nil, 'ARTWORK', nil, 2)
                border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border-Small")
                border:SetWidth(197)
                border:SetHeight(49)
                border:ClearAllPoints()
                border:SetPoint("TOP", frame, "TOP", 0, 20)
                border:Show()
                castingBar.NozdorUIBorder = border
            else
                castingBar.NozdorUIBorder:Show()
            end
        end
        
        -- Hook casting bar show/hide to ensure border is always visible
        if not castingBar.NozdorUI_Hooked then
            local originalShow = castingBar.Show
            castingBar.Show = function(self, ...)
                originalShow(self, ...)
                if castBorder then
                    castBorder:Show()
                elseif castingBar.NozdorUIBorder then
                    castingBar.NozdorUIBorder:Show()
                end
            end
            castingBar.NozdorUI_Hooked = true
        end
    end

    -- Hide arena pet frames (they overlap with main frames)
    local petFrame = _G[frameName .. "PetFrame"]
    if petFrame then
        petFrame:Hide()
        -- Hook to prevent it from showing
        if not petFrame.NozdorUI_Hooked then
            local originalShow = petFrame.Show
            petFrame.Show = function(self, ...)
                -- Don't show pet frame - it overlaps
                return
            end
            petFrame.NozdorUI_Hooked = true
        end
    end
    
    -- Also check for pet frame by alternative name
    local petFrameAlt = _G["ArenaEnemyPetFrame" .. frameIndex]
    if petFrameAlt then
        petFrameAlt:Hide()
        if not petFrameAlt.NozdorUI_Hooked then
            local originalShow = petFrameAlt.Show
            petFrameAlt.Show = function(self, ...)
                return
            end
            petFrameAlt.NozdorUI_Hooked = true
        end
    end
    
    -- Mark as styled
    ArenaFrames.styledFrames[frameIndex] = true
end

-- Style all arena enemy frames
local function StyleAllArenaFrames()
    local arenaFrames = _G["ArenaEnemyFrames"]
    if not arenaFrames then
        return
    end

    -- Apply widget position
    if ArenaFrames.anchor then
        ApplyWidgetPosition()
    end

    -- Style each frame
    for i = 1, MAX_ARENA_ENEMIES do
        StyleArenaEnemyFrame(i)
    end
end

-- ===============================================================
-- UPDATE SETTINGS FUNCTION (like party.lua)
-- ===============================================================

function ArenaFrames:UpdateSettings()
    local config = GetConfig()
    
    if ArenaFrames.anchor then
        ApplyWidgetPosition()
    end

    -- Update each frame
    for i = 1, MAX_ARENA_ENEMIES do
        local frame = _G["ArenaEnemyFrame" .. i]
        if frame then
            local generalScale = (addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.scale) or 1
            local individualScale = config.scale or 1.0
            frame:SetScale(generalScale * individualScale)
            
            -- Reposition relative to anchor
            if ArenaFrames.anchor and not InCombatLockdown() then
                frame:ClearAllPoints()
                local yOffset = (i - 1) * -70
                frame:SetPoint("TOPLEFT", ArenaFrames.anchor, "TOPLEFT", 0, yOffset)
            end
        end
    end
end

-- ===============================================================
-- CENTRALIZED SYSTEM SUPPORT FUNCTIONS
-- ===============================================================

function ArenaFrames:LoadDefaultSettings()
    -- Ensure configuration exists in widgets
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end

    if not addon.db.profile.widgets.arena then
        addon.db.profile.widgets.arena = {
            anchor = "TOPRIGHT",
            posX = -90,
            posY = -240
        }
    end

    -- Ensure configuration exists in unitframe
    if not addon.db.profile.unitframe then
        addon.db.profile.unitframe = {}
    end

    if not addon.db.profile.unitframe.arena then
        addon.db.profile.unitframe.arena = {
            enabled = true,
            classcolor = false,
            breakUpLargeNumbers = true,
            textFormat = 'both',
            showHealthTextAlways = true,
            showManaTextAlways = false,
            scale = 1.0
        }
    end
end

function ArenaFrames:UpdateWidgets()
    ApplyWidgetPosition()
    -- Reposition all arena frames relative to the updated anchor
    if not InCombatLockdown() then
        for i = 1, MAX_ARENA_ENEMIES do
            local frame = _G["ArenaEnemyFrame" .. i]
            if frame and ArenaFrames.anchor then
                frame:ClearAllPoints()
                local yOffset = (i - 1) * -70
                frame:SetPoint("TOPLEFT", ArenaFrames.anchor, "TOPLEFT", 0, yOffset)
            end
        end
    end
end

-- ===============================================================
-- INITIALIZATION FOR EDITOR
-- ===============================================================

local function InitializeArenaFramesForEditor()
    if ArenaFrames.initialized then
        return
    end

    -- Create anchor frame
    CreateArenaAnchorFrame()

    -- Always ensure configuration exists
    ArenaFrames:LoadDefaultSettings()

    -- Apply initial position
    ApplyWidgetPosition()

    -- Register with centralized system
    if addon and addon.RegisterEditableFrame then
        addon:RegisterEditableFrame({
            name = "arena",
            frame = ArenaFrames.anchor,
            blizzardFrame = _G["ArenaEnemyFrames"],
            configPath = {"widgets", "arena"},
            showTest = ShowArenaFramesTest,
            hideTest = HideArenaFramesTest,
            hasTarget = ShouldArenaFramesBeVisible
        })
    end

    ArenaFrames.initialized = true
end

-- ===============================================================
-- EVENT HANDLING
-- ===============================================================

-- Helper function for delayed execution (compatible with WoW 3.3.5a)
local function DelayCall(delay, func)
    local frame = CreateFrame("Frame")
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= delay then
            func()
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- Hook into arena events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
eventFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
eventFrame:RegisterEvent("UNIT_FACTION")
eventFrame:SetScript("OnEvent", function(self, event, addonName, unit)
    if event == "ADDON_LOADED" and addonName == "Blizzard_ArenaUI" then
        -- Wait a bit for frames to be created
        DelayCall(0.1, function()
            StyleAllArenaFrames()
        end)
    elseif event == "ARENA_OPPONENT_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        DelayCall(0.1, function()
            StyleAllArenaFrames()
        end)
    elseif (event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_NAME_UPDATE") and unit then
        -- Update portrait and class icon for specific arena frame
        local arenaIndex = unit:match("arena(%d+)")
        if arenaIndex then
            local frameIndex = tonumber(arenaIndex)
            if frameIndex and frameIndex >= 1 and frameIndex <= MAX_ARENA_ENEMIES then
                DelayCall(0.05, function()
                    StyleArenaEnemyFrame(frameIndex)
                end)
            end
        end
    elseif event == "UNIT_CLASSIFICATION_CHANGED" or event == "UNIT_FACTION" then
        -- Update class icon when unit classification changes
        if unit then
            local arenaIndex = unit:match("arena(%d+)")
            if arenaIndex then
                local frameIndex = tonumber(arenaIndex)
                if frameIndex and frameIndex >= 1 and frameIndex <= MAX_ARENA_ENEMIES then
                    DelayCall(0.05, function()
                        StyleArenaEnemyFrame(frameIndex)
                    end)
                end
            end
        end
    end
end)

-- Periodic portrait update to ensure portraits are visible
local portraitPeriodicFrame = CreateFrame("Frame")
local portraitUpdateElapsed = 0
portraitPeriodicFrame:SetScript("OnUpdate", function(self, elapsed)
    portraitUpdateElapsed = portraitUpdateElapsed + elapsed
    -- Update portraits every 0.3 seconds (more frequent)
    if portraitUpdateElapsed >= 0.3 then
        portraitUpdateElapsed = 0
        for i = 1, MAX_ARENA_ENEMIES do
            local frame = _G["ArenaEnemyFrame" .. i]
            if frame then
                local unit = "arena" .. i
                if UnitExists(unit) then
                    local portrait = _G["ArenaEnemyFrame" .. i .. "Portrait"]
                    if portrait then
                        -- Force portrait to be visible
                        portrait:Show()
                        portrait:SetAlpha(1.0)
                        -- Try to update portrait - this will work when unit is in range
                        SetPortraitTexture(portrait, unit)
                        -- Also try alternative method
                        if portrait.SetPortraitToUnit then
                            portrait:SetPortraitToUnit(unit)
                        end
                    end
                end
            end
        end
    end
end)

-- Hook ArenaEnemyFrame_UpdatePet to hide pets
if not ArenaFrames.petHookInstalled then
    -- Try to hook the function if it exists (it may be loaded later)
    local function HookPetUpdate()
        if _G.ArenaEnemyFrame_UpdatePet then
            hooksecurefunc("ArenaEnemyFrame_UpdatePet", function(frame, index)
                if frame then
                    local frameName = frame:GetName()
                    if frameName then
                        local petFrame = _G[frameName .. "PetFrame"]
                        if petFrame then
                            petFrame:Hide()
                        end
                    end
                    -- Also try alternative names
                    local petFrameAlt = _G["ArenaEnemyPetFrame" .. (index or 1)]
                    if petFrameAlt then
                        petFrameAlt:Hide()
                    end
                end
            end)
            return true
        end
        return false
    end
    
    -- Try immediately
    if not HookPetUpdate() then
        -- If not available, try after Blizzard_ArenaUI loads
        local hookFrame = CreateFrame("Frame")
        hookFrame:RegisterEvent("ADDON_LOADED")
        hookFrame:SetScript("OnEvent", function(self, event, addonName)
            if addonName == "Blizzard_ArenaUI" then
                DelayCall(0.1, function()
                    HookPetUpdate()
                end)
                self:UnregisterAllEvents()
            end
        end)
    end
    
    ArenaFrames.petHookInstalled = true
end

-- Also periodically hide any pet frames that might appear
local petHideFrame = CreateFrame("Frame")
petHideFrame:SetScript("OnUpdate", function(self, elapsed)
    for i = 1, MAX_ARENA_ENEMIES do
        local petFrame = _G["ArenaEnemyFrame" .. i .. "PetFrame"]
        if petFrame and petFrame:IsShown() then
            petFrame:Hide()
        end
        local petFrameAlt = _G["ArenaEnemyPetFrame" .. i]
        if petFrameAlt and petFrameAlt:IsShown() then
            petFrameAlt:Hide()
        end
    end
end)

-- Initialize everything in correct order
InitializeArenaFramesForEditor() -- First: register with centralized system
StyleAllArenaFrames() -- Second: visual properties and positioning

-- Listener for when the addon is fully loaded
local readyFrame = CreateFrame("Frame")
readyFrame:RegisterEvent("ADDON_LOADED")
readyFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "NozdorUI" then
        -- Apply settings after the addon is fully loaded
        if ArenaFrames and ArenaFrames.UpdateSettings then
            ArenaFrames:UpdateSettings()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Export for options.lua refresh functions
function addon:RefreshArenaFrames()
    if ArenaFrames and ArenaFrames.UpdateSettings then
        ArenaFrames:UpdateSettings()
    end
end
