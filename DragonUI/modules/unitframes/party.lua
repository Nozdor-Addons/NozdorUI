-- ===============================================================
-- NOZDORUI PARTY FRAMES MODULE
-- ===============================================================
-- Get addon reference - either from XML parameter or global
local addon = select(2, ...);

-- ===============================================================
-- EARLY EXIT CHECK
-- ===============================================================
-- Simplified: Only check if addon.db exists, not specifically unitframe.party
if not addon or not addon.db then
    return -- Exit early if database not ready
end

-- ===============================================================
-- IMPORTS AND GLOBALS
-- ===============================================================

-- Cache globals and APIs
local _G = _G
local unpack = unpack
local select = select
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitName, UnitClass = UnitName, UnitClass
local UnitExists, UnitIsConnected = UnitExists, UnitIsConnected
local UnitInRange, UnitIsDeadOrGhost = UnitInRange, UnitIsDeadOrGhost
local MAX_PARTY_MEMBERS = MAX_PARTY_MEMBERS or 4

-- ===============================================================
-- MODULE NAMESPACE AND STORAGE
-- ===============================================================

-- Module namespace
local PartyFrames = {}
addon.PartyFrames = PartyFrames

PartyFrames.textElements = {}
PartyFrames.anchor = nil
PartyFrames.initialized = false

-- ===============================================================
-- CONSTANTS AND CONFIGURATION
-- ===============================================================

-- Texture paths for our custom party frames
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

-- ===============================================================
-- CENTRALIZED SYSTEM INTEGRATION
-- ===============================================================

-- Create auxiliary frame for anchoring (similar to target.lua)
local function CreatePartyAnchorFrame()
    if PartyFrames.anchor then
        return PartyFrames.anchor
    end

    -- Use centralized function from core.lua
    PartyFrames.anchor = addon.CreateUIFrame(120, 200, "party")

    -- Customize text for party frames
    if PartyFrames.anchor.editorText then
        PartyFrames.anchor.editorText:SetText("Рамки группы")
    end

    return PartyFrames.anchor
end

-- Store original position for CompactRaidFrameManager repositioning
local originalPartyPosition = {
    anchor = nil,
    posX = nil,
    posY = nil,
    offsetApplied = false
}

-- Function to apply position from widgets (similar to target.lua)
local function ApplyWidgetPosition(skipSave)
    skipSave = skipSave or false
    if not PartyFrames.anchor then
        return
    end

    -- Ensure configuration exists
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets then
        return
    end

    local widgetConfig = addon.db.profile.widgets.party

    if widgetConfig and widgetConfig.posX and widgetConfig.posY then
        -- Use saved anchor, not always TOPLEFT
        local anchor = widgetConfig.anchor or "TOPLEFT"
        
        -- Save original position if not already saved
        if not skipSave and not originalPartyPosition.offsetApplied then
            originalPartyPosition.anchor = anchor
            originalPartyPosition.posX = widgetConfig.posX
            originalPartyPosition.posY = widgetConfig.posY
        end
        
        PartyFrames.anchor:ClearAllPoints()
        PartyFrames.anchor:SetPoint(anchor, UIParent, anchor, widgetConfig.posX, widgetConfig.posY)
    else
        -- Create default configuration if it doesn't exist
        if not addon.db.profile.widgets.party then
            addon.db.profile.widgets.party = {
                anchor = "TOPLEFT",
                posX = 14,
                posY = -200
            }
        end
        
        -- Save original position if not already saved
        if not skipSave and not originalPartyPosition.offsetApplied then
            originalPartyPosition.anchor = "TOPLEFT"
            originalPartyPosition.posX = 14
            originalPartyPosition.posY = -200
        end
        
        PartyFrames.anchor:ClearAllPoints()
        PartyFrames.anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 14, -200)
    end
end

-- Function to check if party frame overlaps with CompactRaidFrameManager
local function DoesPartyFrameOverlapManager(manager)
    if not PartyFrames.anchor or not manager then
        return false
    end
    
    -- Convert to screen coordinates for comparison
    local partyLeft, partyBottom, partyWidth, partyHeight = PartyFrames.anchor:GetRect()
    local managerLeft, managerBottom, managerWidth, managerHeight = manager:GetRect()
    
    if not partyLeft or not managerLeft then
        return false
    end
    
    -- Check if party frame is to the left of manager and overlaps horizontally
    -- Manager typically starts at left edge, party frame should be shifted if it's overlapping
    local partyRight = partyLeft + (partyWidth or 0)
    local managerRight = managerLeft + (managerWidth or 0)
    
    -- Check horizontal overlap (party frame right edge overlaps with manager left edge)
    -- Also check if party frame is positioned where manager would expand
    local horizontalOverlap = partyRight > managerLeft - 5 and partyLeft < managerRight + 5
    
    -- Check vertical overlap (if party frame is in the same vertical space)
    local partyTop = partyBottom + (partyHeight or 0)
    local managerTop = managerBottom + (managerHeight or 0)
    local verticalOverlap = not (partyTop < managerBottom or partyBottom > managerTop)
    
    return horizontalOverlap and verticalOverlap
end

-- Function to adjust party frame position when CompactRaidFrameManager is shown
local function AdjustPartyFrameForCompactRaidManager()
    if not PartyFrames.anchor then
        return
    end
    
    -- NEVER adjust position in editor mode - allow free movement
    if addon.EditorMode and addon.EditorMode:IsActive() then
        return
    end
    
    -- Don't adjust during combat lockdown
    if InCombatLockdown() then
        return
    end
    
    -- CRITICAL: Don't adjust anything if in raid - let CompactRaidFrameManager handle everything
    -- This prevents interference with raid group visibility controls
    if IsInRaid() then
        return
    end
    
    local manager = _G["CompactRaidFrameManager"]
    if not manager then
        -- Manager doesn't exist, restore original position
        if originalPartyPosition.offsetApplied then
            originalPartyPosition.offsetApplied = false
            ApplyWidgetPosition(true)
        end
        return
    end
    
    -- Check if CompactRaidFrameManager is shown
    local isManagerShown = manager:IsShown()
    if not isManagerShown then
        -- Manager is hidden, restore original position
        if originalPartyPosition.offsetApplied then
            originalPartyPosition.offsetApplied = false
            ApplyWidgetPosition(true) -- Skip saving when restoring
        end
        return
    end
    
    -- Check if party frame actually overlaps with manager
    local overlaps = DoesPartyFrameOverlapManager(manager)
    
    if overlaps then
        -- Manager is visible and party frame overlaps, shift party frame to the right
        if not originalPartyPosition.offsetApplied then
            -- Save original position if not saved yet
            local widgetConfig = addon.db.profile.widgets.party
            if widgetConfig and widgetConfig.posX and widgetConfig.posY then
                originalPartyPosition.anchor = widgetConfig.anchor or "TOPLEFT"
                originalPartyPosition.posX = widgetConfig.posX
                originalPartyPosition.posY = widgetConfig.posY
            else
                -- Get current position
                local point, relativeTo, relativePoint, xOfs, yOfs = PartyFrames.anchor:GetPoint()
                if point then
                    originalPartyPosition.anchor = point
                    originalPartyPosition.posX = xOfs or 14
                    originalPartyPosition.posY = yOfs or -200
                else
                    originalPartyPosition.anchor = "TOPLEFT"
                    originalPartyPosition.posX = 14
                    originalPartyPosition.posY = -200
                end
            end
            originalPartyPosition.offsetApplied = true
        end
        
        -- Match Blizzard's behavior exactly: attach to TOPRIGHT of manager with offset
        -- CompactRaidFrameManager_AttachPartyFrames uses: SetPoint("TOPLEFT", manager, "TOPRIGHT", 0, -20)
        PartyFrames.anchor:ClearAllPoints()
        PartyFrames.anchor:SetPoint("TOPLEFT", manager, "TOPRIGHT", 0, -20)
    else
        -- No overlap, restore original position if it was shifted
        if originalPartyPosition.offsetApplied then
            originalPartyPosition.offsetApplied = false
            ApplyWidgetPosition(true) -- Skip saving when restoring
        end
    end
end

-- Functions required by the centralized system
function PartyFrames:LoadDefaultSettings()
    -- Ensure configuration exists in widgets
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end

    if not addon.db.profile.widgets.party then
        addon.db.profile.widgets.party = {
            anchor = "TOPLEFT",
            posX = 14,
            posY = -200
        }
    end

    -- Ensure configuration exists in unitframe
    if not addon.db.profile.unitframe then
        addon.db.profile.unitframe = {}
    end

    if not addon.db.profile.unitframe.party then
        addon.db.profile.unitframe.party = {
            enabled = true,
            classcolor = false,
            textFormat = 'both',
            breakUpLargeNumbers = true,
            showHealthTextAlways = true, -- HP всегда видно
            showManaTextAlways = false,
            orientation = 'vertical',
            padding = 10,
            scale = 1.0,
            override = false,
            anchor = 'TOPLEFT',
            anchorParent = 'TOPLEFT',
            x = 10,
            y = -200
        }
    end
end

function PartyFrames:UpdateWidgets()
    ApplyWidgetPosition()
    -- Reposition all party frames relative to the updated anchor
    -- But don't reposition if in raid and CompactRaidFrameManager is managing party frames
    local manager = _G["CompactRaidFrameManager"]
    local isInRaid = IsInRaid()
    local shouldUseCompactRaid = manager and manager.container and manager.container.enabled and isInRaid
    
    if not shouldUseCompactRaid and not InCombatLockdown() then
        for i = 1, MAX_PARTY_MEMBERS do
            local frame = _G['PartyMemberFrame' .. i]
            if frame and PartyFrames.anchor then
                frame:ClearAllPoints()
                local yOffset = (i - 1) * -70
                frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", 0, yOffset)
            end
        end
    end
end

-- Function to check if party frames should be visible
local function ShouldPartyFramesBeVisible()
    return GetNumPartyMembers() > 0
end

-- Test functions for the editor
local function ShowPartyFramesTest()
    -- Display party frames even if not in a group
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            frame:Show()
        end
    end
end

local function HidePartyFramesTest()
    -- Hide empty frames when not in a party
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame and not UnitExists("party" .. i) then
            frame:Hide()
        end
    end
end

-- ===============================================================
-- HELPER FUNCTIONS
-- ===============================================================

-- Get settings helper
local function GetSettings()
    -- Perform a robust check with default values
    if not addon.db or not addon.db.profile then
        return {
            scale = 1.0,
            classcolor = false,
            breakUpLargeNumbers = true
        }
    end

    local settings = addon.db.profile.unitframe and addon.db.profile.unitframe.party

    -- If configuration doesn't exist, create it with defaults
    if not settings then
        if not addon.db.profile.unitframe then
            addon.db.profile.unitframe = {}
        end

        addon.db.profile.unitframe.party = {
            enabled = true,
            classcolor = false,
            textFormat = 'both',
            breakUpLargeNumbers = true,
            showHealthTextAlways = true, -- HP всегда видно
            showManaTextAlways = false,
            orientation = 'vertical',
            padding = 10,
            scale = 1.0,
            override = false,
            anchor = 'TOPLEFT',
            anchorParent = 'TOPLEFT',
            x = 10,
            y = -200
        }
        settings = addon.db.profile.unitframe.party
    end
    
    return settings
end

-- Format numbers helper
local function FormatNumber(value)
    local settings = GetSettings()
    if not value or not settings then
        return "0"
    end

    if settings.breakUpLargeNumbers then
        if value >= 1000000 then
            return string.format("%.1fm", value / 1000000)
        elseif value >= 1000 then
            return string.format("%.1fk", value / 1000)
        end
    end
    return tostring(value)
end

-- Get class color helper
local function GetClassColor(unit)
    if not unit or not UnitExists(unit) then
        return 1, 1, 1
    end

    local _, class = UnitClass(unit)
    if class and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        return color.r, color.g, color.b
    end

    return 1, 1, 1
end

-- Get texture coordinates for party frame elements
local function GetPartyCoords(type)
    if type == "background" then
        return 0.480469, 0.949219, 0.222656, 0.414062
    elseif type == "flash" then
        return 0.480469, 0.925781, 0.453125, 0.636719
    elseif type == "status" then
        return 0.00390625, 0.472656, 0.453125, 0.644531
    end
    return 0, 1, 0, 1
end

-- New function: Get power bar texture
local function GetPowerBarTexture(unit)
    if not unit or not UnitExists(unit) then
        return TEXTURES.manaBar
    end

    local powerType = UnitPowerType(unit)

    -- In 3.3.5a types are numbers, not strings
    if powerType == 0 then -- MANA
        return TEXTURES.manaBar
    elseif powerType == 1 then -- RAGE
        return TEXTURES.rageBar
    elseif powerType == 2 then -- FOCUS
        return TEXTURES.focusBar
    elseif powerType == 3 then -- ENERGY
        return TEXTURES.energyBar
    elseif powerType == 6 then -- RUNIC_POWER (if it exists in 3.3.5a)
        return TEXTURES.runicPowerBar
    else
        return TEXTURES.manaBar -- Default
    end
end

-- ===============================================================
-- CLASS COLORS
-- ===============================================================

-- New function: Get class color for party member
local function GetPartyClassColor(partyIndex)
    local unit = "party" .. partyIndex
    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        return 1, 1, 1 -- White if not a player
    end

    local _, class = UnitClass(unit)
    if class and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        return color.r, color.g, color.b
    end

    return 1, 1, 1 -- White by default
end

-- New function: Update party health bar with class color
local function UpdatePartyHealthBarColor(partyIndex)
    if not partyIndex or partyIndex < 1 or partyIndex > 4 then
        return
    end

    local unit = "party" .. partyIndex
    if not UnitExists(unit) then
        return
    end

    local healthbar = _G['PartyMemberFrame' .. partyIndex .. 'HealthBar']
    if not healthbar then
        return
    end

    local settings = GetSettings()
    if not settings then
        return
    end

    local texture = healthbar:GetStatusBarTexture()
    if not texture then
        return
    end

    if settings.classcolor and UnitIsPlayer(unit) then
        -- Use constant instead of hardcoded string
        local statusTexturePath = TEXTURES.healthBarStatus
        if texture:GetTexture() ~= statusTexturePath then
            texture:SetTexture(statusTexturePath)
        end

        -- Apply class color
        local r, g, b = GetPartyClassColor(partyIndex)
        healthbar:SetStatusBarColor(r, g, b, 1)
    else
        -- Use constant instead of hardcoded string
        local normalTexturePath = TEXTURES.healthBar
        if texture:GetTexture() ~= normalTexturePath then
            texture:SetTexture(normalTexturePath)
        end

        -- White color (texture already has color)
        healthbar:SetStatusBarColor(1, 1, 1, 1)
    end
end
-- ===============================================================
-- SIMPLE BLIZZARD BUFF/DEBUFF REPOSITIONING
-- ===============================================================
local function RepositionBlizzardBuffs()
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            -- Move buffs and debuffs together
            for auraIndex = 1, 4 do
                local buff = _G['PartyMemberFrame' .. i .. 'Buff' .. auraIndex]
                local debuff = _G['PartyMemberFrame' .. i .. 'Debuff' .. auraIndex]

                if buff then
                    buff:ClearAllPoints()
                    buff:SetPoint('TOPLEFT', frame, 'TOPRIGHT', -5 + (auraIndex - 1) * 18, -5)
                    buff:SetSize(16, 16)
                end

                if debuff then
                    debuff:ClearAllPoints()
                    debuff:SetPoint('TOPLEFT', frame, 'TOPRIGHT', -5 + (auraIndex - 1) * 18, -22)
                    debuff:SetSize(16, 16)
                end
            end
        end
    end
end


-- ===============================================================
-- TEXT UPDATE SYSTEM (TAINT-FREE)
-- ===============================================================

-- Frame and variables for safe text updates
local updateFrame = CreateFrame("Frame")
local pendingUpdates = {}
local updateScheduled = false

-- Safe text update function
local function SafeUpdateTexts()
    for frameIndex, _ in pairs(pendingUpdates) do
        if PartyFrames.textElements[frameIndex] and PartyFrames.textElements[frameIndex].update then
            PartyFrames.textElements[frameIndex].update()
        end
    end

    -- Clear pending updates
    pendingUpdates = {}
    updateScheduled = false
    updateFrame:SetScript("OnUpdate", nil)
end

-- Schedule text update function (taint-free)
local function ScheduleTextUpdate(frameIndex)
    if not frameIndex then
        return
    end

    -- Mark frame for update
    pendingUpdates[frameIndex] = true

    -- If no update is scheduled, create one
    if not updateScheduled then
        updateScheduled = true
        -- Use OnUpdate with reasonable delay to prevent freezes (compatible with 3.3.5a)
        local elapsed = 0
        updateFrame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed >= 0.1 then -- 100ms delay (was 10ms - too frequent)
                SafeUpdateTexts()
                elapsed = 0
            end
        end)
    end
end
-- ===============================================================
-- DYNAMIC CLIPPING SYSTEM
-- ===============================================================

-- Setup dynamic texture clipping for health bars
local function SetupHealthBarClipping(frame)
    if not frame then
        return
    end

    local healthbar = _G[frame:GetName() .. 'HealthBar']
    if not healthbar or healthbar.NozdorUI_ClippingSetup then
        return
    end

    -- Hook SetValue for dynamic clipping and class color
    hooksecurefunc(healthbar, "SetValue", function(self, value)
        local frameIndex = frame:GetID()
        local unit = "party" .. frameIndex
        if not UnitExists(unit) then
            return
        end

        local texture = self:GetStatusBarTexture()
        if not texture then
            return
        end

        -- Apply class color first
        UpdatePartyHealthBarColor(frameIndex)

        -- Dynamic clipping: Only show the filled part of the texture
        local min, max = self:GetMinMaxValues()
        local current = value or self:GetValue()

        if max > 0 and current then
            local percentage = math.max(0, math.min(1, current / max)) -- Clamp between 0 and 1
            texture:SetTexCoord(0, percentage, 0, 1)
        else
            -- Safe default: show full texture
            texture:SetTexCoord(0, 1, 0, 1)
        end
        
        -- CRITICAL: Update health text
        UpdateHealthText(self, unit)
    end)

    healthbar.NozdorUI_ClippingSetup = true
end

-- Setup dynamic texture clipping for mana bars
local function SetupManaBarClipping(frame)
    if not frame then
        return
    end

    local manabar = _G[frame:GetName() .. 'ManaBar']
    if not manabar or manabar.NozdorUI_ClippingSetup then
        return
    end

    -- Hook SetValue for dynamic clipping
    hooksecurefunc(manabar, "SetValue", function(self, value)
        local unit = "party" .. frame:GetID()
        if not UnitExists(unit) then
            return
        end

        local texture = self:GetStatusBarTexture()
        if not texture then
            return
        end

        local min, max = self:GetMinMaxValues()
        local current = value or self:GetValue()

        if max > 0 and current then
            -- Dynamic clipping: Only show the filled part of the texture
            local percentage = math.max(0, math.min(1, current / max)) -- Clamp between 0 and 1
            
            -- CRITICAL: Update mana text
            UpdateManaText(self, unit)
            texture:SetTexCoord(0, percentage, 0, 1)
        else
            -- Safe default: show full texture
            texture:SetTexCoord(0, 1, 0, 1)
        end

        -- Update texture based on power type
        local powerTexture = GetPowerBarTexture(unit)
        texture:SetTexture(powerTexture)
        texture:SetVertexColor(1, 1, 1, 1)
    end)

    manabar.NozdorUI_ClippingSetup = true
end
-- ===============================================================
-- FRAME STYLING FUNCTIONS
-- ===============================================================

-- Main styling function for party frames
local function StylePartyFrames()
    local settings = GetSettings()
    if not settings then
        return
    end

    -- Create anchor frame if it doesn't exist
    CreatePartyAnchorFrame()

    -- Apply widget position
    ApplyWidgetPosition()

    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            -- Scale and texture setup
            local generalScale = (addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.scale) or 1
            local individualScale = settings.scale or 1
            frame:SetScale(generalScale * individualScale)
            
            -- Positioning relative to anchor
            -- Don't reposition if in raid and CompactRaidFrameManager is managing party frames
            local manager = _G["CompactRaidFrameManager"]
            local isInRaid = IsInRaid()
            local shouldUseCompactRaid = manager and manager.container and manager.container.enabled and isInRaid
            
            if not shouldUseCompactRaid and not InCombatLockdown() then
                frame:ClearAllPoints()
                local yOffset = (i - 1) * -70 -- Stack vertically with 70px separation
                frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", 0, yOffset)
            end

            -- Hide background
            local bg = _G[frame:GetName() .. 'Background']
            if bg then
                bg:Hide()
            end

            -- Hide default texture
            local texture = _G[frame:GetName() .. 'Texture']
            if texture then
                texture:SetTexture()
                texture:Hide()
            end

            -- Health bar
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            if healthbar and not InCombatLockdown() then
                healthbar:SetStatusBarTexture(TEXTURES.healthBar)
                healthbar:SetSize(71, 10)
                healthbar:ClearAllPoints()
                healthbar:SetPoint('TOPLEFT', 44, -19)
                healthbar:SetFrameLevel(frame:GetFrameLevel())
                healthbar:SetStatusBarColor(1, 1, 1, 1)

                -- Configure dynamic clipping with class color
                SetupHealthBarClipping(frame)

                -- Apply initial class color
                UpdatePartyHealthBarColor(i)
            end

            -- Replace mana bar setup (lines 192-199)
            local manabar = _G[frame:GetName() .. 'ManaBar']
            if manabar and not InCombatLockdown() then
                manabar:SetStatusBarTexture(TEXTURES.manaBar)
                manabar:SetSize(74, 6.5)
                manabar:ClearAllPoints()
                manabar:SetPoint('TOPLEFT', 41, -30.5)
                manabar:SetFrameLevel(frame:GetFrameLevel()) -- Same level as the frame
                manabar:SetStatusBarColor(1, 1, 1, 1)

                -- Configure dynamic clipping
                SetupManaBarClipping(frame)
            end

            -- Name styling
           local name = _G[frame:GetName() .. 'Name']
            if name then
                name:SetFont("Fonts\\FRIZQT__.TTF", 10)
                name:SetShadowOffset(1, -1)
                name:SetTextColor(1, 0.82, 0, 1) -- Yellow like the rest

                if not InCombatLockdown() then
                    name:ClearAllPoints()
                    name:SetPoint('TOPLEFT', 46, -5)
                    name:SetSize(57, 12)
                end
            end

            -- LEADER ICON STYLING
            local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
            if leaderIcon then -- Removed and not InCombatLockdown()
                leaderIcon:ClearAllPoints()
                leaderIcon:SetPoint('TOPLEFT', 42, 9) -- Custom position
                leaderIcon:SetSize(16, 16) -- Custom size (optional)
            end

            -- Master looter icon styling
            local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
            if masterLooterIcon then -- No combat restriction
                masterLooterIcon:ClearAllPoints()
                masterLooterIcon:SetPoint('TOPLEFT', 58, 20) -- Position next to leader icon
                masterLooterIcon:SetSize(16, 16) -- Custom size

            end

            -- Flash setup
            local flash = _G[frame:GetName() .. 'Flash']
            if flash then
                flash:SetSize(114, 47)
                flash:SetTexture(TEXTURES.frame)
                flash:SetTexCoord(GetPartyCoords("flash"))
                flash:SetPoint('TOPLEFT', 2, -2)
                flash:SetVertexColor(1, 0, 0, 1)
                flash:SetDrawLayer('ARTWORK', 5)
            end

            -- Create background and mark as styled
            if not frame.NozdorUIStyled then
                -- Background (behind)
                local background = frame:CreateTexture(nil, 'BACKGROUND', nil, 3)
                background:SetTexture(TEXTURES.frame)
                background:SetTexCoord(GetPartyCoords("background"))
                background:SetSize(120, 49)
                background:SetPoint('TOPLEFT', 1, -2)

                -- Border (above everything) - with forced framelevel
                local border = frame:CreateTexture(nil, 'ARTWORK', nil, 10)
                    border:SetTexture(TEXTURES.border)
                    border:SetTexCoord(GetPartyCoords("border"))
                    border:SetSize(128, 64)
                    border:SetPoint('TOPLEFT', 1, -2)
                    border:SetVertexColor(1, 1, 1, 1)

                -- Force the border to have a higher framelevel
                local borderFrame = CreateFrame("Frame", nil, frame)
                borderFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
                borderFrame:SetAllPoints(frame)
                border:SetParent(borderFrame)

                -- Move texts to the border frame so they are above
                local name = _G[frame:GetName() .. 'Name']
                local healthText = _G[frame:GetName() .. 'HealthBarText']
                local manaText = _G[frame:GetName() .. 'ManaBarText']
                local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
                local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
                local pvpIcon = _G[frame:GetName() .. 'PVPIcon']
                local statusIcon = _G[frame:GetName() .. 'StatusIcon']
                local blizzardRoleIcon = _G[frame:GetName() .. 'RoleIcon']
                local guideIcon = _G[frame:GetName() .. 'GuideIcon']
                -- Move texts without creating taint (only change parent)
                if name then
                    name:SetParent(borderFrame)
                    name:SetDrawLayer('OVERLAY', 11) -- Above the border
                end
                if healthText then
                    healthText:SetParent(borderFrame)
                    healthText:SetDrawLayer('OVERLAY', 11)
                end
                if manaText then
                    manaText:SetParent(borderFrame)
                    manaText:SetDrawLayer('OVERLAY', 11)
                end
                if leaderIcon then
                    leaderIcon:SetParent(borderFrame)
                    leaderIcon:SetDrawLayer('OVERLAY', 11)
                end
                if masterLooterIcon then
                    masterLooterIcon:SetParent(borderFrame)
                    masterLooterIcon:SetDrawLayer('OVERLAY', 11)
                end
                if pvpIcon then
                    pvpIcon:SetParent(borderFrame)
                    pvpIcon:SetDrawLayer('OVERLAY', 11)
                end
                if statusIcon then 
                    statusIcon:SetParent(borderFrame)
                    statusIcon:SetDrawLayer('OVERLAY', 11)
                end
                if blizzardRoleIcon then
                    blizzardRoleIcon:SetParent(borderFrame)
                    blizzardRoleIcon:SetDrawLayer('OVERLAY', 11)
                end
                if guideIcon then
                    guideIcon:SetParent(borderFrame)
                    guideIcon:SetDrawLayer('OVERLAY', 11)
                end

                frame.NozdorUIStyled = true
            end
            -- Reposition health and mana texts
            if healthbar then
                local healthText = _G[frame:GetName() .. 'HealthBarText']
                if healthText then
                    healthText:ClearAllPoints()
                    healthText:SetPoint("CENTER", healthbar, "CENTER", 0, 0) -- Centered on the bar
                    healthText:SetDrawLayer("OVERLAY", 10) -- Above the border
                    healthText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
                    healthText:SetTextColor(1, 1, 1, 1)
            end
            end

            if manabar then
                local manaText = _G[frame:GetName() .. 'ManaBarText']
                if manaText then
                    manaText:ClearAllPoints()
                    manaText:SetPoint("CENTER", manabar, "CENTER", 0, 0) -- Centered on the bar
                    manaText:SetDrawLayer("OVERLAY", 10) -- Above the border
                    manaText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
                    manaText:SetTextColor(1, 1, 1, 1)
                end
            end

            frame.NozdorUIStyled = true
        end
    end
end

-- ===============================================================
-- DISCONNECTED PLAYERS
-- ===============================================================
local function UpdateDisconnectedState(frame)
    if not frame then
        return
    end

    local unit = "party" .. frame:GetID()
    if not UnitExists(unit) then
        return
    end

    local isConnected = UnitIsConnected(unit)
    local healthbar = _G[frame:GetName() .. 'HealthBar']
    local manabar = _G[frame:GetName() .. 'ManaBar']
    local portrait = _G[frame:GetName() .. 'Portrait']
    local name = _G[frame:GetName() .. 'Name']

    if not isConnected then
        -- Disconnected member - apply gray effects
        if healthbar then
            healthbar:SetAlpha(0.3)
            healthbar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        end

        if manabar then
            manabar:SetAlpha(0.3)
            manabar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        end

        if portrait then
            portrait:SetVertexColor(0.5, 0.5, 0.5, 1)
        end

        if name then
            name:SetTextColor(0.6, 0.6, 0.6, 1)
        end

        -- Reposition icons so they don't get lost
        local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
        if leaderIcon then
            leaderIcon:ClearAllPoints()
            leaderIcon:SetPoint('TOPLEFT', 42, 9)
            leaderIcon:SetSize(16, 16)
        end

        local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
        if masterLooterIcon then
            masterLooterIcon:ClearAllPoints()
            masterLooterIcon:SetPoint('TOPLEFT', 58, 20)
            masterLooterIcon:SetSize(16, 16)
        end

    else
        -- Connected member - undo exactly what was done when disconnecting

        -- Restore transparencies (without taint)
        if healthbar then
            healthbar:SetAlpha(1.0) -- Normal opacity
            -- Restore correct color (class color or white)
            local frameIndex = frame:GetID()
            UpdatePartyHealthBarColor(frameIndex) -- Only updates color, does not recreate frame
        end

        if manabar then
            manabar:SetAlpha(1.0) -- Normal opacity
            manabar:SetStatusBarColor(1, 1, 1, 1) -- White as it should be
        end

        if portrait then
            portrait:SetVertexColor(1, 1, 1, 1) -- Normal color
        end

        if name then
            name:SetTextColor(1, 0.82, 0, 1) -- Normal yellow
        end

        -- Reposition icons (without recreating frames)
        local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
        if leaderIcon then
            leaderIcon:ClearAllPoints()
            leaderIcon:SetPoint('TOPLEFT', 42, 9)
            leaderIcon:SetSize(16, 16)
        end

        local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
        if masterLooterIcon then
            masterLooterIcon:ClearAllPoints()
            masterLooterIcon:SetPoint('TOPLEFT', 58, 20)
            masterLooterIcon:SetSize(16, 16)
        end
    end
end
-- ===============================================================
-- TEXT AND COLOR UPDATE FUNCTIONS
-- ===============================================================

-- Health text update function (taint-free) - UPDATED TO USE SETTINGS
local function UpdateHealthText(statusBar, unit)
    if not statusBar then
        return
    end
    
    local frame = statusBar:GetParent()
    if not frame then
        return
    end
    
    local frameName = frame:GetName()
    local frameIndex = frameName:match("PartyMemberFrame(%d+)")
    if not frameIndex then
        return
    end
    
    local partyUnit = "party" .. frameIndex
    if not UnitExists(partyUnit) or UnitIsDeadOrGhost(partyUnit) then
        local healthText = _G[frameName .. 'HealthBarText']
        if healthText then
            healthText:SetText("")
            healthText:Hide()
        end
        return
    end
    
    -- Get settings
    local settings = GetSettings()
    if not settings then
        return
    end
    
    -- Check if should show health text
    local shouldShow = settings.showHealthTextAlways
    if not shouldShow then
        -- Check hover
        shouldShow = statusBar:IsMouseOver()
    end
    
    local healthText = _G[frameName .. 'HealthBarText']
    if not healthText then
        return
    end
    
    if shouldShow then
        local current = UnitHealth(partyUnit) or 0
        local max = UnitHealthMax(partyUnit) or 1
        
        -- Use TextSystem to format text
        local formattedText = addon.TextSystem.FormatStatusText(
            current, 
            max, 
            settings.textFormat or 'both',
            settings.breakUpLargeNumbers or false,
            'party'
        )
        
        -- Update text based on format
        if type(formattedText) == "table" then
            -- Dual format (both): show percentage and current
            healthText:SetText((formattedText.left or "") .. " " .. (formattedText.right or ""))
        else
            -- Single format: show formatted text
            healthText:SetText(formattedText or "")
        end
        
        healthText:Show()
    else
        healthText:SetText("")
        healthText:Hide()
    end
end

-- Mana text update function (taint-free) - UPDATED TO USE SETTINGS
local function UpdateManaText(statusBar, unit)
    if not statusBar then
        return
    end
    
    local frame = statusBar:GetParent()
    if not frame then
        return
    end
    
    local frameName = frame:GetName()
    local frameIndex = frameName:match("PartyMemberFrame(%d+)")
    if not frameIndex then
        return
    end
    
    local partyUnit = "party" .. frameIndex
    if not UnitExists(partyUnit) or UnitIsDeadOrGhost(partyUnit) then
        local manaText = _G[frameName .. 'ManaBarText']
        if manaText then
            manaText:SetText("")
            manaText:Hide()
        end
        return
    end
    
    -- Get settings
    local settings = GetSettings()
    if not settings then
        return
    end
    
    -- Check if should show mana text
    local shouldShow = settings.showManaTextAlways
    if not shouldShow then
        -- Check hover
        shouldShow = statusBar:IsMouseOver()
    end
    
    local manaText = _G[frameName .. 'ManaBarText']
    if not manaText then
        return
    end
    
    if shouldShow then
        local current = UnitPower(partyUnit) or 0
        local max = UnitPowerMax(partyUnit) or 1
        
        -- Use TextSystem to format text
        local formattedText = addon.TextSystem.FormatStatusText(
            current, 
            max, 
            settings.textFormat or 'both',
            settings.breakUpLargeNumbers or false,
            'party'
        )
        
        -- Update text based on format
        if type(formattedText) == "table" then
            -- Dual format (both): show percentage and current
            manaText:SetText((formattedText.left or "") .. " " .. (formattedText.right or ""))
        else
            -- Single format: show formatted text
            manaText:SetText(formattedText or "")
        end
        
        manaText:Show()
    else
        manaText:SetText("")
        manaText:Hide()
    end
end

-- Update party colors function
local function UpdatePartyColors(frame)
    if not frame then
        return
    end

    local settings = GetSettings()
    if not settings then
        return
    end

    local unit = "party" .. frame:GetID()
    if not UnitExists(unit) then
        return
    end

    local healthbar = _G[frame:GetName() .. 'HealthBar']
    if healthbar and settings.classcolor then
        local r, g, b = GetClassColor(unit)
        healthbar:SetStatusBarColor(r, g, b)
    end
end

-- New function: Update mana bar texture
local function UpdateManaBarTexture(frame)
    if not frame then
        return
    end

    local unit = "party" .. frame:GetID()
    if not UnitExists(unit) then
        return
    end

    local manabar = _G[frame:GetName() .. 'ManaBar']
    if manabar then
        local powerTexture = GetPowerBarTexture(unit)
        manabar:SetStatusBarTexture(powerTexture)
        manabar:SetStatusBarColor(1, 1, 1, 1) -- Keep white
    end
end

-- ===============================================================
-- HOOK SETUP FUNCTION
-- ===============================================================

-- Setup all necessary hooks for party frames
local function SetupPartyHooks()
    -- Hook CompactRaidFrameManager visibility changes
    local function SetupCompactRaidFrameManagerHook()
        local manager = _G["CompactRaidFrameManager"]
        if manager then
            -- Hook the show/hide methods using HookScript to avoid breaking functionality
            -- Only adjust party frame position when not in raid, don't interfere with raid groups
            if not manager.hookedNozdorUIShowHide then
                manager:HookScript("OnShow", function()
                    -- Only adjust if not in raid (party frames adjustment)
                    if not IsInRaid() then
                C_Timer.After(0.1, function()
                    AdjustPartyFrameForCompactRaidManager()
                end)
            end
                end)
                manager:HookScript("OnHide", function()
                    -- Only adjust if not in raid (party frames adjustment)
                    if not IsInRaid() then
                C_Timer.After(0.05, function()
                    AdjustPartyFrameForCompactRaidManager()
                end)
                    end
                end)
                manager.hookedNozdorUIShowHide = true
            end
            
            -- Also hook the toggle button - this is the main entry point
            local toggleButton = _G["CompactRaidFrameManagerToggleButton"]
            if toggleButton then
                local originalOnClick = toggleButton:GetScript("OnClick")
                if originalOnClick then
                    toggleButton:SetScript("OnClick", function(self, button, down)
                        originalOnClick(self, button, down)
                        -- Only adjust if not in raid (party frames adjustment)
                        -- Don't interfere with raid group visibility controls
                        if not IsInRaid() then
                        C_Timer.After(0.15, function()
                            AdjustPartyFrameForCompactRaidManager()
                        end)
                        end
                    end)
                else
                    -- If no OnClick script exists, create one
                    toggleButton:SetScript("OnClick", function(self, button, down)
                        if manager:IsShown() then
                            manager:Hide()
                        else
                            manager:Show()
                        end
                        -- Only adjust if not in raid (party frames adjustment)
                        -- Don't interfere with raid group visibility controls
                        if not IsInRaid() then
                        C_Timer.After(0.15, function()
                            AdjustPartyFrameForCompactRaidManager()
                    end)
                end
                    end)
                end
            end
            
            -- REMOVED: Hook on RaidOptionsFrame_UpdatePartyFrames causes infinite recursion
            -- This function calls other functions that we also hook, creating a stack overflow
            -- Instead, we rely on event handlers (GROUP_ROSTER_UPDATE, RAID_ROSTER_UPDATE) to adjust positions
            
            -- REMOVED: Hook on CompactRaidFrameManager_SetIsShown can cause stack overflow
            -- This function is called frequently and can create infinite recursion
            -- Instead, we rely on event handlers and OnShow/OnHide hooks
            
            -- REMOVED: Hook on CompactRaidFrameManager_AttachPartyFrames can also cause issues
            -- This function is called frequently and can create infinite recursion
            -- Instead, we rely on event handlers and OnShow/OnHide hooks
            
            -- Set up event listener for GROUP_ROSTER_UPDATE and other relevant events
            local eventFrame = CreateFrame("Frame")
            eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
            eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
            eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
            eventFrame:SetScript("OnEvent", function()
                -- Only adjust if not in raid (party frames adjustment)
                -- Don't interfere with raid group visibility controls
                if not IsInRaid() then
                C_Timer.After(0.1, function()
                    AdjustPartyFrameForCompactRaidManager()
                end)
                end
            end)
        end
    end
    
    -- Initialize the hook when frames are ready
    -- Try multiple times to ensure we catch it
    local function TrySetupHook()
        if _G["CompactRaidFrameManager"] then
            SetupCompactRaidFrameManagerHook()
            -- Also set up a periodic check to ensure it stays hooked
            local checkFrame = CreateFrame("Frame")
            local checkCount = 0
            checkFrame:SetScript("OnUpdate", function(self, elapsed)
                checkCount = checkCount + 1
                if checkCount > 30 then -- Check every ~0.5 seconds
                    checkCount = 0
                    if _G["CompactRaidFrameManager"] and not _G["CompactRaidFrameManager"].hookedNozdorUI then
                        SetupCompactRaidFrameManagerHook()
                    end
                    AdjustPartyFrameForCompactRaidManager()
                end
            end)
            return true
        end
        return false
    end
    
    -- Try immediately
    if not TrySetupHook() then
        -- Wait for CompactRaidFrameManager to be created
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("ADDON_LOADED")
        waitFrame:RegisterEvent("PLAYER_LOGIN")
        waitFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        waitFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        waitFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
        local attempts = 0
        waitFrame:SetScript("OnEvent", function(self, event)
            attempts = attempts + 1
            if TrySetupHook() then
                C_Timer.After(0.2, AdjustPartyFrameForCompactRaidManager)
                if event == "PLAYER_LOGIN" then
                    self:UnregisterEvent("PLAYER_LOGIN")
                end
            elseif attempts > 50 then
                -- Give up after many attempts
                self:UnregisterAllEvents()
            end
        end)
        
        -- Also try periodically
        local periodicFrame = CreateFrame("Frame")
        local periodicCount = 0
        periodicFrame:SetScript("OnUpdate", function(self, elapsed)
            periodicCount = periodicCount + 1
            if periodicCount > 10 then
                periodicCount = 0
                if TrySetupHook() then
                    self:SetScript("OnUpdate", nil)
                end
            end
        end)
    else
        -- Already hooked, check immediately
        C_Timer.After(0.2, AdjustPartyFrameForCompactRaidManager)
    end
    
    -- Main hook to maintain styles (simplified)
    hooksecurefunc("PartyMemberFrame_UpdateMember", function(frame)
        if frame and frame:GetName():match("^PartyMemberFrame%d+$") then
            -- Don't reposition if in raid and CompactRaidFrameManager is managing party frames
            local manager = _G["CompactRaidFrameManager"]
            local isInRaid = IsInRaid()
            local shouldUseCompactRaid = manager and manager.container and manager.container.enabled and isInRaid
            
            -- Only maintain positioning if not using CompactRaidFrameManager for party frames
            if not shouldUseCompactRaid and PartyFrames.anchor and not InCombatLockdown() then
                local frameIndex = frame:GetID()
                if frameIndex and frameIndex >= 1 and frameIndex <= 4 then
                    frame:ClearAllPoints()
                    local yOffset = (frameIndex - 1) * -70
                    frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", 0, yOffset)
                end
            end

            -- Re-hide textures (always needed)
            local texture = _G[frame:GetName() .. 'Texture']
            if texture then
                texture:SetTexture()
                texture:Hide()
            end

            local bg = _G[frame:GetName() .. 'Background']
            if bg then
                bg:Hide()
            end

            -- Maintain only clipping configuration (ACE3 handles colors)
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            local manabar = _G[frame:GetName() .. 'ManaBar']

            if healthbar then
                SetupHealthBarClipping(frame)
            end

            if manabar then
                manabar:SetStatusBarColor(1, 1, 1, 1)
                SetupManaBarClipping(frame)
            end

            -- Update power bar texture
            UpdateManaBarTexture(frame)
            -- Disconnected state
            UpdateDisconnectedState(frame)
            
            -- Update portrait to ensure it's visible
            local frameIndex = frame:GetID()
            if frameIndex and frameIndex >= 1 and frameIndex <= 4 then
                local partyUnit = "party" .. frameIndex
                if UnitExists(partyUnit) then
                    local portrait = _G[frame:GetName() .. 'Portrait']
                    if portrait then
                        -- Force portrait update
                        SetPortraitTexture(portrait, partyUnit)
                    end
                end
            end
        end
    end)

    -- Main hook for class color (simplified)
    hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
        if statusbar and statusbar:GetName() and statusbar:GetName():find('PartyMemberFrame') then
            -- Only maintain dynamic clipping - Ace3 handles color
            local texture = statusbar:GetStatusBarTexture()
            if texture then
                local min, max = statusbar:GetMinMaxValues()
                local current = statusbar:GetValue()
                if max > 0 and current then
                    local percentage = math.max(0, math.min(1, current / max)) -- Clamp between 0 and 1
                    texture:SetTexCoord(0, percentage, 0, 1)
                end
            end
        end
    end)

    -- Hook for mana bar (without touching health)
    hooksecurefunc("UnitFrameManaBar_Update", function(statusbar, unit)
        if statusbar and statusbar:GetName() and statusbar:GetName():find('PartyMemberFrame') then
            statusbar:SetStatusBarColor(1, 1, 1, 1) -- Only mana in white

            local frameName = statusbar:GetParent():GetName()
            local frameIndex = frameName:match("PartyMemberFrame(%d+)")
            if frameIndex then
                local partyUnit = "party" .. frameIndex
                local powerTexture = GetPowerBarTexture(partyUnit)
                statusbar:SetStatusBarTexture(powerTexture)

                -- Maintain dynamic clipping
                local texture = statusbar:GetStatusBarTexture()
                if texture then
                    local min, max = statusbar:GetMinMaxValues()
                    local current = statusbar:GetValue()
                    if max > 0 and current then
                        local percentage = math.max(0, math.min(1, current / max)) -- Clamp between 0 and 1
                        texture:SetTexCoord(0, percentage, 0, 1)
                        texture:SetTexture(powerTexture)
                    end
                end
            end
        end
    end)
end

-- ===============================================================
-- MODULE INTERFACE FUNCTIONS (SIMPLIFIED FOR ACE3)
-- ===============================================================

-- Simplified function compatible with Ace3
function PartyFrames:UpdateSettings()
    -- Check initial configuration
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets or not addon.db.profile.widgets.party then
        self:LoadDefaultSettings()
    end

    -- Apply widget position first
    ApplyWidgetPosition()
    
    -- Only apply base styles - ACE3 handles class color
    StylePartyFrames()
    
    -- Reposition buffs
    RepositionBlizzardBuffs()
    
    -- CRITICAL: Update text for all party frames
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            local manabar = _G[frame:GetName() .. 'ManaBar']
            
            if healthbar then
                UpdateHealthText(healthbar, nil)
            end
            
            if manabar then
                UpdateManaText(manabar, nil)
            end
        end
    end
    
    -- Обновить портреты после применения стилей
    C_Timer.After(0.3, function()
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
                local partyUnit = "party" .. i
                if UnitExists(partyUnit) then
                    local portrait = _G[frame:GetName() .. 'Portrait']
                    if portrait then
                        SetPortraitTexture(portrait, partyUnit)
        end
    end
            end
        end
    end)
end

-- ===============================================================
-- EXPORTS FOR OPTIONS.LUA
-- ===============================================================

-- Export for options.lua refresh functions
addon.RefreshPartyFrames = function()
    if PartyFrames.UpdateSettings then
        PartyFrames:UpdateSettings()
    end
end

-- New function: Refresh called from core.lua
function addon:RefreshPartyFrames()
    if PartyFrames and PartyFrames.UpdateSettings then
        PartyFrames:UpdateSettings()
    end
end

-- ===============================================================
-- CENTRALIZED SYSTEM REGISTRATION AND INITIALIZATION
-- ===============================================================

local function InitializePartyFramesForEditor()
    if PartyFrames.initialized then
        return
    end

    -- Create anchor frame
    CreatePartyAnchorFrame()

    -- Always ensure configuration exists
    PartyFrames:LoadDefaultSettings()

    -- Apply initial position
    ApplyWidgetPosition()

    -- Register with centralized system
    if addon and addon.RegisterEditableFrame then
        addon:RegisterEditableFrame({
            name = "party",
            frame = PartyFrames.anchor,
            configPath = {"widgets", "party"}, -- Add configPath required by core.lua
            showTest = ShowPartyFramesTest,
            hideTest = HidePartyFramesTest,
            hasTarget = ShouldPartyFramesBeVisible -- Use hasTarget instead of shouldShow
        })
    end

    PartyFrames.initialized = true
end

-- ===============================================================
-- INITIALIZATION
-- ===============================================================

-- Функция для обновления всех портретов (определена до использования)
local function UpdateAllPartyPortraits()
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            local partyUnit = "party" .. i
            if UnitExists(partyUnit) then
                local portrait = _G[frame:GetName() .. 'Portrait']
                if portrait then
                    -- Принудительно обновить портрет
                    SetPortraitTexture(portrait, partyUnit)
                end
            end
        end
    end
end

-- Initialize everything in correct order
InitializePartyFramesForEditor() -- First: register with centralized system
StylePartyFrames() -- Second: visual properties and positioning
SetupPartyHooks() -- Third: safe hooks only

-- Listener for when the addon is fully loaded
local readyFrame = CreateFrame("Frame")
readyFrame:RegisterEvent("ADDON_LOADED")
readyFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "NozdorUI" then
        -- Apply position after the addon is fully loaded
        if PartyFrames and PartyFrames.UpdateSettings then
            PartyFrames:UpdateSettings()
        end
        -- Обновить портреты после загрузки аддона
        -- Небольшая задержка для надежности
        local updateFrame = CreateFrame("Frame")
        updateFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed >= 0.5 then
                UpdateAllPartyPortraits()
                self:SetScript("OnUpdate", nil)
            end
        end)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

local connectionFrame = CreateFrame("Frame")
connectionFrame:RegisterEvent("PARTY_MEMBER_DISABLE")
connectionFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
connectionFrame:SetScript("OnEvent", function(self, event)
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            UpdateDisconnectedState(frame)
        end
    end
end)

-- Frame for portrait updates
local portraitUpdateFrame = CreateFrame("Frame")
portraitUpdateFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
portraitUpdateFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
portraitUpdateFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
portraitUpdateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
portraitUpdateFrame:RegisterEvent("PLAYER_LOGIN")
portraitUpdateFrame:RegisterEvent("PARTY_LEADER_CHANGED")
portraitUpdateFrame:SetScript("OnEvent", function(self, event, unit)
    -- При входе в игру обновить все портреты несколько раз с задержками
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
        -- Немедленное обновление
        UpdateAllPartyPortraits()
        
        -- Обновление с задержками для надежности
        local updateFrame = CreateFrame("Frame")
        local attempts = 0
        updateFrame:SetScript("OnUpdate", function(self, elapsed)
            attempts = attempts + elapsed
            if attempts >= 0.3 then
                attempts = 0
                UpdateAllPartyPortraits()
                -- Остановить после нескольких попыток
                if self.updateCount then
                    self.updateCount = self.updateCount + 1
                    if self.updateCount >= 5 then
                        self:SetScript("OnUpdate", nil)
                    end
                else
                    self.updateCount = 1
                end
            end
        end)
        return
    end
    
    -- Update portraits for all party members
    if event == "GROUP_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" or event == "PARTY_LEADER_CHANGED" then
        -- Обновить все портреты при изменении состава группы
        UpdateAllPartyPortraits()
        return
    end
    
    -- Для UNIT_PORTRAIT_UPDATE обновить конкретный юнит
    if event == "UNIT_PORTRAIT_UPDATE" then
        for i = 1, MAX_PARTY_MEMBERS do
            local frame = _G['PartyMemberFrame' .. i]
            if frame then
                local partyUnit = "party" .. i
                -- If event has a unit parameter, only update that unit
                if not unit or unit == partyUnit then
                    local portrait = _G[frame:GetName() .. 'Portrait']
                    if portrait and UnitExists(partyUnit) then
                        -- Force portrait update using SetPortraitTexture
                        SetPortraitTexture(portrait, partyUnit)
                    end
                end
            end
        end
    end
end)

-- Periodic portrait update to ensure portraits are visible even when far away
local portraitPeriodicFrame = CreateFrame("Frame")
local portraitUpdateElapsed = 0
portraitPeriodicFrame:SetScript("OnUpdate", function(self, elapsed)
    portraitUpdateElapsed = portraitUpdateElapsed + elapsed
    -- Update portraits every 0.5 seconds
    if portraitUpdateElapsed >= 0.5 then
        portraitUpdateElapsed = 0
        for i = 1, MAX_PARTY_MEMBERS do
            local frame = _G['PartyMemberFrame' .. i]
            if frame then
                local partyUnit = "party" .. i
                if UnitExists(partyUnit) then
                    local portrait = _G[frame:GetName() .. 'Portrait']
                    if portrait then
                        -- Try to update portrait - this will work when unit is in range
                        SetPortraitTexture(portrait, partyUnit)
                    end
                end
            end
        end
    end
end)


-- ===============================================================
-- MODULE LOADED CONFIRMATION
-- ===============================================================

