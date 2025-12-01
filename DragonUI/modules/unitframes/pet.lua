-- ===============================================================
-- NOZDORUI PET FRAME MODULE - OPTIMIZED WITH TEXT SYSTEM
-- ===============================================================
-- Get addon reference - either from XML parameter or global
local addon = select(2, ...);
local PetFrameModule = {}
addon.PetFrameModule = PetFrameModule

-- ===============================================================
-- LOCALIZED API REFERENCES
-- ===============================================================
local _G = _G
local CreateFrame = CreateFrame
local UIParent = UIParent
local PlayerFrame = _G.PlayerFrame
local UnitExists = UnitExists
local UnitPowerType = UnitPowerType
local hooksecurefunc = hooksecurefunc

-- ===============================================================
-- MODULE CONSTANTS
-- ===============================================================
local TEXTURE_PATH = 'Interface\\AddOns\\DragonUI\\Textures\\'
local UNITFRAME_PATH = TEXTURE_PATH .. 'Unitframe\\'
local ATLAS_TEXTURE = TEXTURE_PATH .. 'uiunitframe'
local TOT_BASE = 'UI-HUD-UnitFrame-TargetofTarget-PortraitOn-'

local POWER_TEXTURES = {
    MANA = UNITFRAME_PATH .. TOT_BASE .. 'Bar-Mana',
    FOCUS = UNITFRAME_PATH .. TOT_BASE .. 'Bar-Focus',
    RAGE = UNITFRAME_PATH .. TOT_BASE .. 'Bar-Rage',
    ENERGY = UNITFRAME_PATH .. TOT_BASE .. 'Bar-Energy',
    RUNIC_POWER = UNITFRAME_PATH .. TOT_BASE .. 'Bar-RunicPower'
}

local COMBAT_TEX_COORDS = {0.3095703125, 0.4208984375, 0.3125, 0.404296875}

-- ===============================================================
-- ANIMACIONES COMBAT PULSE
-- ===============================================================

--  CONFIGURACIÓN PARA PULSO DE COLOR
local COMBAT_PULSE_SETTINGS = {
    speed = 9,              -- Velocidad del latido
    minIntensity = 0.3,     -- Intensidad mínima del rojo (0.4 = rojo oscuro)
    maxIntensity = 0.7,     -- Intensidad máxima del rojo (1.0 = rojo brillante)
    enabled = true          -- Activar/desactivar animación
}

--  VARIABLE DE ESTADO
local combatPulseTimer = 0


-- ===============================================================
-- NUEVA FUNCIÓN DE ANIMACIÓN CON CAMBIO DE COLOR
-- ===============================================================
local function AnimatePetCombatPulse(elapsed)
    if not COMBAT_PULSE_SETTINGS.enabled then
        return
    end
    
    local texture = _G.PetAttackModeTexture
    if not texture or not texture:IsVisible() then
        return
    end
    
    -- Incrementar timer
    combatPulseTimer = combatPulseTimer + (elapsed * COMBAT_PULSE_SETTINGS.speed)
    
    -- Calcular intensidad del rojo usando función seno
    local intensity = COMBAT_PULSE_SETTINGS.minIntensity + 
                     (COMBAT_PULSE_SETTINGS.maxIntensity - COMBAT_PULSE_SETTINGS.minIntensity) * 
                     (math.sin(combatPulseTimer) * 0.5 + 0.5)
    
    --  CAMBIAR COLOR EN LUGAR DE ALPHA
    texture:SetVertexColor(intensity, 0.0, 0.0, 1.0)
end

-- ===============================================================
-- MODULE STATE
-- ===============================================================
local moduleState = {
    frame = {},
    hooks = {},
    textSystem = nil
}

-- ===============================================================
-- UTILITY FUNCTIONS
-- ===============================================================
local function noop() end

-- ===============================================================
-- CENTRALIZED SYSTEM INTEGRATION (forward declarations)
-- ===============================================================

-- Variables para el sistema centralizado
PetFrameModule.anchor = nil
PetFrameModule.initialized = false

--  FUNCIÓN PARA APLICAR POSICIÓN DESDE WIDGETS (КАК В player.lua)
local function ApplyWidgetPosition()
    if not PetFrameModule.anchor then
        return
    end
    
    -- Использовать GetConfigValue как в player.lua
    local widgetConfig = addon:GetConfigValue("widgets", "pet")
    if not widgetConfig then
        -- Si no hay widgets config, usar defaults (прямо под player frame)
        widgetConfig = {
            anchor = "TOPLEFT",
            posX = -19,
            posY = -104
        }
    end

    -- Применить позицию относительно UIParent (как в player.lua)
    PetFrameModule.anchor:ClearAllPoints()
    PetFrameModule.anchor:SetPoint(
        widgetConfig.anchor or "TOPLEFT", 
        UIParent, 
        widgetConfig.anchor or "TOPLEFT",
        widgetConfig.posX or -19,
        widgetConfig.posY or -104
    )
end

-- Create auxiliary frame for anchoring (como party.lua y castbar.lua)
local function CreatePetAnchorFrame()
    if PetFrameModule.anchor then
        return PetFrameModule.anchor
    end

    -- Убедиться, что конфигурация по умолчанию загружена ПЕРЕД созданием фрейма
    PetFrameModule:LoadDefaultSettings()

    --  USAR FUNCIÓN CENTRALIZADA DE CORE.LUA
    PetFrameModule.anchor = addon.CreateUIFrame(130, 44, "pet")
    
    --  PERSONALIZAR TEXTO PARA PET FRAME
    if PetFrameModule.anchor.editorText then
        PetFrameModule.anchor.editorText:SetText("Рамка питомца")
    end
    
    -- Сразу применить правильную позицию (перезаписать любую позицию из CreateUIFrame)
    ApplyWidgetPosition()
    
    -- Убедиться, что anchor показан
    PetFrameModule.anchor:Show()
    
    return PetFrameModule.anchor
end

-- ===============================================================
-- FRAME POSITIONING
-- ===============================================================
local function ApplyFramePositioning()
    local config = addon.db and addon.db.profile.unitframe.pet
    if not PetFrame then return end
    
    -- Убедиться, что anchor создан и позиционирован
    if not PetFrameModule.anchor then
        CreatePetAnchorFrame()
    end
    if PetFrameModule.anchor then
        ApplyWidgetPosition()
    end
    
    if config then
        local generalScale = (addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.scale) or 1
        local individualScale = config.scale or 1.0
        PetFrame:SetScale(generalScale * individualScale)
    end
    
    --  PRIORIDAD: Usar anchor frame si existe (sistema centralizado)
    if PetFrameModule.anchor then
        PetFrame:ClearAllPoints()
        PetFrame:SetPoint("CENTER", PetFrameModule.anchor, "CENTER", 0, 0)
        
    elseif config and config.override then
        --  FALLBACK: Sistema legacy de configuración manual
        PetFrame:ClearAllPoints()
        local anchor = config.anchorFrame and _G[config.anchorFrame] or UIParent
        PetFrame:SetPoint(
            config.anchor or "TOPRIGHT",
            anchor,
            config.anchorParent or "BOTTOMRIGHT",
            config.x or 0,
            config.y or 0
        )
        PetFrame:SetMovable(true)
        PetFrame:EnableMouse(true)
        
    else
        
    end
end

-- ===============================================================
-- POWER BAR MANAGEMENT
-- ===============================================================
local function UpdatePowerBarTexture()
    if not UnitExists("pet") or not PetFrameManaBar then return end
    
    local _, powerType = UnitPowerType('pet')
    local texture = POWER_TEXTURES[powerType]
    
    if texture then
        local statusBar = PetFrameManaBar:GetStatusBarTexture()
        statusBar:SetTexture(texture)
        statusBar:SetVertexColor(1, 1, 1, 1)
    end
end

-- ===============================================================
-- COMBAT MODE TEXTURE
-- ===============================================================
local function ConfigureCombatMode()
    local texture = _G.PetAttackModeTexture
    if not texture then return end
    
    texture:SetTexture(ATLAS_TEXTURE)
    texture:SetTexCoord(unpack(COMBAT_TEX_COORDS))
    texture:SetVertexColor(1.0, 0.0, 0.0, 1.0)  -- Color inicial
    texture:SetBlendMode("ADD")
    texture:SetAlpha(0.8)  -- Alpha fijo
    texture:SetDrawLayer("OVERLAY", 9)
    texture:ClearAllPoints()
    texture:SetPoint('CENTER', PetFrame, 'CENTER', -7, -2)
    texture:SetSize(114, 47)
    
    --  REINICIAR TIMER
    combatPulseTimer = 0
end

-- ===============================================================
-- FUNCIÓN OnUpdate PARA EL PET FRAME
-- ===============================================================
local function PetFrame_OnUpdate(self, elapsed)
    -- Throttle updates to prevent freezes (update every 0.1 seconds instead of every frame)
    self.updateElapsed = (self.updateElapsed or 0) + elapsed
    if self.updateElapsed < 0.1 then
        return
    end
    self.updateElapsed = 0
    
    local success, err = pcall(function()
        AnimatePetCombatPulse(elapsed)
    end)
    
    if not success then
        
    end
end

-- ===============================================================
-- THREAT GLOW SYSTEM 
-- ===============================================================
local function ConfigurePetThreatGlow()
    --  El pet frame usa PetFrameFlash para el threat glow
    local threatFlash = _G.PetFrameFlash
    if not threatFlash then return end
    
    --  APLICAR TU TEXTURA PERSONALIZADA
    threatFlash:SetTexture(ATLAS_TEXTURE)  
    threatFlash:SetTexCoord(unpack(COMBAT_TEX_COORDS))
    --  COORDENADAS DE TEXTURA (ajustar según tu textura)
    -- Formato: left, right, top, bottom (valores entre 0 y 1)
   
    
    --  CONFIGURACIÓN VISUAL
    threatFlash:SetBlendMode("ADD")  -- Efecto luminoso
    threatFlash:SetAlpha(0.7)  -- Transparencia
    threatFlash:SetDrawLayer("OVERLAY", 10)  -- Por encima de todo
    
    --  POSICIONAMIENTO PARA PET FRAME
    threatFlash:ClearAllPoints()
    threatFlash:SetPoint("CENTER", PetFrame, "CENTER", -7, -2)  
    threatFlash:SetSize(114, 47)  
end
-- ===============================================================
-- FRAME SETUP
-- ===============================================================
local function SetupFrameElement(parent, name, layer, texture, point, size)
    local element = parent:CreateTexture(name)
    element:SetDrawLayer(layer[1], layer[2])
    element:SetTexture(texture)
    element:SetPoint(unpack(point))
    if size then element:SetSize(unpack(size)) end
    return element
end

local function SetupStatusBar(bar, point, size, texture)
    bar:ClearAllPoints()
    bar:SetPoint(unpack(point))
    bar:SetSize(unpack(size))
    if texture then
        bar:GetStatusBarTexture():SetTexture(texture)
        bar:SetStatusBarColor(1, 1, 1, 1)
        bar.SetStatusBarColor = noop
    end
end

-- ===============================================================
-- MAIN FRAME REPLACEMENT
-- ===============================================================
local function ReplaceBlizzardPetFrame()
    local petFrame = PetFrame
    if not petFrame then return end

    if not moduleState.hooks.onUpdate then
        petFrame:SetScript("OnUpdate", PetFrame_OnUpdate)
        moduleState.hooks.onUpdate = true
        
    end
    
    -- Убедиться, что anchor создан и позиционирован перед применением позиции
    if not PetFrameModule.anchor then
        CreatePetAnchorFrame()
        ApplyWidgetPosition()
    end
    
    ApplyFramePositioning()
    
    -- Принудительно привязать PetFrame к anchor, если он еще не привязан
    if PetFrameModule.anchor then
        local point, relativeTo = petFrame:GetPoint()
        if not point or relativeTo ~= PetFrameModule.anchor then
            petFrame:ClearAllPoints()
            petFrame:SetPoint("CENTER", PetFrameModule.anchor, "CENTER", 0, 0)
        end
    end
    
    -- Hide original Blizzard texture
    PetFrameTexture:SetTexture('')
    PetFrameTexture:Hide()
    
    -- Hide original text elements to avoid conflicts
    if PetFrameHealthBarText then PetFrameHealthBarText:Hide() end
    if PetFrameManaBarText then PetFrameManaBarText:Hide() end
    
    -- Setup portrait
    local portrait = PetPortrait
    if portrait then
        portrait:ClearAllPoints()
        portrait:SetPoint("LEFT", 6, 0)
        portrait:SetSize(34, 34)
        portrait:SetDrawLayer('BACKGROUND')
    end
    
    -- Create NozdorUI elements if needed
    if not moduleState.frame.background then
        moduleState.frame.background = SetupFrameElement(
            petFrame,
            'NozdorUIPetFrameBackground',
            {'BACKGROUND', 1},
            TEXTURE_PATH .. TOT_BASE .. 'BACKGROUND',
            {'LEFT', portrait, 'CENTER', -24, -10}
        )
    end
    
    if not moduleState.frame.border then
        moduleState.frame.border = SetupFrameElement(
            PetFrameHealthBar,
            'NozdorUIPetFrameBorder',
            {'OVERLAY', 6},
            TEXTURE_PATH .. TOT_BASE .. 'BORDER',
            {'LEFT', portrait, 'CENTER', -24, -10}
        )
    end
    
    -- Setup health bar
    SetupStatusBar(
        PetFrameHealthBar,
        {'LEFT', portrait, 'RIGHT', 2, 0},
        {70.5, 10},
        UNITFRAME_PATH .. TOT_BASE .. 'Bar-Health'
    )
    
    -- Setup mana bar
    SetupStatusBar(
        PetFrameManaBar,
        {'LEFT', portrait, 'RIGHT', -1, -10},
        {74, 7.5}
    )
    UpdatePowerBarTexture()
    
    -- Configure combat mode
    ConfigureCombatMode()
    if not moduleState.hooks.combatMode then
        hooksecurefunc(_G.PetAttackModeTexture, "Show", function(self)
            ConfigureCombatMode()
        end)
        
        --  MODIFICAR EL HOOK DE SetVertexColor PARA NO INTERFERIR
        hooksecurefunc(_G.PetAttackModeTexture, "SetVertexColor", function(self, r, g, b, a)
            -- Solo intervenir si no es nuestro rango de colores del pulso
            if not COMBAT_PULSE_SETTINGS.enabled then
                if r ~= 1.0 or g ~= 0.0 or b ~= 0.0 then
                    self:SetVertexColor(1.0, 0.0, 0.0, 1.0)
                end
            end
            -- Si el pulso está activo, dejamos que la animación controle el color
        end)
        
        moduleState.hooks.combatMode = true
    end

    -- Configurar threat glow personalizado
    if not moduleState.hooks.threatGlow then
        ConfigurePetThreatGlow()
        
        --  HOOK para mantener la configuración
        hooksecurefunc(_G.PetFrameFlash, "Show", ConfigurePetThreatGlow)
        
        moduleState.hooks.threatGlow = true
    end
    
    -- Setup pet name positioning
    if PetName then
        PetName:ClearAllPoints()
        PetName:SetPoint("CENTER", petFrame, "CENTER", 10, 13)
        PetName:SetJustifyH("LEFT")
        PetName:SetWidth(65)
        PetName:SetDrawLayer("OVERLAY")
    end
    
    -- Position happiness icon
    local happiness = _G[petFrame:GetName() .. 'Happiness']
    if happiness then
        happiness:ClearAllPoints()
        happiness:SetPoint("LEFT", petFrame, "RIGHT", -10, -5)
    end

    -- ===============================================================
    -- INTEGRATE TEXT SYSTEM
    -- ===============================================================
    if addon.TextSystem then
        
        
        -- Setup the advanced text system for pet frame
        moduleState.textSystem = addon.TextSystem.SetupFrameTextSystem(
            "pet",                 -- frameType
            "pet",                 -- unit
            petFrame,              -- parentFrame
            PetFrameHealthBar,     -- healthBar
            PetFrameManaBar,       -- manaBar
            "PetFrame"             -- prefix
        )
        
        
    else
        
    end
end

-- ===============================================================
-- UPDATE HANDLER
-- ===============================================================
local function OnPetFrameUpdate()
    -- Refresh textures
    if moduleState.frame.background then
        moduleState.frame.background:SetTexture(TEXTURE_PATH .. TOT_BASE .. 'BACKGROUND')
    end
    if moduleState.frame.border then
        moduleState.frame.border:SetTexture(TEXTURE_PATH .. TOT_BASE .. 'BORDER')
    end
    
    UpdatePowerBarTexture()
    ConfigureCombatMode()
    ConfigurePetThreatGlow()
    
    -- Update text system if available
    if moduleState.textSystem and moduleState.textSystem.update then
        moduleState.textSystem.update()
    end
end

-- ===============================================================
-- MODULE INTERFACE
-- ===============================================================
function PetFrameModule:OnEnable()
    if not moduleState.hooks.petUpdate then
        hooksecurefunc('PetFrame_Update', OnPetFrameUpdate)
        moduleState.hooks.petUpdate = true
    end
end

function PetFrameModule:OnDisable()
    if moduleState.textSystem and moduleState.textSystem.clear then
        moduleState.textSystem.clear()
    end
end

function PetFrameModule:PLAYER_ENTERING_WORLD()
    -- Применить позицию anchor перед заменой фрейма
    if PetFrameModule.UpdateWidgets then
        PetFrameModule:UpdateWidgets()
    end
    ReplaceBlizzardPetFrame()
end

-- ===============================================================
-- REFRESH FUNCTION FOR OPTIONS
-- ===============================================================
function addon.RefreshPetFrame()
    if UnitExists("pet") then
        OnPetFrameUpdate()
        
    end
end

-- ===============================================================
-- EVENT HANDLING
-- ===============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "NozdorUI" then
        PetFrameModule:OnEnable()
    elseif event == "PLAYER_ENTERING_WORLD" then
        PetFrameModule:PLAYER_ENTERING_WORLD()
    end
end)

-- ===============================================================
-- CENTRALIZED SYSTEM INTEGRATION
-- ===============================================================

--  FUNCIONES REQUERIDAS POR EL SISTEMA CENTRALIZADO
function PetFrameModule:LoadDefaultSettings()
    --  ASEGURAR QUE EXISTE LA CONFIGURACIÓN EN WIDGETS
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    
    -- Установить позицию по умолчанию (абсолютная позиция рядом с player frame)
    -- Упрощенная логика: просто установить позицию по умолчанию, если её нет
    if not addon.db.profile.widgets.pet then
        needsDefault = true
    elseif addon.db.profile.widgets.pet.anchor == "CENTER" then
        -- Если конфигурация указывает на CENTER, это неправильно, нужно исправить
        needsDefault = true
    end
    
    if needsDefault then
        -- Позиция по умолчанию: рядом с фреймом игрока
        -- Если PlayerFrame существует, используем относительную позицию
        if PlayerFrame then
            -- Вычислить позицию относительно PlayerFrame
            local playerPoint, _, _, playerX, playerY = PlayerFrame:GetPoint()
            if playerPoint then
                -- PlayerFrame обычно в TOPLEFT, фрейм питомца прямо под ним с небольшим смещением вправо
                addon.db.profile.widgets.pet = {
                    anchor = "TOPLEFT",
                    posX = -19,   -- Та же X позиция, что и у player frame
                    posY = -104   -- Прямо под player frame (player в -4, высота фрейма ~100px)
                }
            else
                addon.db.profile.widgets.pet = {
                    anchor = "TOPLEFT",
                    posX = -19,
                    posY = -104
                }
            end
        else
        addon.db.profile.widgets.pet = {
                anchor = "TOPLEFT",
                posX = -19,
                posY = -104
        }
        end
    end
    
    --  ASEGURAR QUE EXISTE LA CONFIGURACIÓN EN UNITFRAME.PET
    if not addon.db.profile.unitframe then
        addon.db.profile.unitframe = {}
    end
    
    if not addon.db.profile.unitframe.pet then
        -- La configuración del pet ya debería existir en database.lua
        
    end
end

function PetFrameModule:UpdateWidgets()
    -- Убедиться, что anchor создан
    if not PetFrameModule.anchor then
        CreatePetAnchorFrame()
    end
    
    ApplyWidgetPosition()
    
    --  REPOSICIONAR EL PET FRAME RELATIVO AL ANCHOR ACTUALIZADO
    if not InCombatLockdown() and PetFrame then
        -- El pet frame debería seguir al anchor
        if PetFrameModule.anchor then
            PetFrame:ClearAllPoints()
            PetFrame:SetPoint("CENTER", PetFrameModule.anchor, "CENTER", 0, 0)
        else
        ApplyFramePositioning()
        end
    end
end

--  FUNCIÓN PARA VERIFICAR SI EL PET FRAME DEBE ESTAR VISIBLE
-- SIGUIENDO A RETAILUI: Siempre visible en editor, NO filtrado por clases
local function ShouldPetFrameBeVisible()
    -- RetailUI siempre permite editar el PET frame independientemente de la clase
    return true
end

--  FUNCIONES DE TESTEO PARA EL EDITOR
local function ShowPetFrameTest()
    -- Убедиться, что anchor создан и показан
    if not PetFrameModule.anchor then
        CreatePetAnchorFrame()
    end
    
    -- Применить позицию anchor (из widgets, как в player.lua)
    if PetFrameModule.anchor then
        ApplyWidgetPosition()
        
        -- Убедиться, что anchor показан
        PetFrameModule.anchor:Show()
    end
    
    -- Применить позицию PetFrame к anchor
    if PetFrameModule.anchor and PetFrame then
        PetFrame:ClearAllPoints()
        PetFrame:SetPoint("CENTER", PetFrameModule.anchor, "CENTER", 0, 0)
    end
    
    -- Mostrar el PET frame aunque no haya mascota
    if PetFrame then
        PetFrame:Show()
        
        -- Simular que hay una mascota para el test
        if PetName then
            PetName:SetText("Тестовый питомец")
            PetName:Show()
        end
        
        if PetPortrait then
            PetPortrait:Show()
        end
        
        if PetFrameHealthBar then
            PetFrameHealthBar:SetMinMaxValues(0, 100)
            PetFrameHealthBar:SetValue(75)
            PetFrameHealthBar:Show()
        end
        
        if PetFrameManaBar then
            PetFrameManaBar:SetMinMaxValues(0, 100)
            PetFrameManaBar:SetValue(50)
            PetFrameManaBar:Show()
        end
    end
end

local function HidePetFrameTest()
    -- Restaurar el estado normal del PET frame
    if PetFrame then
        if UnitExists("pet") then
            -- Si hay mascota real, restaurar valores reales
            if PetName then
                PetName:SetText(UnitName("pet") or "")
            end
            
            -- Forzar actualización de las barras con valores reales
            if PetFrameHealthBar then
                PetFrameHealthBar:SetMinMaxValues(0, UnitHealthMax("pet"))
                PetFrameHealthBar:SetValue(UnitHealth("pet"))
            end
            
            if PetFrameManaBar then
                PetFrameManaBar:SetMinMaxValues(0, UnitPowerMax("pet"))
                PetFrameManaBar:SetValue(UnitPower("pet"))
            end
        else
            -- Si no hay mascota real, ocultar todo
            PetFrame:Hide()
            
            -- Limpiar los valores de prueba
            if PetName then
                PetName:SetText("")
            end
        end
    end
end

--  FUNCIÓN DE INICIALIZACIÓN DEL SISTEMA CENTRALIZADO
local function InitializePetFrameForEditor()
    if PetFrameModule.initialized then
        return
    end
    
    -- Crear el anchor frame
    CreatePetAnchorFrame()
    
    -- Always ensure configuration exists (como party.lua)
    PetFrameModule:LoadDefaultSettings()
    
    -- Применить позицию сразу после создания
    if PetFrameModule.anchor then
        ApplyWidgetPosition()
    end
    
    --  REGISTRO COMPLETO CON TODAS LAS FUNCIONES (COMO party.lua y castbar.lua)
    addon:RegisterEditableFrame({
        name = "PetFrame",
        frame = PetFrameModule.anchor,
        configPath = {"widgets", "pet"},  --  Array como otros módulos
        hasTarget = ShouldPetFrameBeVisible,  --  Siempre true (como RetailUI)
        showTest = ShowPetFrameTest,  --  Minúscula como party.lua
        hideTest = HidePetFrameTest,  --  Minúscula como party.lua
        onShow = function() 
            -- При входе в редактор убедиться, что anchor создан и позиционирован
            if not PetFrameModule.anchor then
                CreatePetAnchorFrame()
                ApplyWidgetPosition()
            end
            
            -- Убедиться, что anchor показан
            if PetFrameModule.anchor then
                PetFrameModule.anchor:Show()
            end
            
            -- При входе в редактор убедиться, что все правильно привязано
            if PetFrameModule.anchor and PetFrame then
                PetFrame:ClearAllPoints()
                PetFrame:SetPoint("CENTER", PetFrameModule.anchor, "CENTER", 0, 0)
            end
        end,
        onHide = function() PetFrameModule:UpdateWidgets() end,  --  Para aplicar cambios
        LoadDefaultSettings = function() PetFrameModule:LoadDefaultSettings() end,
        UpdateWidgets = function() PetFrameModule:UpdateWidgets() end
    })
    
    PetFrameModule.initialized = true
    
end

--  INICIALIZACIÓN
InitializePetFrameForEditor()

--  LISTENER PARA CUANDO EL ADDON ESTÉ COMPLETAMENTE CARGADO
local readyFrame = CreateFrame("Frame")
readyFrame:RegisterEvent("ADDON_LOADED")
readyFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "NozdorUI" then
        -- Aplicar posición del widget cuando el addon esté listo
        if PetFrameModule.UpdateWidgets then
            PetFrameModule:UpdateWidgets()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

