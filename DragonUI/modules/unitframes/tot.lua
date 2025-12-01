-- Get addon reference - either from XML parameter or global
local addon = select(2, ...);

-- ============================================================================
-- NOZDORUI TARGET OF TARGET FRAME MODULE - WoW 3.3.5a
-- ============================================================================

local Module = {
    totFrame = nil,
    textSystem = nil,
    initialized = false,
    configured = false,
    eventsFrame = nil
}

-- ============================================================================
-- CONFIGURATION & CONSTANTS
-- ============================================================================

-- Cache Blizzard frames
local TargetFrameToT = _G.TargetFrameToT

-- Texture paths (ToT específicas)
local TEXTURES = {
    BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BACKGROUND",
    BORDER = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER",
    BAR_PREFIX = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-",
    BOSS = "Interface\\AddOns\\DragonUI\\Textures\\uiunitframeboss2x"
}

-- Boss classifications (coordenadas ToT más pequeñas)
local BOSS_COORDS = {
    elite = {0.001953125, 0.314453125, 0.322265625, 0.630859375, 60, 59, 3, 1},
    rare = {0.00390625, 0.31640625, 0.64453125, 0.953125, 60, 59, 3, 1},
    rareelite = {0.001953125, 0.388671875, 0.001953125, 0.31835937, 74, 61, 10, 1}
}

-- Power types
local POWER_MAP = {
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [6] = "RunicPower"
}

-- Frame elements storage
local frameElements = {
    background = nil,
    border = nil,
    elite = nil
}

-- Update throttling
local updateCache = {
    lastHealthUpdate = 0,
    lastPowerUpdate = 0
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function GetConfig()
    return addon:GetConfigValue("unitframe", "tot") or {}
end

-- ============================================================================
-- UTILITY FUNCTIONS FOR CENTRALIZED SYSTEM
-- ============================================================================

--  FUNCIÓN PARA APLICAR POSICIÓN DESDE WIDGETS
local function ApplyWidgetPosition()
    if not Module.totFrame then
        return
    end

    local widgetConfig = addon.db and addon.db.profile.widgets and addon.db.profile.widgets.tot
    
    if widgetConfig then
        Module.totFrame:ClearAllPoints()
        local anchorFrame = _G[widgetConfig.anchorFrame] or TargetFrame or UIParent
        Module.totFrame:SetPoint(widgetConfig.anchor or "BOTTOMRIGHT", anchorFrame, widgetConfig.anchorParent or "BOTTOMRIGHT", 
                               widgetConfig.posX or 22, widgetConfig.posY or -15)
        
        -- Также aplicar al frame de Blizzard
        if TargetFrameToT then
            TargetFrameToT:ClearAllPoints()
            TargetFrameToT:SetPoint("CENTER", Module.totFrame, "CENTER", 0, 0)
        end
    else
        -- Fallback a posición por defecto
        Module.totFrame:ClearAllPoints()
        local anchorFrame = TargetFrame or UIParent
        Module.totFrame:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", 22, -15)
        if TargetFrameToT then
            TargetFrameToT:ClearAllPoints()
            TargetFrameToT:SetPoint("CENTER", Module.totFrame, "CENTER", 0, 0)
        end
    end
end

--  FUNCIÓN PARA VERIFICAR SI EL TOT FRAME DEBE ESTAR VISIBLE
local function ShouldToTFrameBeVisible()
    return UnitExists("target") and UnitExists("targettarget")
end

--  FUNCIONES DE TESTEO
local function ShowToTFrameTest()
    -- Mostrar el frame aunque no haya targettarget
    if TargetFrameToT then
        TargetFrameToT:Show()
    end
end

local function HideToTFrameTest()
    -- Ocultar el frame de prueba
    if TargetFrameToT then
        TargetFrameToT:Hide()
    end
end

-- ============================================================================
-- BAR MANAGEMENT (IGUAL QUE TARGET/FOCUS)
-- ============================================================================

local function SetupBarHooks()
    -- Health bar hooks (igual que tu target.lua)
    if not TargetFrameToTHealthBar.NozdorUI_Setup then
        local healthTexture = TargetFrameToTHealthBar:GetStatusBarTexture()
        if healthTexture then
            healthTexture:SetDrawLayer("ARTWORK", 1)
        end

        hooksecurefunc(TargetFrameToTHealthBar, "SetValue", function(self)
    if not UnitExists("targettarget") then
        return
    end

    local now = GetTime()
    if now - updateCache.lastHealthUpdate < 0.05 then
        return
    end
    updateCache.lastHealthUpdate = now

    local texture = self:GetStatusBarTexture()
    if not texture then
        return
    end

    local config = GetConfig()
    local texturePath
    
    -- NUEVO: Decidir qué textura usar basado en classcolor
    if config.classcolor and UnitIsPlayer("targettarget") then
        texturePath = TEXTURES.BAR_PREFIX .. "Health-Status"  -- Versión Status para colores de clase
    else
        texturePath = TEXTURES.BAR_PREFIX .. "Health"         -- Versión normal
    end

    -- Update texture
    if texture:GetTexture() ~= texturePath then
        texture:SetTexture(texturePath)
        texture:SetDrawLayer("ARTWORK", 1)
    end

    -- Update coords
    local min, max = self:GetMinMaxValues()
    local current = self:GetValue()
    if max > 0 and current then
        texture:SetTexCoord(0, current / max, 0, 1)
    end

    -- Update color
    if config.classcolor and UnitIsPlayer("targettarget") then
        local _, class = UnitClass("targettarget")
        local color = RAID_CLASS_COLORS[class]
        if color then
            texture:SetVertexColor(color.r, color.g, color.b)
        else
            texture:SetVertexColor(1, 1, 1)
        end
    else
        texture:SetVertexColor(1, 1, 1)
    end
end)

        TargetFrameToTHealthBar.NozdorUI_Setup = true
    end

    -- Power bar hooks (igual que tu target.lua)
    if not TargetFrameToTManaBar.NozdorUI_Setup then
        local powerTexture = TargetFrameToTManaBar:GetStatusBarTexture()
        if powerTexture then
            powerTexture:SetDrawLayer("ARTWORK", 1)
        end

        hooksecurefunc(TargetFrameToTManaBar, "SetValue", function(self)
            if not UnitExists("targettarget") then
                return
            end

            local now = GetTime()
            if now - updateCache.lastPowerUpdate < 0.05 then
                return
            end
            updateCache.lastPowerUpdate = now

            local texture = self:GetStatusBarTexture()
            if not texture then
                return
            end

            -- Update texture based on power type
            local powerType = UnitPowerType("targettarget")
            local powerName = POWER_MAP[powerType] or "Mana"
            local texturePath = TEXTURES.BAR_PREFIX .. powerName

            if texture:GetTexture() ~= texturePath then
                texture:SetTexture(texturePath)
                texture:SetDrawLayer("ARTWORK", 1)
            end

            -- Update coords
            local min, max = self:GetMinMaxValues()
            local current = self:GetValue()
            if max > 0 and current then
                texture:SetTexCoord(0, current / max, 0, 1)
            end

            -- Force white color
            texture:SetVertexColor(1, 1, 1)
        end)

        TargetFrameToTManaBar.NozdorUI_Setup = true
    end
end

-- ============================================================================
-- CLASSIFICATION SYSTEM 
-- ============================================================================

local function UpdateClassification()
    if not UnitExists("targettarget") or not frameElements.elite then
        if frameElements.elite then
            frameElements.elite:Hide()
        end
        return
    end

    local classification = UnitClassification("targettarget")
    local coords = nil

    -- Check vehicle first
    if UnitVehicleSeatCount and UnitVehicleSeatCount("targettarget") > 0 then
        frameElements.elite:Hide()
        return
    end

    -- Determine classification
    if classification == "worldboss" or classification == "elite" then
        coords = BOSS_COORDS.elite
    elseif classification == "rareelite" then
        coords = BOSS_COORDS.rareelite
    elseif classification == "rare" then
        coords = BOSS_COORDS.rare
    else
        local name = UnitName("targettarget")
        if name and addon.unitframe and addon.unitframe.famous and addon.unitframe.famous[name] then
            coords = BOSS_COORDS.elite
        end
    end

    if coords then
        frameElements.elite:SetTexture(TEXTURES.BOSS) --  AÑADIDO: SetTexture

        --  APLICAR FLIP HORIZONTAL A TODAS LAS DECORACIONES
        local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
        frameElements.elite:SetTexCoord(right, left, top, bottom) --  FLIPPED: right, left en lugar de left, right

        --  USAR VALORES CORREGIDOS DEL DEBUG
        frameElements.elite:SetSize(51, 51) -- En lugar de coords[5], coords[6]
        frameElements.elite:SetPoint("CENTER", TargetFrameToTPortrait, "CENTER", -4, -2) -- En lugar de coords[7], coords[8]
        frameElements.elite:SetDrawLayer("OVERLAY", 11) --  FORZAR DRAW LAYER
        frameElements.elite:Show()
        frameElements.elite:SetAlpha(1) --  ASEGURAR VISIBILIDAD
    else
        frameElements.elite:Hide()
    end
end

-- ============================================================================
-- FRAME INITIALIZATION (IGUAL QUE TARGET/FOCUS)
-- ============================================================================

local function InitializeFrame()
    if Module.configured then
        return
    end

    -- Verificar que ToT existe
    if not TargetFrameToT then
        
        return
    end

    -- Get configuration
    local config = GetConfig()

    -- CRITICAL: Use anchor frame if available (editor system)
    if Module.totFrame then
        -- Apply position from widgets
        ApplyWidgetPosition()
        
        -- Position TargetFrameToT relative to anchor
        TargetFrameToT:ClearAllPoints()
        TargetFrameToT:SetPoint("CENTER", Module.totFrame, "CENTER", 0, 0)
    else
        -- Fallback to legacy positioning
        TargetFrameToT:ClearAllPoints()
        TargetFrameToT:SetPoint(config.anchor or "BOTTOMRIGHT", TargetFrame, config.anchorParent or "BOTTOMRIGHT", config.x or 22, config.y or -15)
    end
    
    local generalScale = (addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.scale) or 1
    local individualScale = config.scale or 1
    TargetFrameToT:SetScale(generalScale * individualScale)

    -- Hide Blizzard elements
    local toHide = {TargetFrameToTTextureFrameTexture, TargetFrameToTBackground}

    for _, element in ipairs(toHide) do
        if element then
            element:SetAlpha(0)
            element:Hide()
        end
    end

    -- Create background texture
    if not frameElements.background then
        frameElements.background = TargetFrameToT:CreateTexture("NozdorUI_ToTBG", "BACKGROUND", nil, 0)
        frameElements.background:SetTexture(TEXTURES.BACKGROUND)
        frameElements.background:SetPoint('LEFT', TargetFrameToTPortrait, 'CENTER', -25 + 1, -10)
    end

    -- Create border texture
    if not frameElements.border then
        frameElements.border = TargetFrameToTHealthBar:CreateTexture("NozdorUI_ToTBorder", "OVERLAY", nil, 1)
        frameElements.border:SetTexture(TEXTURES.BORDER)
        frameElements.border:SetPoint('LEFT', TargetFrameToTPortrait, 'CENTER', -25 + 1, -10)
        frameElements.border:Show()
        frameElements.border:SetAlpha(1)
    end

    -- Create elite decoration
    if not frameElements.elite then
        local eliteFrame = CreateFrame("Frame", "NozdorUI_ToTEliteFrame", TargetFrameToT)
        eliteFrame:SetFrameStrata("MEDIUM")
        eliteFrame:SetAllPoints(TargetFrameToTPortrait)

        frameElements.elite = eliteFrame:CreateTexture("NozdorUI_ToTElite", "OVERLAY", nil, 1)
        frameElements.elite:SetTexture(TEXTURES.BOSS)
        frameElements.elite:Hide()
    end
    -- Configure health bar
    TargetFrameToTHealthBar:Hide()
    TargetFrameToTHealthBar:ClearAllPoints()
    TargetFrameToTHealthBar:SetParent(TargetFrameToT)
    TargetFrameToTHealthBar:SetFrameStrata("LOW")
    TargetFrameToTHealthBar:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
    TargetFrameToTHealthBar:GetStatusBarTexture():SetTexture(TEXTURES.BAR_PREFIX .. "Health")
    TargetFrameToTHealthBar.SetStatusBarColor = function()
    end -- noop
    TargetFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
    TargetFrameToTHealthBar:SetSize(70.5, 10)
    TargetFrameToTHealthBar:SetPoint('LEFT', TargetFrameToTPortrait, 'RIGHT', 1 + 1, 0)
    TargetFrameToTHealthBar:Show()

    -- Configure power bar
    TargetFrameToTManaBar:Hide()
    TargetFrameToTManaBar:ClearAllPoints()
    TargetFrameToTManaBar:SetParent(TargetFrameToT)
    TargetFrameToTManaBar:SetFrameStrata("LOW")
    TargetFrameToTManaBar:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
    TargetFrameToTManaBar:GetStatusBarTexture():SetTexture(TEXTURES.BAR_PREFIX .. "Mana")
    TargetFrameToTManaBar.SetStatusBarColor = function()
    end -- noop
    TargetFrameToTManaBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
    TargetFrameToTManaBar:SetSize(74, 7.5)
    TargetFrameToTManaBar:SetPoint('LEFT', TargetFrameToTPortrait, 'RIGHT', 1 - 2 - 1.5 + 1, 2 - 10 - 1)
    TargetFrameToTManaBar:Show()

    -- Configure name text
    if TargetFrameToTTextureFrameName then
        TargetFrameToTTextureFrameName:ClearAllPoints()
        TargetFrameToTTextureFrameName:SetPoint('LEFT', TargetFrameToTPortrait, 'RIGHT', 3, 13)
        TargetFrameToTTextureFrameName:SetParent(TargetFrameToT)
        TargetFrameToTTextureFrameName:Show()
        local font, size, flags = TargetFrameToTTextureFrameName:GetFont()
        if font and size then
            TargetFrameToTTextureFrameName:SetFont(font, math.max(size, 10), flags)
        end
        TargetFrameToTTextureFrameName:SetTextColor(1.0, 0.82, 0.0, 1.0)
        TargetFrameToTTextureFrameName:SetDrawLayer("BORDER", 1)

        --  TRUNCADO AUTOMÁTICO COMO RETAILUI
        TargetFrameToTTextureFrameName:SetWidth(65)
        TargetFrameToTTextureFrameName:SetJustifyH("LEFT")
    end

    -- Force debuff positions if needed
    if TargetFrameToTDebuff1 then
        TargetFrameToTDebuff1:ClearAllPoints()
        TargetFrameToTDebuff1:SetPoint("TOPLEFT", TargetFrameToT, "BOTTOMLEFT", 120, 35)
    end

    -- Setup bar hooks
    SetupBarHooks()
end

-- ============================================================================
-- EVENT HANDLING (IGUAL QUE TARGET/FOCUS)
-- ============================================================================

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "NozdorUI" and not Module.initialized then
            -- CRITICAL: Use CreateUIFrame for editor system integration
            Module.totFrame = addon.CreateUIFrame(120, 47, "tot")
            
            --  PERSONALIZAR TEXTO PARA TOT
            if Module.totFrame.editorText then
                Module.totFrame.editorText:SetText("Цель цели")
            end
            
            -- Apply position from widgets
            ApplyWidgetPosition()
            
            --  EXPORTAR ApplyWidgetPosition AL MODULE PARA ACCESO DESDE CORE.LUA
            Module.ApplyWidgetPosition = ApplyWidgetPosition
            
            --  REGISTRO EN SISTEMA CENTRALIZADO
            addon:RegisterEditableFrame({
                name = "tot",
                frame = Module.totFrame,
                blizzardFrame = TargetFrameToT,
                configPath = {"widgets", "tot"},
                hasTarget = ShouldToTFrameBeVisible,
                showTest = ShowToTFrameTest,
                hideTest = HideToTFrameTest,
                onHide = function()
                    ApplyWidgetPosition()
                end,
                module = Module
            })
            
            Module.initialized = true
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeFrame()
        if UnitExists("targettarget") then

            UpdateClassification()
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Target cambió, forzar update del ToT

        UpdateClassification()
        if Module.textSystem then
            Module.textSystem.update()
        end

    elseif event == "UNIT_TARGET" then
        local unit = ...
        if unit == "target" then -- El target del target cambió

            UpdateClassification()
            if Module.textSystem then
                Module.textSystem.update()
            end
        end

    elseif event == "UNIT_CLASSIFICATION_CHANGED" then
        local unit = ...
        if unit == "targettarget" then
            UpdateClassification()
        end

    elseif event == "UNIT_FACTION" then
        local unit = ...
        if unit == "targettarget" then
            -- No tenemos name background como target, pero podrías agregarlo
        end
    end
end

-- Initialize events
if not Module.eventsFrame then
    Module.eventsFrame = CreateFrame("Frame")
    Module.eventsFrame:RegisterEvent("ADDON_LOADED")
    Module.eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Module.eventsFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_TARGET") -- Crucial para ToT
    Module.eventsFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_FACTION")
    Module.eventsFrame:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- PUBLIC API (IGUAL QUE TARGET/FOCUS)
-- ============================================================================

local function RefreshFrame()
    if not Module.configured then
        InitializeFrame()
    end

    -- CRITICAL: Apply position from widgets if anchor frame exists
    if Module.totFrame then
        ApplyWidgetPosition()
    end

    if UnitExists("targettarget") then
        UpdateClassification()
        if Module.textSystem then
            Module.textSystem.update()
        end
    end
end

local function ResetFrame()
    -- Reset a valores por defecto de la DB
    addon:SetConfigValue("unitframe", "tot", "x", 22)
    addon:SetConfigValue("unitframe", "tot", "y", -15)
    addon:SetConfigValue("unitframe", "tot", "scale", 1.0)

    --  RESETEAR WIDGETS TAMBIÉN
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    local defaults = addon.defaults and addon.defaults.profile.widgets.tot
    if defaults then
        addon.db.profile.widgets.tot = {
            anchor = defaults.anchor or "BOTTOMRIGHT",
            anchorParent = defaults.anchorParent or "BOTTOMRIGHT",
            anchorFrame = defaults.anchorFrame or "TargetFrame",
            posX = defaults.posX or 22,
            posY = defaults.posY or -15
        }
    else
        addon.db.profile.widgets.tot = {
            anchor = "BOTTOMRIGHT",
            anchorParent = "BOTTOMRIGHT",
            anchorFrame = "TargetFrame",
            posX = 22,
            posY = -15
        }
    end

    -- Aplicar inmediatamente
    local config = GetConfig()
    if Module.totFrame then
        ApplyWidgetPosition()
        TargetFrameToT:ClearAllPoints()
        TargetFrameToT:SetPoint("CENTER", Module.totFrame, "CENTER", 0, 0)
    else
        TargetFrameToT:ClearAllPoints()
        TargetFrameToT:SetPoint(config.anchor or "BOTTOMRIGHT", TargetFrame, config.anchorParent or "BOTTOMRIGHT", config.x or 22, config.y or -15)
    end
    local generalScale = (addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.scale) or 1
    local individualScale = config.scale or 1
    TargetFrameToT:SetScale(generalScale * individualScale)
end

-- Export API (igual que target/focus)
addon.TargetOfTarget = {
    Refresh = RefreshFrame,
    RefreshToTFrame = RefreshFrame,
    Reset = ResetFrame,
    anchor = function()
        return Module.totFrame
    end,
    ChangeToTFrame = RefreshFrame
}

-- Legacy compatibility
addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeToT = RefreshFrame
addon.unitframe.ReApplyToTFrame = RefreshFrame
addon.unitframe.StyleToTFrame = InitializeFrame

function addon:RefreshToTFrame()
    RefreshFrame()
end


