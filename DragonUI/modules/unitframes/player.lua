-- Get addon reference - either from XML parameter or global
local addon = select(2, ...);



-- ====================================================================
-- NOZDORUI PLAYER FRAME MODULE - Optimized for WoW 3.3.5a
-- ====================================================================

-- ============================================================================
-- MODULE VARIABLES & CONFIGURATION
-- ============================================================================

local Module = {}
Module.playerFrame = nil
Module.textSystem = nil
Module.initialized = false
Module.eventsFrame = nil
-- Animation variables for Combat Flash pulse effect
local combatPulseTimer = 0
local eliteStatusPulseTimer = 0

-- Elite Glow System State
local eliteGlowActive = false
local statusGlowVisible = false
local combatGlowVisible = false

-- Cache frequently accessed globals for performance
local PlayerFrame = _G.PlayerFrame
local PlayerFrameHealthBar = _G.PlayerFrameHealthBar
local PlayerFrameManaBar = _G.PlayerFrameManaBar
local PlayerPortrait = _G.PlayerPortrait
local PlayerStatusTexture = _G.PlayerStatusTexture
local PlayerFrameFlash = _G.PlayerFrameFlash
local PlayerRestIcon = _G.PlayerRestIcon
local PlayerStatusGlow = _G.PlayerStatusGlow
local PlayerRestGlow = _G.PlayerRestGlow
local PlayerName = _G.PlayerName
local PlayerLevelText = _G.PlayerLevelText

-- Texture paths configuration
local TEXTURES = {
    BASE = 'Interface\\AddOns\\DragonUI\\Textures\\uiunitframe',
    HEALTH_BAR = 'Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health',
    HEALTH_STATUS = 'Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Status',
    BORDER = 'Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Player-PortraitOn-BORDER',
    REST_ICON = "Interface\\AddOns\\DragonUI\\Textures\\PlayerFrame\\PlayerRestFlipbook",
    RUNE_TEXTURE = 'Interface\\AddOns\\DragonUI\\Textures\\PlayerFrame\\ClassOverlayDeathKnightRunes',
    LFG_ICONS = "Interface\\AddOns\\DragonUI\\Textures\\PlayerFrame\\LFGRoleIcons",
    POWER_BARS = {
        MANA = 'Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana',
        RAGE = 'Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage',
        FOCUS = 'Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Focus',
        ENERGY = 'Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Energy',
        RUNIC_POWER = 'Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-RunicPower'
    }
}

-- Coordenadas para glows elite/rare (target frame invertido)
local ELITE_GLOW_COORDINATES = {
    -- Usando la textura correcta: 'Interface\\AddOns\\DragonUI\\Textures\\UI\\UnitFrame'
    texCoord = {0.2061015625, 0, 0.537109375, 0.712890625},
    size = {209, 90},
    texture = 'Interface\\AddOns\\DragonUI\\Textures\\UI\\UnitFrame'
}

-- Dragon decoration coordinates for uiunitframeboss2x texture (always flipped for player frame)
local DRAGON_COORDINATES = {
    elite = {
        texCoord = {0.314453125, 0.001953125, 0.322265625, 0.630859375},
        size = {80, 79},
        offset = {4, 1}
    },
    rareelite = {
        texCoord = {0.388671875, 0.001953125, 0.001953125, 0.31835937},
        size = {99, 81}, -- 97*1.02 в‰€ 99, 79*1.02 в‰€ 81
        offset = {23, 2}
    }
}

-- Combat Flash animation settings *NO Elite activated
local COMBAT_PULSE_SETTINGS = {
    speed = 9, -- Velocidad del pulso
    minAlpha = 0.3, -- Transparencia mГ­nima
    maxAlpha = 1.0, -- Transparencia mГЎxima
    enabled = true -- Activar/desactivar animaciГіn
}

-- Elite Combat Flash animation settings (cuando elite decoration estГЎ ON)
local ELITE_COMBAT_PULSE_SETTINGS = {
    speed = 9, -- Velocidad para combat en modo elite (diferente a normal)
    minAlpha = 0.2,
    maxAlpha = 0.9,
    enabled = true
}

-- Elite Status/Rest animation settings (cuando elite decoration estГЎ ON)
local ELITE_STATUS_PULSE_SETTINGS = {
    speed = 5, -- Velocidad para resting en modo elite
    minAlpha = 0,
    maxAlpha = 0.7,
    enabled = true
}

-- Event lookup tables for O(1) performance
local HEALTH_EVENTS = {
    UNIT_HEALTH = true,
    UNIT_MAXHEALTH = true,
    UNIT_HEALTH_FREQUENT = true
}

local POWER_EVENTS = {
    UNIT_MAXMANA = true,
    UNIT_DISPLAYPOWER = true,
    UNIT_POWER_UPDATE = true
}

-- Rune type coordinates
local RUNE_COORDS = {
    [1] = {0 / 128, 34 / 128, 0 / 128, 34 / 128}, -- Blood
    [2] = {0 / 128, 34 / 128, 68 / 128, 102 / 128}, -- Unholy
    [3] = {34 / 128, 68 / 128, 0 / 128, 34 / 128}, -- Frost
    [4] = {68 / 128, 102 / 128, 0 / 128, 34 / 128} -- Death
}

-- LFG Role icon coordinates
local ROLE_COORDS = {
    TANK = {35 / 256, 53 / 256, 0 / 256, 17 / 256},
    HEALER = {18 / 256, 35 / 256, 0 / 256, 18 / 256},
    DAMAGER = {0 / 256, 17 / 256, 0 / 256, 17 / 256}
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Get player configuration with fallback to defaults
local function GetPlayerConfig()
    local config = addon:GetConfigValue("unitframe", "player") or {}
    -- Usar defaults directamente de database
    local dbDefaults = addon.defaults and addon.defaults.profile.unitframe.player or {}

    -- Aplicar defaults de database para cualquier valor faltante
    for key, value in pairs(dbDefaults) do
        if config[key] == nil then
            config[key] = value
        end
    end
    return config
end


-- ============================================================================
-- BLIZZARD FRAME MANAGEMENT
-- ============================================================================
-- Hide Blizzard's original player frame texts permanently using alpha 0
local function HideBlizzardPlayerTexts()
    -- Get Blizzard's ORIGINAL text elements (not our custom ones)
    local blizzardTexts = {
        -- These are the actual Blizzard frame text elements in WoW 3.3.5a
        PlayerFrameHealthBar.TextString,
        PlayerFrameManaBar.TextString,
        -- Alternative names that might exist
        _G.PlayerFrameHealthBarText,
        _G.PlayerFrameManaBarText
    }

    -- Hide each BLIZZARD text element permanently with alpha 0 (ONE TIME SETUP)
    for _, textElement in pairs(blizzardTexts) do
        if textElement and not textElement.NozdorUIHidden then
            -- Set alpha to 0 immediately (taint-free)
            textElement:SetAlpha(0)

            -- Override Show function to maintain permanent invisibility
            textElement.NozdorUIShow = textElement.Show
            textElement.Show = function(self)
                -- Always stay invisible - no timer needed
                self:SetAlpha(0)
            end

            -- Mark as processed to avoid duplicate setup
            textElement.NozdorUIHidden = true
        end
    end
end
-- Hide and disable Blizzard glow effects
local function HideBlizzardGlows()
    local glows = {PlayerStatusGlow, PlayerRestGlow}
    for _, glow in ipairs(glows) do
        if glow then
            glow:Hide()
            glow:SetAlpha(0)
        end
    end
end

-- Remove unwanted Blizzard frame elements
local function RemoveBlizzardFrames()
    local elementsToHide = {"PlayerAttackIcon", "PlayerFrameBackground", "PlayerAttackBackground", "PlayerGuideIcon",
                            "PlayerFrameGroupIndicatorLeft", "PlayerFrameGroupIndicatorRight"}

    for _, name in ipairs(elementsToHide) do
        local obj = _G[name]
        if obj and not obj.__NozdorUIHidden then
            obj:Hide()
            obj:SetAlpha(0)

            if obj.HookScript then
                obj:HookScript("OnShow", function(self)
                    self:Hide()
                    self:SetAlpha(0)
                end)
            end

            if obj.GetObjectType and obj:GetObjectType() == "Texture" and obj.SetTexture then
                obj:SetTexture(nil)
            end

            obj.__NozdorUIHidden = true
        end
    end

    -- Hide standard frame textures
    local textures = {PlayerFrameTexture, PlayerFrameBackground, PlayerFrameVehicleTexture}
    for _, texture in ipairs(textures) do
        if texture then
            texture:SetAlpha(0)
        end
    end
end

-- ============================================================================
-- ELITE GLOW SYSTEM - Switch system
-- ============================================================================

-- Check if elite mode is active based on dragon decoration
local function IsEliteModeActive()
    local config = GetPlayerConfig()
    local decorationType = config.dragon_decoration or "none"
    return decorationType == "elite" or decorationType == "rareelite"
end

-- Toggle glow visibility based on elite mode
local function UpdateGlowVisibility()
    local dragonFrame = _G["NozdorUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    eliteGlowActive = IsEliteModeActive()

    --  CORREGIDO: Control correcto del PlayerStatusTexture
    if PlayerStatusTexture then
        if eliteGlowActive then
            -- En modo elite: ocultar completamente el glow original
            PlayerStatusTexture:Hide()
            PlayerStatusTexture:SetAlpha(0)
        else
            -- En modo normal: controlar segГєn statusGlowVisible
            PlayerStatusTexture:SetAlpha(1) -- Restaurar alpha
            if statusGlowVisible then
                PlayerStatusTexture:Show()
            else
                PlayerStatusTexture:Hide()
            end
        end
    end

    if dragonFrame.NozdorUICombatGlow then
        if eliteGlowActive then
            -- En modo elite: ocultar glow original
            dragonFrame.NozdorUICombatGlow:Hide()
            dragonFrame.NozdorUICombatGlow:SetAlpha(0)
        else
            -- En modo normal: mostrar/ocultar glow original segГєn combatGlowVisible
            dragonFrame.NozdorUICombatGlow:SetAlpha(1) -- Restaurar alpha
            if combatGlowVisible then
                dragonFrame.NozdorUICombatGlow:Show()
            else
                dragonFrame.NozdorUICombatGlow:Hide()
            end
        end
    end

    -- Update elite glows (solo en modo elite)
    if eliteGlowActive then
        if dragonFrame.EliteStatusGlow then
            if statusGlowVisible then
                dragonFrame.EliteStatusGlow:Show()
            else
                dragonFrame.EliteStatusGlow:Hide()
            end
        end
        if dragonFrame.EliteCombatGlow then
            if combatGlowVisible then
                dragonFrame.EliteCombatGlow:Show()
            else
                dragonFrame.EliteCombatGlow:Hide()
            end
        end
    else
        -- Ocultar elite glows en modo normal
        if dragonFrame.EliteStatusGlow then
            dragonFrame.EliteStatusGlow:Hide()
        end
        if dragonFrame.EliteCombatGlow then
            dragonFrame.EliteCombatGlow:Hide()
        end
    end
end

-- Set status glow state (replaces original logic)
local function SetStatusGlowVisible(visible)
    statusGlowVisible = visible
    UpdateGlowVisibility()
end

-- Set combat glow state (replaces original logic)
local function SetEliteCombatFlashVisible(visible)
    combatGlowVisible = visible
    UpdateGlowVisibility()
end

-- ============================================================================
-- ANIMATION & VISUAL EFFECTS
-- ============================================================================

-- Animate texture coordinates for rest icon
local function AnimateTexCoords(texture, textureWidth, textureHeight, frameWidth, frameHeight, numFrames, elapsed,
    throttle)
    if not texture or not texture:IsVisible() then
        return
    end

    texture.animationTimer = (texture.animationTimer or 0) + elapsed
    if texture.animationTimer >= throttle then
        texture.animationFrame = ((texture.animationFrame or 0) + 1) % numFrames
        local col = texture.animationFrame % (textureWidth / frameWidth)
        local row = math.floor(texture.animationFrame / (textureWidth / frameWidth))

        local left = col * frameWidth / textureWidth
        local right = (col + 1) * frameWidth / textureWidth
        local top = row * frameHeight / textureHeight
        local bottom = (row + 1) * frameHeight / textureHeight

        texture:SetTexCoord(left, right, top, bottom)
        texture.animationTimer = 0
    end
end

-- Animate Combat Flash pulse effect
local function AnimateCombatFlashPulse(elapsed)
    if not COMBAT_PULSE_SETTINGS.enabled then
        return
    end
    local dragonFrame = _G["NozdorUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    if eliteGlowActive then
        -- Modo Elite: usar configuraciГіn especГ­fica para elite combat
        if not ELITE_COMBAT_PULSE_SETTINGS.enabled then
            return
        end

        combatPulseTimer = combatPulseTimer + (elapsed * ELITE_COMBAT_PULSE_SETTINGS.speed)

        local pulseAlpha = ELITE_COMBAT_PULSE_SETTINGS.minAlpha +
                               (ELITE_COMBAT_PULSE_SETTINGS.maxAlpha - ELITE_COMBAT_PULSE_SETTINGS.minAlpha) *
                               (math.sin(combatPulseTimer) * 0.5 + 0.5)

        if dragonFrame.EliteCombatGlow and dragonFrame.EliteCombatGlow:IsVisible() then
            dragonFrame.EliteCombatTexture:SetAlpha(pulseAlpha)
        end
    else
        -- Modo Normal: usar configuraciГіn normal
        if not COMBAT_PULSE_SETTINGS.enabled then
            return
        end

        combatPulseTimer = combatPulseTimer + (elapsed * COMBAT_PULSE_SETTINGS.speed)

        local pulseAlpha = COMBAT_PULSE_SETTINGS.minAlpha +
                               (COMBAT_PULSE_SETTINGS.maxAlpha - COMBAT_PULSE_SETTINGS.minAlpha) *
                               (math.sin(combatPulseTimer) * 0.5 + 0.5)

        if dragonFrame.NozdorUICombatGlow and dragonFrame.NozdorUICombatGlow:IsVisible() then
            dragonFrame.NozdorUICombatTexture:SetAlpha(pulseAlpha)
        end
    end
end

-- Animate Elite Status/Rest pulse effect
local function AnimateEliteStatusPulse(elapsed)
    if not ELITE_STATUS_PULSE_SETTINGS.enabled then
        return
    end

    local dragonFrame = _G["NozdorUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    -- Solo animar si estamos en modo elite Y el status glow estГЎ visible
    if eliteGlowActive and dragonFrame.EliteStatusGlow and dragonFrame.EliteStatusGlow:IsVisible() then
        eliteStatusPulseTimer = eliteStatusPulseTimer + (elapsed * ELITE_STATUS_PULSE_SETTINGS.speed)

        local pulseAlpha = ELITE_STATUS_PULSE_SETTINGS.minAlpha +
                               (ELITE_STATUS_PULSE_SETTINGS.maxAlpha - ELITE_STATUS_PULSE_SETTINGS.minAlpha) *
                               (math.sin(eliteStatusPulseTimer) * 0.5 + 0.5)

        dragonFrame.EliteStatusTexture:SetAlpha(pulseAlpha)
    end
end

-- Frame update handler for animations
local function PlayerFrame_OnUpdate(self, elapsed)
    -- Throttle updates to prevent freezes (update every 0.1 seconds instead of every frame)
    self.updateElapsed = (self.updateElapsed or 0) + elapsed
    if self.updateElapsed < 0.1 then
        return
    end
    self.updateElapsed = 0
    
    --  PROTEGER CON pcall PARA EVITAR CRASHES
    local success, err = pcall(function()
        -- Rest icon animation
        if PlayerRestIcon and PlayerRestIcon:IsVisible() then
            AnimateTexCoords(PlayerRestIcon, 512, 512, 64, 64, 42, elapsed, 0.09)
        end

        -- Combat Flash pulse animation
        AnimateCombatFlashPulse(elapsed)

        -- Elite Status pulse animation
        AnimateEliteStatusPulse(elapsed)
    end)

    if not success then

    end
end

-- Override Blizzard status update to prevent glow interference
local function PlayerFrame_UpdateStatus()
    HideBlizzardGlows()
    -- Trigger status glow based on player state
    local isResting = IsResting()
    SetStatusGlowVisible(isResting)
end

-- ============================================================================
-- CLASS-SPECIFIC FEATURES
-- ============================================================================

-- Update Death Knight rune display
local function UpdateRune(button)
    if not button then
        return
    end

    local rune = button:GetID()
    local runeType = GetRuneType and GetRuneType(rune)

    if runeType and RUNE_COORDS[runeType] then
        local runeTexture = _G[button:GetName() .. "Rune"]
        if runeTexture then
            runeTexture:SetTexture(TEXTURES.RUNE_TEXTURE)
            runeTexture:SetTexCoord(unpack(RUNE_COORDS[runeType]))
        end
    end
end

-- Setup Death Knight rune frame
local function SetupRuneFrame()
    if select(2, UnitClass("player")) ~= "DEATHKNIGHT" then
        return
    end

    for index = 1, 6 do
        local button = _G['RuneButtonIndividual' .. index]
        if button then
            button:ClearAllPoints()
            if index > 1 then
                button:SetPoint('LEFT', _G['RuneButtonIndividual' .. (index - 1)], 'RIGHT', 4, 0)
            else
                button:SetPoint('CENTER', PlayerFrame, 'BOTTOM', -20, 0)
            end
            UpdateRune(button)
        end
    end
end

-- Update LFG role icon display
local function UpdatePlayerRoleIcon()
    local dragonFrame = _G["NozdorUIUnitframeFrame"]
    if not dragonFrame or not dragonFrame.PlayerRoleIcon then
        return
    end

    local iconTexture = dragonFrame.PlayerRoleIcon
    local isTank, isHealer, isDamage = UnitGroupRolesAssigned("player")

    --  MEJORAR: Usar lГіgica de RetailUI
    if isTank then
        iconTexture:SetTexture(TEXTURES.LFG_ICONS)
        iconTexture:SetTexCoord(unpack(ROLE_COORDS.TANK))
        iconTexture:Show()
    elseif isHealer then
        iconTexture:SetTexture(TEXTURES.LFG_ICONS)
        iconTexture:SetTexCoord(unpack(ROLE_COORDS.HEALER))
        iconTexture:Show()
    elseif isDamage then
        iconTexture:SetTexture(TEXTURES.LFG_ICONS)
        iconTexture:SetTexCoord(unpack(ROLE_COORDS.DAMAGER))
        iconTexture:Show()
    else
        iconTexture:Hide()
    end
end

-- Update group indicator for raids
local function UpdateGroupIndicator()
    local groupIndicatorFrame = _G[PlayerFrame:GetName() .. 'GroupIndicator']
    local groupText = _G[PlayerFrame:GetName() .. 'GroupIndicatorText']

    if not groupIndicatorFrame or not groupText then
        return
    end

    groupIndicatorFrame:Hide()

    local numRaidMembers = GetNumRaidMembers()
    if numRaidMembers == 0 then
        return
    end

    for i = 1, numRaidMembers do
        local name, rank, subgroup = GetRaidRosterInfo(i)
        if name and name == UnitName("player") then
            groupText:SetText("Группа" .. subgroup)
            groupIndicatorFrame:Show()
            break
        end
    end
end

-- ============================================================================
-- LEADERSHIP & PVP ICONS MANAGEMENT
-- ============================================================================

-- Cache leadership and PVP icons
local PlayerLeaderIcon = _G.PlayerLeaderIcon
local PlayerMasterIcon = _G.PlayerMasterIcon
local PlayerPVPIcon = _G.PlayerPVPIcon

-- Update leader icon positioning based on dragon decoration mode
local function UpdateLeaderIconPosition()
    if not PlayerLeaderIcon then
        return
    end

    local config = GetPlayerConfig()
    local decorationType = config.dragon_decoration or "none"
    local isEliteMode = decorationType == "elite" or decorationType == "rareelite"

    PlayerLeaderIcon:ClearAllPoints()

    if isEliteMode then
        -- En modo elite: posicionar mГЎs arriba para evitar el dragon
        PlayerLeaderIcon:SetPoint('BOTTOM', PlayerFrame, "TOP", -1, -33)
    else
        -- Modo normal
        PlayerLeaderIcon:SetPoint('BOTTOM', PlayerFrame, "TOP", -70, -25)
    end
end

-- Update master icon positioning based on dragon decoration mode
local function UpdateMasterIconPosition()
    if not PlayerMasterIcon then
        return
    end

    local config = GetPlayerConfig()
    local decorationType = config.dragon_decoration or "none"
    local isEliteMode = decorationType == "elite" or decorationType == "rareelite"

    PlayerMasterIcon:ClearAllPoints()

    if isEliteMode then
        local iconContainer = _G["NozdorUIUnitframeFrame"].EliteIconContainer
        PlayerMasterIcon:SetParent(iconContainer)
        PlayerMasterIcon:ClearAllPoints()
        PlayerMasterIcon:SetPoint("TOPRIGHT", PlayerFrame, "TOPRIGHT", -135, -55)
    else
        -- Modo normal
        PlayerMasterIcon:SetPoint('BOTTOM', PlayerFrame, "TOP", -71, -75)
    end
end

local function UpdatePVPIconPosition()
    if not PlayerPVPIcon then
        return
    end

    local config = GetPlayerConfig()
    local decorationType = config.dragon_decoration or "none"
    local isEliteMode = decorationType == "elite" or decorationType == "rareelite"

    -- Use the high-level container created in CreatePlayerFrameTextures
    local dragonFrame = _G["NozdorUIUnitframeFrame"]
    if not dragonFrame or not dragonFrame.PvPIconContainer then
        return
    end
    
    -- Set parent to the high-level container instead of PlayerFrameHealthBar
    -- This ensures the PvP icon is always rendered above the portrait and its border
    PlayerPVPIcon:SetParent(dragonFrame.PvPIconContainer)
    PlayerPVPIcon:ClearAllPoints()
    PlayerPVPIcon:SetPoint("CENTER", dragonFrame.PvPIconContainer, "CENTER", 0, 0)
    
    -- Set draw layer to ensure proper rendering order
    -- Use OVERLAY with high sublayer to ensure it's on top
    PlayerPVPIcon:SetDrawLayer("OVERLAY", 7)
    
    -- Ensure the container is visible and positioned correctly
    -- Update container position when PlayerFrame moves
    dragonFrame.PvPIconContainer:SetPoint("TOPRIGHT", PlayerFrame, "TOPRIGHT", -155, -22)
    dragonFrame.PvPIconContainer:Show()
end

-- Master function to update all leadership icons positioning
local function UpdateLeadershipIcons()
    UpdateLeaderIconPosition()
    UpdateMasterIconPosition()
    UpdatePVPIconPosition()
end

-- ============================================================================
-- BAR COLOR & TEXTURE MANAGEMENT
-- ============================================================================
-- Update player health bar color and texture based on class color setting
local function UpdatePlayerHealthBarColor()
    if not PlayerFrameHealthBar then
        return
    end

    local config = GetPlayerConfig()
    local texture = PlayerFrameHealthBar:GetStatusBarTexture()

    if not texture then
        return
    end

    if config.classcolor then
        --  USAR TEXTURA STATUS (BLANCA) PARA CLASS COLOR
        local statusTexturePath = TEXTURES.HEALTH_STATUS
        if texture:GetTexture() ~= statusTexturePath then
            texture:SetTexture(statusTexturePath)
        end

        --  APLICAR COLOR DE CLASE DEL PLAYER
        local _, class = UnitClass("player")
        local color = RAID_CLASS_COLORS[class]
        if color then
            PlayerFrameHealthBar:SetStatusBarColor(color.r, color.g, color.b, 1)
        else
            PlayerFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
        end
    else
        --  USAR TEXTURA NORMAL (COLORED) SIN CLASS COLOR
        local normalTexturePath = TEXTURES.HEALTH_BAR
        if texture:GetTexture() ~= normalTexturePath then
            texture:SetTexture(normalTexturePath)
        end

        --  COLOR BLANCO (la textura ya tiene color)
        PlayerFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
    end
end
-- Update health bar color and texture
local function UpdateHealthBarColor(statusBar, unit)
    if not unit then
        -- Determine unit from PlayerFrame state
        if PlayerFrame.state == "vehicle" then
            unit = "vehicle"
        else
        unit = "player"
    end
    end
    
    -- Only update if this is PlayerFrameHealthBar and unit is either "player" or "vehicle"
    -- When in vehicle, PlayerFrame shows vehicle data, PetFrame shows player data
    if statusBar ~= PlayerFrameHealthBar or (unit ~= "player" and unit ~= "vehicle") then
        return
    end

    --  LLAMAR A LA NUEVA FUNCIГ"N
    -- Only apply class color for player, not vehicle
    if unit == "player" then
    UpdatePlayerHealthBarColor()
    end
end

-- Update mana bar color (always white for texture purity)
local function UpdateManaBarColor(statusBar)
    if statusBar == PlayerFrameManaBar then
        statusBar:SetStatusBarColor(1, 1, 1)
    end
end

-- Update power bar texture based on current power type (handles druid forms)
local function UpdatePowerBarTexture(statusBar)
    if statusBar ~= PlayerFrameManaBar then
        return
    end

    local powerType, powerTypeString = UnitPowerType('player')
    local powerTexture = TEXTURES.POWER_BARS[powerTypeString] or TEXTURES.POWER_BARS.MANA

    --  CAMBIAR TEXTURA segГєn el tipo de poder actual
    local currentTexture = statusBar:GetStatusBarTexture():GetTexture()
    if currentTexture ~= powerTexture then
        statusBar:GetStatusBarTexture():SetTexture(powerTexture)

    end
end

-- ============================================================================
-- FRAME CREATION & CONFIGURATION
-- ============================================================================

-- Update decorative dragon for player frame
local function UpdatePlayerDragonDecoration()
    local dragonFrame = _G["NozdorUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    local config = GetPlayerConfig()
    local decorationType = config.dragon_decoration or "none"

    -- Remove existing dragon if it exists
    if dragonFrame.PlayerDragonDecoration then
        if dragonFrame.PlayerDragonFrame then
            dragonFrame.PlayerDragonFrame:Hide()
            dragonFrame.PlayerDragonFrame = nil
        end
        dragonFrame.PlayerDragonDecoration = nil
    end

    --  Reposicionar rest icon en modo elite/dragon
    if PlayerRestIcon then
        if decorationType ~= "none" then
            -- Modo elite: mover arriba y a la derecha
            PlayerRestIcon:ClearAllPoints()
            PlayerRestIcon:SetPoint("TOPLEFT", PlayerPortrait, "TOPLEFT", 60, 20)
        else
            -- Modo normal: posiciГіn original
            PlayerRestIcon:ClearAllPoints()
            PlayerRestIcon:SetPoint("TOPLEFT", PlayerPortrait, "TOPLEFT", 40, 15) -- PosiciГіn original
        end
    end

    --  Cambiar background, borde Y ESTIRAR MANA BAR segГєn decoraciГіn
    if decorationType ~= "none" then
        -- Usar texturas del target (invertidas) cuando hay decoraciГіn
        if dragonFrame.PlayerFrameBackground then
            dragonFrame.PlayerFrameBackground:SetTexture(
                "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BACKGROUND")
            dragonFrame.PlayerFrameBackground:SetSize(255, 130)
            dragonFrame.PlayerFrameBackground:SetTexCoord(1, 0, 0, 1) -- Invertir horizontalmente

            -- Reposicionar con frame de referencia especГ­fico
            dragonFrame.PlayerFrameBackground:ClearAllPoints()
            dragonFrame.PlayerFrameBackground:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -128, -29.5)
        end
        if dragonFrame.PlayerFrameBorder then
            dragonFrame.PlayerFrameBorder:SetTexture(
                "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BORDER")
            dragonFrame.PlayerFrameBorder:SetTexCoord(1, 0, 0, 1) -- Invertir horizontalmente

            -- Reposicionar con frame de referencia especГ­fico
            dragonFrame.PlayerFrameBorder:ClearAllPoints()
            dragonFrame.PlayerFrameBorder:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -128, -29.5)
        end

        --  NUEVO: Ocultar PlayerFrameDeco cuando hay decoraciГіn elite/rare
        if dragonFrame.PlayerFrameDeco then
            dragonFrame.PlayerFrameDeco:Hide()
        end

        --  NUEVO: Estirar mana bar hacia la izquierda
        if PlayerFrameManaBar then
            local hasVehicleUI = UnitHasVehicleUI("player")
            local normalWidth = hasVehicleUI and 117 or 125
            local extendedWidth = hasVehicleUI and 130 or 130 -- MГЎs ancho

            PlayerFrameManaBar:ClearAllPoints()
            PlayerFrameManaBar:SetSize(extendedWidth, hasVehicleUI and 9 or 8)
            -- CLAVE: Anclar por el lado DERECHO para que solo se estire hacia la izquierda
            PlayerFrameManaBar:SetPoint('RIGHT', PlayerPortrait, 'RIGHT', 1 + normalWidth, -16.5)
        end
    else
        -- Usar texturas normales del player cuando no hay decoraciГіn
        if dragonFrame.PlayerFrameBackground then
            dragonFrame.PlayerFrameBackground:SetTexture(TEXTURES.BASE)
            dragonFrame.PlayerFrameBackground:SetTexCoord(0.7890625, 0.982421875, 0.001953125, 0.140625)
            dragonFrame.PlayerFrameBackground:SetSize(198, 71)

            -- Restaurar posiciГіn original
            dragonFrame.PlayerFrameBackground:ClearAllPoints()
            dragonFrame.PlayerFrameBackground:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -67, 0)
        end
        if dragonFrame.PlayerFrameBorder then
            dragonFrame.PlayerFrameBorder:SetTexture(TEXTURES.BORDER)
            dragonFrame.PlayerFrameBorder:SetTexCoord(0, 1, 0, 1)

            -- Restaurar posiciГіn original
            dragonFrame.PlayerFrameBorder:ClearAllPoints()
            dragonFrame.PlayerFrameBorder:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -67, -28.5)
        end

        --  NUEVO: Mostrar PlayerFrameDeco cuando no hay decoraciГіn
        if dragonFrame.PlayerFrameDeco then
            dragonFrame.PlayerFrameDeco:Show()
        end

        --  NUEVO: Restaurar tamaГ±o normal de mana bar
        if PlayerFrameManaBar then
            local hasVehicleUI = UnitHasVehicleUI("player")

            PlayerFrameManaBar:ClearAllPoints()
            PlayerFrameManaBar:SetSize(hasVehicleUI and 117 or 125, hasVehicleUI and 9 or 8)
            -- Restaurar anclaje por la izquierda (posiciГіn original)
            PlayerFrameManaBar:SetPoint('LEFT', PlayerPortrait, 'RIGHT', 1, -16.5)
        end
    end

    -- Don't create dragon if decoration is disabled
    if decorationType == "none" then
        return
    end

    -- Get dragon coordinates
    local coords = DRAGON_COORDINATES[decorationType]
    if not coords then

        return
    end

    -- Create HIGH strata frame for dragon (parented to PlayerFrame for scaling)
    local dragonParent = CreateFrame("Frame", nil, PlayerFrame)
    dragonParent:SetFrameStrata("MEDIUM")
    dragonParent:SetFrameLevel(1)
    dragonParent:SetSize(coords.size[1], coords.size[2])
    dragonParent:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", -coords.offset[1] + 29.5, coords.offset[2] - 5)

    -- Create dragon texture in high strata frame
    local dragon = dragonParent:CreateTexture(nil, "OVERLAY")
    dragon:SetTexture("Interface\\AddOns\\DragonUI\\Textures\\uiunitframeboss2x")
    dragon:SetTexCoord(coords.texCoord[1], coords.texCoord[2], coords.texCoord[3], coords.texCoord[4])
    dragon:SetAllPoints(dragonParent)

    -- Store references
    dragonFrame.PlayerDragonFrame = dragonParent
    dragonFrame.PlayerDragonDecoration = dragon

    UpdateLeadershipIcons() -- Reposicionar icons de liderazgo


end

-- Create custom NozdorUI textures and elements
local function CreatePlayerFrameTextures()
    local dragonFrame = _G["NozdorUIUnitframeFrame"]
    if not dragonFrame then
        dragonFrame = CreateFrame('FRAME', 'NozdorUIUnitframeFrame', UIParent)

    end

    HideBlizzardGlows()
    
    -- Create container for PvP icon to ensure it's above portrait border
    -- Parent to PlayerFrame but use higher frame level to be above portrait elements
    -- This ensures it's above the portrait border while staying within PlayerFrame's strata
    -- The container will inherit PlayerFrame's strata (MEDIUM) but can have a higher frame level
    if not dragonFrame.PvPIconContainer then
        local iconContainer = CreateFrame("Frame", "NozdorUI_PvPIconContainer", PlayerFrame)
        -- Don't set strata - it will inherit from PlayerFrame (MEDIUM)
        -- Set a high frame level relative to PlayerFrame to be above portrait elements
        -- Frame level will be updated in ChangePlayerframe() to match PlayerFrame's level
        iconContainer:SetFrameLevel(PlayerFrame:GetFrameLevel() + 50) -- Relative to PlayerFrame
        iconContainer:SetSize(64, 64)
        iconContainer:SetPoint("TOPRIGHT", PlayerFrame, "TOPRIGHT", -155, -22)
        iconContainer:Show()
        iconContainer:EnableMouse(false) -- Don't interfere with clicks
        dragonFrame.PvPIconContainer = iconContainer
    end

    if not dragonFrame.EliteIconContainer then
        local iconContainer = CreateFrame("Frame", "NozdorUI_EliteIconContainer", PlayerFrame)
        iconContainer:SetFrameStrata("HIGH")
        iconContainer:SetFrameLevel(1000)
        iconContainer:SetSize(200, 200)
        iconContainer:SetPoint("CENTER", PlayerFrame, "CENTER", 0, 0)
        dragonFrame.EliteIconContainer = iconContainer
    end

    if not dragonFrame.NozdorUICombatGlow then
        local combatFlashFrame = CreateFrame("Frame", "NozdorUICombatFlash", PlayerFrame)
        combatFlashFrame:SetFrameStrata("LOW")
        combatFlashFrame:SetFrameLevel(900)
        combatFlashFrame:SetSize(192, 71)
        combatFlashFrame:Hide()

        local combatTexture = combatFlashFrame:CreateTexture(nil, "OVERLAY")
        combatTexture:SetTexture(TEXTURES.BASE)
        combatTexture:SetTexCoord(0.1943359375, 0.3818359375, 0.169921875, 0.30859375)
        combatTexture:SetAllPoints(combatFlashFrame)
        combatTexture:SetBlendMode("ADD")
        combatTexture:SetVertexColor(1.0, 0.0, 0.0, 1.0)

        dragonFrame.NozdorUICombatGlow = combatFlashFrame
        dragonFrame.NozdorUICombatTexture = combatTexture


    end

    -- CREATE ELITE GLOW SYSTEM - Two glows using ELITE_GLOW_COORDINATES
    if not dragonFrame.EliteStatusGlow then
        -- Elite Status Glow (Yellow)
        local statusFrame = CreateFrame("Frame", "NozdorUIEliteStatusGlow", PlayerFrame)
        statusFrame:SetFrameStrata("LOW")
        statusFrame:SetFrameLevel(998)
        statusFrame:SetSize(ELITE_GLOW_COORDINATES.size[1], ELITE_GLOW_COORDINATES.size[2])
        statusFrame:Hide()

        local statusTexture = statusFrame:CreateTexture(nil, "OVERLAY")
        statusTexture:SetTexture(ELITE_GLOW_COORDINATES.texture) --  Usar desde coordenadas
        statusTexture:SetTexCoord(unpack(ELITE_GLOW_COORDINATES.texCoord))
        statusTexture:SetAllPoints(statusFrame)
        statusTexture:SetBlendMode("ADD")
        statusTexture:SetVertexColor(1.0, 0.8, 0.2, 0.6) -- Yellow

        dragonFrame.EliteStatusGlow = statusFrame
        dragonFrame.EliteStatusTexture = statusTexture

        -- Elite Combat Glow (Red with pulse)
        local combatFrame = CreateFrame("Frame", "NozdorUIEliteCombatGlow", PlayerFrame)
        combatFrame:SetFrameStrata("LOW")
        combatFrame:SetFrameLevel(900)
        combatFrame:SetSize(ELITE_GLOW_COORDINATES.size[1], ELITE_GLOW_COORDINATES.size[2])
        combatFrame:Hide()

        local eliteCombatTexture = combatFrame:CreateTexture(nil, "OVERLAY")
        eliteCombatTexture:SetTexture(ELITE_GLOW_COORDINATES.texture) --  Usar desde coordenadas
        eliteCombatTexture:SetTexCoord(unpack(ELITE_GLOW_COORDINATES.texCoord))
        eliteCombatTexture:SetAllPoints(combatFrame)
        eliteCombatTexture:SetBlendMode("ADD")
        eliteCombatTexture:SetVertexColor(1.0, 0.0, 0.0, 1.0) -- Red

        dragonFrame.EliteCombatGlow = combatFrame
        dragonFrame.EliteCombatTexture = eliteCombatTexture


    end

    -- Create background texture
    if not dragonFrame.PlayerFrameBackground then
        local background = PlayerFrame:CreateTexture('NozdorUIPlayerFrameBackground')
        background:SetDrawLayer('BACKGROUND', 2)
        background:SetTexture(TEXTURES.BASE)
        background:SetTexCoord(0.7890625, 0.982421875, 0.001953125, 0.140625)
        background:SetSize(198, 71)
        background:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -67, 0)
        dragonFrame.PlayerFrameBackground = background
    end

    -- Create border texture
    if not dragonFrame.PlayerFrameBorder then
        local border = PlayerFrameHealthBar:CreateTexture('NozdorUIPlayerFrameBorder')
        border:SetDrawLayer('OVERLAY', 5)
        border:SetTexture(TEXTURES.BORDER)
        border:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -67, -28.5)
        dragonFrame.PlayerFrameBorder = border
    end

    -- Create decoration texture
    if not dragonFrame.PlayerFrameDeco then
        local deco = PlayerFrame:CreateTexture('NozdorUIPlayerFrameDeco')
        deco:SetDrawLayer('OVERLAY', 5)
        deco:SetTexture(TEXTURES.BASE)
        deco:SetTexCoord(0.953125, 0.9755859375, 0.259765625, 0.3046875)
        deco:SetPoint('CENTER', PlayerPortrait, 'CENTER', 16, -16.5)
        deco:SetSize(23, 23)
        dragonFrame.PlayerFrameDeco = deco
    end

    -- Setup rest icon
    if not dragonFrame.PlayerRestIconOverride then
        PlayerRestIcon:SetTexture(TEXTURES.REST_ICON)
        PlayerRestIcon:ClearAllPoints()
        PlayerRestIcon:SetPoint("TOPLEFT", PlayerPortrait, "TOPLEFT", 40, 15)
        PlayerRestIcon:SetSize(28, 28)
        PlayerRestIcon:SetTexCoord(0, 0.125, 0, 0.125) -- First frame
        dragonFrame.PlayerRestIconOverride = true
    end

    -- Create group indicator
    if not dragonFrame.PlayerGroupIndicator then
        local groupIndicator = CreateFrame("Frame", "NozdorUIPlayerGroupIndicator", PlayerFrame)

        --  USAR TEXTURA uiunitframe como RetailUI
        local bgTexture = groupIndicator:CreateTexture(nil, "BACKGROUND")
        bgTexture:SetTexture(TEXTURES.BASE) -- Tu textura uiunitframe
        bgTexture:SetTexCoord(0.927734375, 0.9970703125, 0.3125, 0.337890625) --  Coordenadas del GroupIndicator
        bgTexture:SetAllPoints(groupIndicator)

        --  SIZING FIJO como en las coordenadas
        groupIndicator:SetSize(71, 13)
        groupIndicator:SetPoint("BOTTOMLEFT", PlayerFrame, "TOP", 30, -19.5)

        --  TEXTO CENTRADO como original
        local text = groupIndicator:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER", groupIndicator, "CENTER", 0, 0)
        text:SetJustifyH("CENTER")
        text:SetTextColor(1, 1, 1, 1)
        text:SetFont("Fonts\\FRIZQT__.TTF", 9)
        text:SetShadowOffset(1, -1)
        text:SetShadowColor(0, 0, 0, 1)

        groupIndicator.text = text
        groupIndicator.backgroundTexture = bgTexture
        groupIndicator:Hide()

        _G[PlayerFrame:GetName() .. 'GroupIndicator'] = groupIndicator
        _G[PlayerFrame:GetName() .. 'GroupIndicatorText'] = text
        _G[PlayerFrame:GetName() .. 'GroupIndicatorMiddle'] = bgTexture --  Como original
        dragonFrame.PlayerGroupIndicator = groupIndicator
    end

    -- Create role icon
    if not dragonFrame.PlayerRoleIcon then
        local roleIcon = PlayerFrame:CreateTexture(nil, "OVERLAY")
        roleIcon:SetSize(18, 18)
        roleIcon:SetPoint("TOPRIGHT", PlayerPortrait, "TOPRIGHT", -2, -2)
        roleIcon:Hide()
        dragonFrame.PlayerRoleIcon = roleIcon
    end

    -- Create text elements for health and mana bars
    local textElements = {{
        name = "PlayerFrameHealthBarTextLeft",
        parent = PlayerFrameHealthBar,
        point = "LEFT",
        x = 6,
        y = 0,
        justify = "LEFT"
    }, {
        name = "PlayerFrameHealthBarTextRight",
        parent = PlayerFrameHealthBar,
        point = "RIGHT",
        x = -6,
        y = 0,
        justify = "RIGHT"
    }, {
        name = "PlayerFrameManaBarTextLeft",
        parent = PlayerFrameManaBar,
        point = "LEFT",
        x = 6,
        y = 0,
        justify = "LEFT"
    }, {
        name = "PlayerFrameManaBarTextRight",
        parent = PlayerFrameManaBar,
        point = "RIGHT",
        x = -6,
        y = 0,
        justify = "RIGHT"
    }}

    for _, elem in ipairs(textElements) do
        if not dragonFrame[elem.name] then
            local text = elem.parent:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
            local font, size, flags = text:GetFont()
            if font and size then
                text:SetFont(font, size + 1, flags)
            end
            text:SetPoint(elem.point, elem.parent, elem.point, elem.x, elem.y)
            text:SetJustifyH(elem.justify)
            dragonFrame[elem.name] = text
        end
    end
    UpdatePlayerDragonDecoration()
end


-- Main frame configuration function
local function ChangePlayerframe()
    CreatePlayerFrameTextures()
    RemoveBlizzardFrames()
    HideBlizzardGlows()

    local hasVehicleUI = UnitHasVehicleUI("player")

    -- Keep PlayerFrame at standard strata (MEDIUM) to avoid appearing above other windows
    -- PlayerFrame.xml defines it as "BACKGROUND" strata, but MEDIUM is more appropriate for unit frames
    PlayerFrame:SetFrameStrata("MEDIUM")
    PlayerFrame:SetFrameLevel(10) -- Standard level for unit frames
    
    -- Update PvP icon container to ensure it stays within PlayerFrame's strata
    -- The container inherits MEDIUM strata from PlayerFrame but has a higher frame level
    local dragonFrame = _G["NozdorUIUnitframeFrame"]
    if dragonFrame and dragonFrame.PvPIconContainer then
        -- Ensure container stays within PlayerFrame's strata (no independent strata)
        -- Just update its frame level to be above portrait elements
        dragonFrame.PvPIconContainer:SetFrameLevel(PlayerFrame:GetFrameLevel() + 50)
    end
    
    -- When on vehicle, ensure portrait has higher frame level to prevent clipping behind world geometry
    -- Use PlayerFrame as parent but with higher frame level
    if hasVehicleUI then
        -- Just ensure portrait has higher level, no need for separate container
        -- The portrait will be above world geometry due to PlayerFrame's MEDIUM strata
        PlayerPortrait:SetParent(PlayerFrame)
    else
        -- When not on vehicle, parent portrait to PlayerFrame
        PlayerPortrait:SetParent(PlayerFrame)
    end

    -- Configure portrait
    PlayerPortrait:ClearAllPoints()
    PlayerPortrait:SetDrawLayer('ARTWORK', 5)
        PlayerPortrait:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 42, -15)
    PlayerPortrait:SetSize(hasVehicleUI and 62 or 56, hasVehicleUI and 62 or 56)
    
    -- When on vehicle, ensure portrait shows vehicle unit as 2D texture (like pet, not floating 3D model)
    -- Blizzard's UnitFrame_SetUnit sets unit to "vehicle", but we need to ensure portrait updates correctly
    if hasVehicleUI then
        -- Force update portrait to show vehicle as 2D texture
        -- This prevents the floating 3D model issue - portrait should be like pet portrait below PlayerFrame
        C_Timer.After(0.05, function()
            if UnitHasVehicleUI("player") and PlayerPortrait then
                -- Ensure portrait is updated to show vehicle unit
                SetPortraitTexture(PlayerPortrait, "vehicle")
            end
        end)
    end

    -- Position name and level
    PlayerName:ClearAllPoints()
    PlayerName:SetPoint('BOTTOMLEFT', PlayerFrameHealthBar, 'TOPLEFT', 0, 2)
    PlayerLevelText:ClearAllPoints()
    PlayerLevelText:SetPoint('BOTTOMRIGHT', PlayerFrameHealthBar, 'TOPRIGHT', -5, 3)

    -- Configure health bar
    PlayerFrameHealthBar:ClearAllPoints()
    PlayerFrameHealthBar:SetSize(hasVehicleUI and 117 or 125, 20)
    PlayerFrameHealthBar:SetPoint('LEFT', PlayerPortrait, 'RIGHT', 1, 0)

    -- Configure mana bar
    PlayerFrameManaBar:ClearAllPoints()
    PlayerFrameManaBar:SetSize(hasVehicleUI and 117 or 125, hasVehicleUI and 9 or 8)
    PlayerFrameManaBar:SetPoint('LEFT', PlayerPortrait, 'RIGHT', 1, -16.5)

    -- Set power bar texture based on type
    local powerType, powerTypeString = UnitPowerType('player')
    local powerTexture = TEXTURES.POWER_BARS[powerTypeString] or TEXTURES.POWER_BARS.MANA
    PlayerFrameManaBar:GetStatusBarTexture():SetTexture(powerTexture)

    -- Configure status and flash textures
    PlayerStatusTexture:SetTexture(TEXTURES.BASE)
    PlayerStatusTexture:SetSize(192, 71)
    PlayerStatusTexture:SetTexCoord(0.1943359375, 0.3818359375, 0.169921875, 0.30859375)
    PlayerStatusTexture:ClearAllPoints()

    local dragonFrame = _G["NozdorUIUnitframeFrame"]
    if dragonFrame and dragonFrame.PlayerFrameBorder then
        PlayerStatusTexture:SetPoint('TOPLEFT', PlayerPortrait, 'TOPLEFT', -9, 9)
    end

    if PlayerFrameFlash then
        PlayerFrameFlash:Hide()
        PlayerFrameFlash:SetAlpha(0)
    end

    -- Position our high-priority Combat Flash

    if dragonFrame and dragonFrame.NozdorUICombatGlow then
        dragonFrame.NozdorUICombatGlow:ClearAllPoints()
        dragonFrame.NozdorUICombatGlow:SetPoint('TOPLEFT', PlayerPortrait, 'TOPLEFT', -9, 9)
    end

    -- Position Elite Glows
    if dragonFrame and dragonFrame.EliteStatusGlow then
        dragonFrame.EliteStatusGlow:ClearAllPoints()
        dragonFrame.EliteStatusGlow:SetPoint('TOPLEFT', PlayerPortrait, 'TOPLEFT', -24, 20)
    end
    if dragonFrame and dragonFrame.EliteCombatGlow then
        dragonFrame.EliteCombatGlow:ClearAllPoints()
        dragonFrame.EliteCombatGlow:SetPoint('TOPLEFT', PlayerPortrait, 'TOPLEFT', -24, 20)
    end

    -- Setup class-specific elements
        SetupRuneFrame()
    UpdatePlayerRoleIcon()
    UpdateGroupIndicator()
    
    -- Determine correct unit based on vehicle state
    -- When in vehicle, PlayerFrame shows vehicle unit, PetFrame shows player unit
    local currentUnit = (PlayerFrame.state == "vehicle") and "vehicle" or "player"
    UpdateHealthBarColor(PlayerFrameHealthBar, currentUnit)
    UpdateManaBarColor(PlayerFrameManaBar)
    
    -- Update leadership icons position after all textures are created
    -- This ensures PvP icon draw layer is set correctly after border creation
    UpdateLeadershipIcons()
    
    -- Force update PvP icon position one more time to ensure it's above everything
    -- This is critical because the portrait border may be created/updated after our initial setup
    if PlayerPVPIcon then
        UpdatePVPIconPosition()
    end

    -- Hide Blizzard texts after frame configuration
    HideBlizzardPlayerTexts()


end

local function SetCombatFlashVisible(visible)
    local dragonFrame = _G["NozdorUIUnitframeFrame"]
    if not dragonFrame or not dragonFrame.PlayerFrameDeco then
        return
    end

    if visible then
        combatPulseTimer = 0 -- Reset pulse timer

        --  CAMBIAR DECORACIГ“N A ICONO DE COMBATE (espadas cruzadas)
        dragonFrame.PlayerFrameDeco:SetTexCoord(0.9775390625, 0.9931640625, 0.259765625, 0.291015625)
        --  AJUSTAR TAMAГ‘O PARA EL ICONO DE COMBATE
        dragonFrame.PlayerFrameDeco:SetSize(16, 16) -- MГЎs pequeГ±o que el original (23x23)
        dragonFrame.PlayerFrameDeco:SetPoint('CENTER', PlayerPortrait, 'CENTER', 18, -20)

    else
        --  RESTAURAR DECORACIГ“N NORMAL
        dragonFrame.PlayerFrameDeco:SetTexCoord(0.953125, 0.9755859375, 0.259765625, 0.3046875)
        --  RESTAURAR TAMAГ‘O ORIGINAL
        dragonFrame.PlayerFrameDeco:SetSize(23, 23) -- TamaГ±o original
        dragonFrame.PlayerFrameDeco:SetPoint('CENTER', PlayerPortrait, 'CENTER', 16, -16.5)

    end

    SetEliteCombatFlashVisible(visible) -- Use unified system
end

--  FUNCIГ“N PARA APLICAR POSICIГ“N DESDE WIDGETS (COMO MINIMAP)
local function ApplyWidgetPosition()

    if not Module.playerFrame then
        return
    end

    local widgetConfig = addon:GetConfigValue("widgets", "player")
    if not widgetConfig then
        -- Si no hay widgets config, usar defaults
        widgetConfig = {
            anchor = "TOPLEFT",
            posX = -19,
            posY = -4
        }
    end

        --  CLAVE: Posicionar el frame auxiliar
        Module.playerFrame:ClearAllPoints()
    Module.playerFrame:SetPoint(
        widgetConfig.anchor or "TOPLEFT", 
        UIParent, 
        widgetConfig.anchor or "TOPLEFT",
        widgetConfig.posX or -19,
        widgetConfig.posY or -4
    )

        --  CLAVE: Anclar PlayerFrame al auxiliar (sistema RetailUI)
    -- Allow SetPoint for our own positioning system
    PlayerFrame._NozdorUI_AllowSetPoint = true
        PlayerFrame:ClearAllPoints()
            PlayerFrame:SetPoint("CENTER", Module.playerFrame, "CENTER", -15, -7)
    PlayerFrame._NozdorUI_AllowSetPoint = false

    
end

-- Apply configuration settings
local function ApplyPlayerConfig()

    if not Module.initialized then
        InitializePlayerFrame()
    end
    
    local config = GetPlayerConfig()

    -- Aplicar escala (общий масштаб * индивидуальный масштаб)
    local generalScale = (addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.scale) or 1
    local individualScale = config.scale or 1.0
    PlayerFrame:SetScale(generalScale * individualScale)

    --  SIEMPRE usar posiciГіn de widgets (Editor Mode)
    ApplyWidgetPosition()

    -- Setup text system
    local dragonFrame = _G["NozdorUIUnitframeFrame"]
    if dragonFrame and addon.TextSystem then
        if not Module.textSystem then
            Module.textSystem = addon.TextSystem.SetupFrameTextSystem("player", "player", dragonFrame,
                PlayerFrameHealthBar, PlayerFrameManaBar, "PlayerFrame")
        end
        if Module.textSystem then
            Module.textSystem.update()
        end
    end

    UpdatePlayerDragonDecoration()
    UpdateGlowVisibility()

end

-- ============================================================================
-- PUBLIC API FUNCTIONS
-- ============================================================================

-- Reset frame to default configuration
local function ResetPlayerFrame()
    -- Usar defaults de database en lugar de DEFAULTS locales
    local dbDefaults = addon.defaults and addon.defaults.profile.unitframe.player or {}
    for key, value in pairs(dbDefaults) do
        addon:SetConfigValue("unitframe", "player", key, value)
    end
    ApplyPlayerConfig()

end

-- Refresh frame configuration
local function RefreshPlayerFrame()
    --  APLICAR CONFIGURACIГ“N INMEDIATAMENTE
    ApplyPlayerConfig()

    --  ACTUALIZAR CLASS COLOR
    UpdatePlayerHealthBarColor()

    --  ACTUALIZAR DECORACIГ“N DRAGON (importante para scale)
    UpdatePlayerDragonDecoration()

    --  ACTUALIZAR SISTEMA DE TEXTOS
    if Module.textSystem then
        Module.textSystem.update()
    end
    

end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function SetupPlayerClassColorHooks()
    if not _G.NozdorUI_PlayerHealthHookSetup then
        --  SOLO UN HOOK SIMPLE - cuando Blizzard actualiza la health bar
        -- Support both "player" and "vehicle" units for PlayerFrame
        hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
            if statusbar == PlayerFrameHealthBar then
                -- When in vehicle, PlayerFrame shows vehicle unit, PetFrame shows player unit
                -- Only apply class color for player unit, not vehicle
                if unit == "player" then
                UpdatePlayerHealthBarColor()
                elseif unit == "vehicle" then
                    -- Vehicle health bar - don't apply class color, just ensure it's visible
                    -- The unit is correctly set by Blizzard's PlayerFrame_ToVehicleArt
                end
            end
        end)

        _G.NozdorUI_PlayerHealthHookSetup = true

    end
end
-- Initialize the PlayerFrame module
local function InitializePlayerFrame()
    if Module.initialized then
        return
    end
    
    if _G.PlayerFrame_ToVehicleArt then
        hooksecurefunc("PlayerFrame_ToVehicleArt", function()
            -- Reconfigurar textures para vehГ­culo
            ChangePlayerframe()
            
            -- Ensure portrait shows vehicle as 2D texture (not floating 3D model)
            -- This should display like pet portrait below PlayerFrame
            C_Timer.After(0.05, function()
                if UnitHasVehicleUI("player") and PlayerPortrait then
                    SetPortraitTexture(PlayerPortrait, "vehicle")
                end
            end)
            
            C_Timer.After(0.1, function()
                if Module.playerFrame then
                    ApplyWidgetPosition()
                    local dragonFrame = _G["NozdorUIUnitframeFrame"]
                    if dragonFrame and dragonFrame.PvPIconContainer then
                        dragonFrame.PvPIconContainer:SetPoint("TOPRIGHT", PlayerFrame, "TOPRIGHT", -155, -22)
        end
    end
            end)
        end)
    end
    
    if _G.PlayerFrame_ToPlayerArt then
        hooksecurefunc("PlayerFrame_ToPlayerArt", function()
            ChangePlayerframe()
            C_Timer.After(0.1, function()
                if Module.playerFrame then
                    ApplyWidgetPosition()
                    local dragonFrame = _G["NozdorUIUnitframeFrame"]
                    if dragonFrame and dragonFrame.PvPIconContainer then
                        dragonFrame.PvPIconContainer:SetPoint("TOPRIGHT", PlayerFrame, "TOPRIGHT", -155, -22)
                    end
        end
    end)
        end)
    end

    -- Create auxiliary frame
    Module.playerFrame = addon.CreateUIFrame(200, 75, "player")

    -- Hook PlayerFrame.SetPoint to prevent position resets by Blizzard
    -- This ensures the frame position is always maintained from editor settings
    if not PlayerFrame._NozdorUI_SetPoint_Hooked then
        local originalSetPoint = PlayerFrame.SetPoint
        PlayerFrame.SetPoint = function(self, point, relativeTo, relativePoint, x, y)
            -- Allow SetPoint if we're positioning relative to Module.playerFrame (our system)
            if relativeTo == Module.playerFrame then
                originalSetPoint(self, point, relativeTo, relativePoint, x, y)
                return
            end
            
            -- Block any other SetPoint calls that would reset position
            -- Only allow if it's from our own ApplyWidgetPosition
            if not PlayerFrame._NozdorUI_AllowSetPoint then
                -- Silently ignore - position is controlled by editor
                return
            end
            
            -- Allow SetPoint if explicitly allowed
            PlayerFrame._NozdorUI_AllowSetPoint = false
            originalSetPoint(self, point, relativeTo, relativePoint, x, y)
        end
        PlayerFrame._NozdorUI_SetPoint_Hooked = true
    end

    --  REGISTRO AUTOMГЃTICO EN EL SISTEMA CENTRALIZADO
    addon:RegisterEditableFrame({
        name = "player",
        frame = Module.playerFrame,
        blizzardFrame = PlayerFrame,
        configPath = {"widgets", "player"},
        onHide = function()
            ApplyPlayerConfig() -- Aplicar nueva configuraciГіn al salir del editor
        end,
        module = Module
    })

    -- Setup frame hooks
    if PlayerFrame and PlayerFrame.HookScript then
        PlayerFrame:HookScript('OnUpdate', PlayerFrame_OnUpdate)
    end

    -- Hook Blizzard functions
    if _G.PlayerFrame_UpdateStatus then
        hooksecurefunc('PlayerFrame_UpdateStatus', PlayerFrame_UpdateStatus)
    end

    if _G.PlayerFrame_UpdateArt then
        hooksecurefunc("PlayerFrame_UpdateArt", function()
            ChangePlayerframe()
            C_Timer.After(0.1, function()
                if Module.playerFrame then
                    ApplyWidgetPosition()
                end
            end)
        end)
    end

    -- Setup bar hooks for persistent colors
    if PlayerFrameHealthBar and PlayerFrameHealthBar.HookScript then
        PlayerFrameHealthBar:HookScript('OnValueChanged', function(self)
            --  APLICAR CLASS COLOR EN CADA CAMBIO
            UpdatePlayerHealthBarColor()
        end)
        PlayerFrameHealthBar:HookScript('OnShow', function(self)
            --  APLICAR CLASS COLOR AL MOSTRAR
            UpdatePlayerHealthBarColor()
        end)
        -- Throttle OnUpdate to prevent freezes (update every 0.1 seconds instead of every frame)
        local healthBarUpdateElapsed = 0
        PlayerFrameHealthBar:HookScript('OnUpdate', function(self, elapsed)
            healthBarUpdateElapsed = healthBarUpdateElapsed + elapsed
            if healthBarUpdateElapsed >= 0.1 then
                healthBarUpdateElapsed = 0
            --  APLICAR CLASS COLOR EN UPDATES
            UpdatePlayerHealthBarColor()
            end
        end)
    end

    if PlayerFrameManaBar and PlayerFrameManaBar.HookScript then
        PlayerFrameManaBar:HookScript('OnValueChanged', UpdateManaBarColor)
    end

    -- Setup glow suppression hooks
    local glows = {PlayerStatusGlow, PlayerRestGlow}
    for _, glow in ipairs(glows) do
        if glow and glow.HookScript then
            glow:HookScript('OnShow', function(self)
                self:Hide()
                self:SetAlpha(0)
            end)
        end
    end

    -- Hide Blizzard texts after module initialization
    HideBlizzardPlayerTexts()

    Module.initialized = true

end

-- ============================================================================
-- EVENT SYSTEM
-- ============================================================================

-- Combined update function for efficiency
local function UpdateBothBars()
    -- Determine correct unit based on vehicle state
    local currentUnit = (PlayerFrame.state == "vehicle") and "vehicle" or "player"
    UpdateHealthBarColor(PlayerFrameHealthBar, currentUnit)
    UpdateManaBarColor(PlayerFrameManaBar)
end

-- Setup event handling system
local function SetupPlayerEvents()
    if Module.eventsFrame then
        return
    end

    local f = CreateFrame("Frame")
    Module.eventsFrame = f

    -- Event handlers
    local handlers = {
        PLAYER_REGEN_DISABLED = function()
            UpdateBothBars()
            SetCombatFlashVisible(true)
        end,

        PLAYER_REGEN_ENABLED = function()
            UpdateBothBars()
            SetCombatFlashVisible(false)
        end,

        ADDON_LOADED = function(addonName)
            if addonName == "NozdorUI" then
                InitializePlayerFrame()
            end
        end,
        
        VARIABLES_LOADED = function()
            if not Module.initialized then
                InitializePlayerFrame()
            end
        end,

        PLAYER_ENTERING_WORLD = function()
            if not Module.initialized then
                InitializePlayerFrame()
            end
            ChangePlayerframe()
            ApplyPlayerConfig()
            -- Ensure Blizzard texts are hidden after entering world
            HideBlizzardPlayerTexts()
        end,
        
        PLAYER_LOGIN = function()
            if not Module.initialized then
                InitializePlayerFrame()
            end
        end,

        RUNE_TYPE_UPDATE = function(runeIndex)
            if runeIndex then
                UpdateRune(_G['RuneButtonIndividual' .. runeIndex])
            end
        end,

        GROUP_ROSTER_UPDATE = UpdateGroupIndicator,
        ROLE_CHANGED_INFORM = UpdatePlayerRoleIcon,
        LFG_ROLE_UPDATE = UpdatePlayerRoleIcon,

        UNIT_AURA = function(unit)
            if unit == "player" then
                UpdateBothBars()
            end
        end
    }

    -- Register events
    for event in pairs(handlers) do
        f:RegisterEvent(event)
    end

    for event in pairs(HEALTH_EVENTS) do
        f:RegisterEvent(event)
    end

    for event in pairs(POWER_EVENTS) do
        f:RegisterEvent(event)
    end

    -- Event dispatcher
    f:SetScript("OnEvent", function(_, event, ...)
        local handler = handlers[event]
        if handler then
            handler(...)
            return
        end

        local unit = ...
        if unit ~= "player" then
            return
        end

        if HEALTH_EVENTS[event] then
            -- Determine correct unit based on vehicle state
            local currentUnit = (PlayerFrame.state == "vehicle") and "vehicle" or "player"
            UpdateHealthBarColor(PlayerFrameHealthBar, currentUnit)
        elseif POWER_EVENTS[event] then
            UpdateManaBarColor(PlayerFrameManaBar)
            UpdatePowerBarTexture(PlayerFrameManaBar)
        end
    end)


end


-- ============================================================================
-- MODULE STARTUP
-- ============================================================================

-- Initialize event system
SetupPlayerEvents()
SetupPlayerClassColorHooks()

if not Module.initialized then
    if PlayerFrame then
        InitializePlayerFrame()
                end
end

-- Hide Blizzard texts after initialization
HideBlizzardPlayerTexts()

-- Expose public API
addon.PlayerFrame = {
    Refresh = RefreshPlayerFrame,
    RefreshPlayerFrame = RefreshPlayerFrame,
    Reset = ResetPlayerFrame,
    anchor = function()
        return Module.playerFrame
    end,
    ChangePlayerframe = ChangePlayerframe,
    CreatePlayerFrameTextures = CreatePlayerFrameTextures,
    UpdatePlayerHealthBarColor = UpdatePlayerHealthBarColor
}



--  FUNCIONES EDITOR MODE ELIMINADAS - AHORA USA SISTEMA CENTRALIZADO

