--[[
    Original code by Dmitriy (RetailUI) - Licensed under MIT License
    Adapted for NozdorUI
]]

-- Get addon reference - either from XML parameter or global
local addon = select(2, ...);

--  CREAR MÓDULO USANDO EL SISTEMA DE NOZDORUI
local BuffFrameModule = {}
addon.BuffFrameModule = BuffFrameModule

--  VARIABLES LOCALES
local buffFrame = nil
local toggleButton = nil
local nozdorUIBuffFrame = nil  --  NUESTRO FRAME CUSTOM COMO RETAILUI
local buffsCollapsed = false  -- Состояние свернутости баффов (true = скрыты, false = показаны)

--  FUNCIÓN PARA REEMPLAZAR BUFFFRAME (IGUAL QUE RETAILUI)
local function ReplaceBlizzardFrame(frame)
    frame.toggleButton = frame.toggleButton or CreateFrame('Button', nil, UIParent)
    toggleButton = frame.toggleButton
    -- Initialize toggle state: true = shown (right arrow), false = hidden (left arrow)
    if toggleButton.toggle == nil then
        toggleButton.toggle = true  -- Default: shown
    end
    buffsCollapsed = not toggleButton.toggle  -- Sync with button state
    toggleButton:SetPoint("RIGHT", frame, "RIGHT", 0, -3)
    toggleButton:SetSize(9, 17)
    toggleButton:SetHitRectInsets(0, 0, 0, 0)

    local normalTexture = toggleButton:GetNormalTexture() or toggleButton:CreateTexture(nil, "BORDER")
    normalTexture:SetAllPoints(toggleButton)
    SetAtlasTexture(normalTexture, 'CollapseButton-Right')
    toggleButton:SetNormalTexture(normalTexture)

    local highlightTexture = toggleButton:GetHighlightTexture() or toggleButton:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetAllPoints(toggleButton)
    SetAtlasTexture(highlightTexture, 'CollapseButton-Right')
    toggleButton:SetHighlightTexture(highlightTexture)

    toggleButton:SetScript("OnClick", function(self)
        buffsCollapsed = not buffsCollapsed
        self.toggle = buffsCollapsed
        
        -- Apply toggle state to buffs
        BuffFrameModule:ApplyToggleState()
    end)

    local consolidatedBuffFrame = ConsolidatedBuffs
    consolidatedBuffFrame:SetMovable(true)
    consolidatedBuffFrame:SetUserPlaced(true)
    consolidatedBuffFrame:ClearAllPoints()
    consolidatedBuffFrame:SetPoint("RIGHT", toggleButton, "LEFT", -6, 0)
end

--  FUNCIÓN PARA MOSTRAR/OCULTAR EL BOTÓN SEGÚН BUFFS (IGUAL QUE RETAILUI)
local function ShowToggleButtonIf(condition)
    if not nozdorUIBuffFrame or not nozdorUIBuffFrame.toggleButton then
        return
    end
    if condition then
        nozdorUIBuffFrame.toggleButton:Show()
    else
        nozdorUIBuffFrame.toggleButton:Hide()
    end
end

--  FUNCIÓN PARA CONTAR BUFFS (IGUAL QUE RETAILUI)
local function GetUnitBuffCount(unit, range)
    local count = 0
    for index = 1, range do
        local name = UnitBuff(unit, index)
        if name then
            count = count + 1
        end
    end
    return count
end

--  FUNCIÓN ДЛЯ ПРИМЕНЕНИЯ СОСТОЯНИЯ TOGGLE К БАФФАМ
function BuffFrameModule:ApplyToggleState()
    if not toggleButton then
        return
    end
    
    -- Update button texture based on state
    local normalTexture = toggleButton:GetNormalTexture()
    local highlightTexture = toggleButton:GetHighlightTexture()
    
    if buffsCollapsed then
        SetAtlasTexture(normalTexture, 'CollapseButton-Left')
        SetAtlasTexture(highlightTexture, 'CollapseButton-Left')
        
        -- Hide all buff buttons
        local maxBuffs = BUFF_ACTUAL_DISPLAY or BUFF_MAX_DISPLAY or 32
        for index = 1, maxBuffs do
            local button = _G['BuffButton' .. index]
            if button then
                button:Hide()
            end
        end
    else
        SetAtlasTexture(normalTexture, 'CollapseButton-Right')
        SetAtlasTexture(highlightTexture, 'CollapseButton-Right')
        
        -- Show all buff buttons
        local maxBuffs = BUFF_ACTUAL_DISPLAY or BUFF_MAX_DISPLAY or 32
        for index = 1, maxBuffs do
            local button = _G['BuffButton' .. index]
            if button then
                button:Show()
            end
        end
    end
    
    -- Sync toggle state with button
    toggleButton.toggle = buffsCollapsed
end

--  FUNCIÓN PARA POSICIONAR EL BUFF FRAME (SIMPLIFICADA COMO RETAILUI)
function BuffFrameModule:UpdatePosition()
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets or not addon.db.profile.widgets.buffs then
        return
    end
    
    if not nozdorUIBuffFrame then
        return
    end
    
    local widgetOptions = addon.db.profile.widgets.buffs
    nozdorUIBuffFrame:ClearAllPoints()
    nozdorUIBuffFrame:SetPoint(widgetOptions.anchor, UIParent, widgetOptions.anchor, widgetOptions.posX, widgetOptions.posY)
    
    -- Ensure BuffFrame follows the editor frame position
    if BuffFrame then
        BuffFrame:ClearAllPoints()
        BuffFrame:SetAllPoints(nozdorUIBuffFrame)
        BuffFrame:Show()
    end
    
    -- Ensure editor frame is visible
    nozdorUIBuffFrame:Show()
end

--  FUNCIÓN PARA HABILITAR/DESHABILITAR EL MÓDULO
function BuffFrameModule:Toggle(enabled)
    if not addon.db or not addon.db.profile then return end
    
    if not addon.db.profile.modules then
        addon.db.profile.modules = {}
    end
    if not addon.db.profile.modules.buffs then
        addon.db.profile.modules.buffs = {}
    end
    addon.db.profile.modules.buffs.enabled = enabled
    
    if enabled then
        self:Enable()
    else
        self:Disable()
    end
end

--  FUNCIÓN PARA HABILITAR EL MÓDULO (IGUAL QUE RETAILUI)
function BuffFrameModule:Enable()
    -- Don't create if already exists
    if nozdorUIBuffFrame then return end
    
    -- Ensure BuffFrame exists - try to get it from global
    if not BuffFrame then
        BuffFrame = _G["BuffFrame"]
    end
    if not BuffFrame then 
        -- If BuffFrame doesn't exist yet, wait a bit and try again
        local delayFrame = CreateFrame("Frame")
        delayFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed >= 0.5 then
                if not BuffFrame then
                    BuffFrame = _G["BuffFrame"]
                end
                if BuffFrame and not nozdorUIBuffFrame then
                    BuffFrameModule:Enable()
                end
                self:SetScript("OnUpdate", nil)
                self:Hide()
            end
        end)
        delayFrame:Show()
        return
    end
    
    --  CREAR BUFFFRAME USANDO CreateUIFrame (IGUAL QUE RETAILUI)
    nozdorUIBuffFrame = addon.CreateUIFrame(BuffFrame:GetWidth(), BuffFrame:GetHeight(), "buffs")
    
    -- Make sure it's visible and positioned correctly
    nozdorUIBuffFrame:Show()
    
    -- Ensure BuffFrame is also visible and positioned
    if BuffFrame then
        BuffFrame:Show()
        -- Make BuffFrame follow the editor frame position
        BuffFrame:ClearAllPoints()
        BuffFrame:SetAllPoints(nozdorUIBuffFrame)
    end
    
    --  REGISTRAR EN SISTEMA CENTRALIZADO
    addon:RegisterEditableFrame({
        name = "buffs",
        frame = nozdorUIBuffFrame,
        blizzardFrame = BuffFrame,
        configPath = {"widgets", "buffs"},
        onHide = function()
            self:UpdatePosition()
        end,
        module = self
    })
    
    -- Apply position immediately
    self:UpdatePosition()
    
    -- Also call ReplaceBlizzardFrame immediately
    ReplaceBlizzardFrame(nozdorUIBuffFrame)
    
    -- Initialize toggle state
    if toggleButton then
        buffsCollapsed = toggleButton.toggle or false
    end
    
    -- Hook BuffFrame_UpdateAllBuffFrames to maintain toggle state
    if BuffFrame_UpdateAllBuffFrames then
        hooksecurefunc("BuffFrame_UpdateAllBuffFrames", function()
            BuffFrameModule:ApplyToggleState()
        end)
    end
    
    -- Hook BuffFrame_Update to maintain toggle state
    if BuffFrame_Update then
        hooksecurefunc("BuffFrame_Update", function()
            BuffFrameModule:ApplyToggleState()
        end)
    end
    
    --  CONFIGURAR EVENTOS (IGUAL QUE RETAILUI)
    if not buffFrame then
        buffFrame = CreateFrame("Frame")
        buffFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        buffFrame:RegisterEvent("UNIT_AURA")
        buffFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
        buffFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
        
        buffFrame:SetScript("OnEvent", function(self, event, unit)
            if event == "PLAYER_ENTERING_WORLD" then
                if nozdorUIBuffFrame then
                    ReplaceBlizzardFrame(nozdorUIBuffFrame)
                    ShowToggleButtonIf(GetUnitBuffCount("player", 16) > 0)
                    BuffFrameModule:UpdatePosition()
                    -- Apply toggle state after world load
                    addon.core:ScheduleTimer(function()
                        BuffFrameModule:ApplyToggleState()
                    end, 0.1)
                end
            elseif event == "UNIT_AURA" then
                if unit == 'vehicle' then
                    ShowToggleButtonIf(GetUnitBuffCount("vehicle", 16) > 0)
                elseif unit == 'player' then
                    ShowToggleButtonIf(GetUnitBuffCount("player", 16) > 0)
                end
                -- Apply toggle state after aura update to prevent buffs from showing when collapsed
                addon.core:ScheduleTimer(function()
                    BuffFrameModule:ApplyToggleState()
                end, 0.05)
            elseif event == "UNIT_ENTERED_VEHICLE" then
                if unit == 'player' then
                    ShowToggleButtonIf(GetUnitBuffCount("vehicle", 16) > 0)
                end
            elseif event == "UNIT_EXITED_VEHICLE" then
                if unit == 'player' then
                    ShowToggleButtonIf(GetUnitBuffCount("player", 16) > 0)
                end
            end
        end)
    end
    
    
end

--  FUNCIÓN PARA DESHABILITAR EL MÓDULO (SIMPLIFICADA)
function BuffFrameModule:Disable()
    if buffFrame then
        buffFrame:UnregisterAllEvents()
        buffFrame:SetScript("OnEvent", nil)
        buffFrame = nil
    end
    
    if toggleButton then
        toggleButton:Hide()
        toggleButton = nil
    end
    
    if nozdorUIBuffFrame then
        nozdorUIBuffFrame:Hide()
        nozdorUIBuffFrame = nil
    end
    
    
end

--  INICIALIZACIÓN AUTOMÁTICA
local function Initialize()
    if BuffFrameModule.initialized then
        return
    end
    
    BuffFrameModule.initialized = true
    
    -- Inicializar el módulo si está habilitado
    -- Use RefreshBuffFrame to ensure proper initialization
    if addon.RefreshBuffFrame then
        addon.RefreshBuffFrame()
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "NozdorUI" then
        Initialize()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- For client integration: initialize on any of these events
        if not BuffFrameModule.initialized then
            Initialize()
        end
        if event == "PLAYER_LOGIN" then
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    end
end)

-- Additional early initialization for client integration
if not BuffFrameModule.initialized then
    if addon.db and addon.db.profile then
        Initialize()
    end
end

--  FUNCIÓN PARA SER LLAMADA DESDE OPTIONS.LUA
function addon:RefreshBuffFrame()
    if not BuffFrameModule then return end
    
    local isEnabled = addon.db and addon.db.profile and addon.db.profile.modules and 
                     addon.db.profile.modules.buffs and addon.db.profile.modules.buffs.enabled
    
    if isEnabled then
        -- Enable module if not already enabled
        if not nozdorUIBuffFrame then
            BuffFrameModule:Enable()
        else
            -- Just update position if already enabled
        BuffFrameModule:UpdatePosition()
        end
    else
        -- Disable module if disabled
        BuffFrameModule:Disable()
    end
end