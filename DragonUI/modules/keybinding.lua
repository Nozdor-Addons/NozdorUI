--[[
    KeyBinding Module
    Implements LibKeyBound-1.0 for intuitive keybinding system
    Allows hover + key press to bind keys to buttons
]]

-- Get addon reference - either from XML parameter or global
local addon = select(2, ...);
local LibKeyBound
local format = string.format

-- Safe loading of LibKeyBound
local success, result = pcall(function()
    return LibStub("LibKeyBound-1.0")
end)

if success then
    LibKeyBound = result
else
    return
end

-- ============================================================================
-- KEYBINDING MODULE
-- ============================================================================

local KeyBindingModule = {
    enabled = false,
    registeredButtons = {},
    originalMethods = {}
}

addon.KeyBindingModule = KeyBindingModule

-- ============================================================================
-- BUTTON ENHANCEMENT SYSTEM
-- ============================================================================

-- Make any button compatible with LibKeyBound (Bartender4 style)
function KeyBindingModule:MakeButtonBindable(button, bindingAction, actionName)
    if not LibKeyBound or not button or self.registeredButtons[button] then
        return
    end
    

    -- Store original methods
    self.originalMethods[button] = {
        GetHotkey = button.GetHotkey,
        SetKey = button.SetKey,
        ClearBindings = button.ClearBindings,
        GetActionName = button.GetActionName,
        GetBindings = button.GetBindings
    }

    -- Store binding info
    button._bindingAction = bindingAction
    button._actionName = actionName

    -- GetHotkey - returns the primary hotkey for display on button
    button.GetHotkey = function(self)
        local key
        -- For action buttons, check both ACTIONBUTTON and CLICK formats
        if self._bindingAction:match("^ACTIONBUTTON") or self._bindingAction:match("^BONUSACTIONBUTTON") or self._bindingAction:match("^MULTIACTIONBAR") then
            -- Try ACTIONBUTTON format first
            key = GetBindingKey(self._bindingAction)
            if not key then
                -- Fallback to CLICK format
                local clickBinding = format('CLICK %s:LeftButton', self:GetName())
                key = GetBindingKey(clickBinding)
            end
        else
            key = GetBindingKey(self._bindingAction)
        end
        if key then
            return LibKeyBound:ToShortKey(key)
        end
        return ""
    end

    -- SetKey - assigns a key to this button
    button.SetKey = function(self, key)
        if InCombatLockdown() then return end
        -- Use SetBindingClick for action buttons, SetBinding for others
        if self._bindingAction:match("^ACTIONBUTTON") or self._bindingAction:match("^BONUSACTIONBUTTON") or self._bindingAction:match("^MULTIACTIONBAR") then
            SetBindingClick(key, self:GetName(), 'LeftButton')
        else
        SetBinding(key, self._bindingAction)
        end
    end

    -- ClearBindings - removes all keys from this button
    button.ClearBindings = function(self)
        if InCombatLockdown() then return end
        -- For action buttons, check both ACTIONBUTTON and CLICK formats
        if self._bindingAction:match("^ACTIONBUTTON") or self._bindingAction:match("^BONUSACTIONBUTTON") or self._bindingAction:match("^MULTIACTIONBAR") then
            -- Clear ACTIONBUTTON format bindings (standard interface)
            local actionKeys = {GetBindingKey(self._bindingAction)}
            for i = 1, #actionKeys do
                if actionKeys[i] then
                    SetBinding(actionKeys[i], nil)
                end
            end
            -- Clear CLICK format bindings (addon bindings)
            local clickBinding = format('CLICK %s:LeftButton', self:GetName())
            local clickKeys = {GetBindingKey(clickBinding)}
            for i = 1, #clickKeys do
                if clickKeys[i] then
                    SetBinding(clickKeys[i], nil)
                end
            end
        else
            local keys = {GetBindingKey(self._bindingAction)}
            for i = 1, #keys do
                if keys[i] then
                    SetBinding(keys[i], nil)
                end
            end
        end
    end

    -- GetActionName - for tooltip display
    button.GetActionName = function(self)
        return self._actionName or self:GetName()
    end

    -- GetBindings - returns formatted string of all bindings
    button.GetBindings = function(self)
        local keys = {}
        -- For action buttons, check both ACTIONBUTTON and CLICK formats
        if self._bindingAction:match("^ACTIONBUTTON") or self._bindingAction:match("^BONUSACTIONBUTTON") or self._bindingAction:match("^MULTIACTIONBAR") then
            -- Try ACTIONBUTTON format first
            local actionKeys = {GetBindingKey(self._bindingAction)}
            for i = 1, #actionKeys do
                if actionKeys[i] then
                    table.insert(keys, actionKeys[i])
                end
            end
            -- Also check CLICK format
            local clickBinding = format('CLICK %s:LeftButton', self:GetName())
            local clickKeys = {GetBindingKey(clickBinding)}
            for i = 1, #clickKeys do
                if clickKeys[i] then
                    table.insert(keys, clickKeys[i])
                end
            end
        else
            local actionKeys = {GetBindingKey(self._bindingAction)}
            for i = 1, #actionKeys do
                if actionKeys[i] then
                    table.insert(keys, actionKeys[i])
                end
            end
        end
        
        if #keys > 0 then
            local bindings = {}
            for i = 1, #keys do
                if keys[i] then
                    table.insert(bindings, GetBindingText(keys[i], 'KEY_'))
                end
            end
            return table.concat(bindings, ', ')
        end
        return nil
    end

    -- FreeKey - required by LibKeyBound for proper conflict resolution
    button.FreeKey = function(self, key)
        if InCombatLockdown() then return end
        local action = GetBindingAction(key)
        if action and action ~= "" then
            -- For action buttons, check if it's our own binding
            if self._bindingAction:match("^ACTIONBUTTON") or self._bindingAction:match("^BONUSACTIONBUTTON") or self._bindingAction:match("^MULTIACTIONBAR") then
                local clickBinding = format('CLICK %s:LeftButton', self:GetName())
                if action == self._bindingAction or action == clickBinding then
                    return nil -- Don't free our own binding
                end
            elseif action == self._bindingAction then
                return nil -- Don't free our own binding
            end
            SetBinding(key, nil)
            return action
        end
        return nil
    end

    -- Simple hover handling (let LibKeyBound manage its own state)
    button:HookScript("OnEnter", function(self)
        if KeyBindingModule.enabled and LibKeyBound:IsShown() then
            LibKeyBound:Set(self)
        end
    end)

    -- Don't hook OnLeave - LibKeyBound handles this internally

    -- Register the button
    self.registeredButtons[button] = true
end

-- Remove LibKeyBound compatibility from a button
function KeyBindingModule:RemoveButtonBinding(button)
    if not button or not self.registeredButtons[button] then
        return
    end

    -- Restore original methods
    local original = self.originalMethods[button]
    if original then
        button.GetHotkey = original.GetHotkey
        button.SetKey = original.SetKey
        button.ClearBindings = original.ClearBindings
        button.GetActionName = original.GetActionName
        button.GetBindings = original.GetBindings
    end
    
    -- Note: HookScript doesn't need to be restored - it adds handlers, doesn't replace them

    -- Clean up binding info
    button._bindingAction = nil
    button._actionName = nil

    -- Unregister
    self.registeredButtons[button] = nil
    self.originalMethods[button] = nil
end

-- ============================================================================
-- MODULE CONTROL
-- ============================================================================
function KeyBindingModule:Enable()
    if self.enabled or not LibKeyBound then
        return
    end
    
    -- Initialize LibKeyBound if not already done
    if not LibKeyBound.initialized then
        LibKeyBound:Initialize()
    end
    
    -- Ensure the binder frame exists
    if not LibKeyBound.frame then
        LibKeyBound.frame = LibKeyBound.Binder:Create()
    end
    
    self.enabled = true
    
    -- Register LibKeyBound events using proper callback system
    LibKeyBound.RegisterCallback(self, "LIBKEYBOUND_ENABLED")
    LibKeyBound.RegisterCallback(self, "LIBKEYBOUND_DISABLED")
    

    
    -- Add slash commands
    SLASH_NozdorUI_KEYBIND1 = "/dukeybind"
    SLASH_NozdorUI_KEYBIND2 = "/dukb"
    SlashCmdList["NozdorUI_KEYBIND"] = function(msg)
        local command = msg:lower():trim()
        if command ~= "help" then
            LibKeyBound:Toggle()
        end
    end
    

end

function KeyBindingModule:Disable()
    if not self.enabled then
        return
    end
    
    -- Deactivate LibKeyBound if active
    if LibKeyBound:IsShown() then
        LibKeyBound:Deactivate()
    end
    
    -- Remove all button bindings
    for button in pairs(self.registeredButtons) do
        self:RemoveButtonBinding(button)
    end
    
    -- Unregister slash commands
    SlashCmdList["NozdorUI_KEYBIND"] = nil
    
    self.enabled = false
end

-- ============================================================================
-- LIBKEYBOUND CALLBACKS
-- ============================================================================

function KeyBindingModule:LIBKEYBOUND_ENABLED()
end

function KeyBindingModule:LIBKEYBOUND_DISABLED()
end



-- ============================================================================
-- AUTO-REGISTRATION SYSTEM
-- ============================================================================

-- Auto-register action buttons when they're created
function KeyBindingModule:AutoRegisterActionButtons()
    if not self.enabled then
        return
    end

    -- Register main action buttons
    for i = 1, 12 do
        local button = _G["ActionButton" .. i]
        if button and not self.registeredButtons[button] then
            self:MakeButtonBindable(button, "ACTIONBUTTON" .. i, "Кнопка действия " .. i)
        end
    end

    -- Register bonus action buttons
    for i = 1, 12 do
        local button = _G["BonusActionButton" .. i]
        if button and not self.registeredButtons[button] then
            self:MakeButtonBindable(button, "BONUSACTIONBUTTON" .. i, "Дополнительная кнопка " .. i)
        end
    end

    -- Register multibar buttons with proper keybind mappings
    local multibarMappings = {
        {frame = "MultiBarBottomLeftButton", binding = "MULTIACTIONBAR1BUTTON", name = "Нижняя левая кнопка"},
        {frame = "MultiBarBottomRightButton", binding = "MULTIACTIONBAR2BUTTON", name = "Нижняя правая кнопка"},
        {frame = "MultiBarRightButton", binding = "MULTIACTIONBAR3BUTTON", name = "Правая кнопка"},
        {frame = "MultiBarLeftButton", binding = "MULTIACTIONBAR4BUTTON", name = "Левая кнопка"}
    }
    
    for _, mapping in pairs(multibarMappings) do
        for i = 1, 12 do
            local button = _G[mapping.frame .. i]
            if button and not self.registeredButtons[button] then
                self:MakeButtonBindable(button, mapping.binding .. i, mapping.name .. " " .. i)
            end
        end
    end
    
    -- Register stance/shapeshift buttons
    for i = 1, 10 do
        local button = _G["ShapeshiftButton" .. i]
        if button and not self.registeredButtons[button] then
            self:MakeButtonBindable(button, "SHAPESHIFT" .. i, "Стойка " .. i)
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Auto-enable when addon loads
local function Initialize()
    if KeyBindingModule.initialized then
        return
    end
    
    KeyBindingModule.initialized = true
    
    -- Check if keybinding module should be enabled (default to enabled if not set)
    local isEnabled = true
    if addon.db and addon.db.profile and addon.db.profile.modules and 
       addon.db.profile.modules.keybinding then
        isEnabled = addon.db.profile.modules.keybinding.enabled ~= false
    end
    
    if isEnabled then
        KeyBindingModule:Enable()
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
        if not KeyBindingModule.initialized then
            Initialize()
        end
        -- Auto-register action buttons after world load
        if KeyBindingModule.enabled then
            KeyBindingModule:AutoRegisterActionButtons()
        end
        if event == "PLAYER_LOGIN" then
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    end
end)

-- Additional early initialization for client integration
if not KeyBindingModule.initialized then
    if addon.db and addon.db.profile then
        Initialize()
    end
end

-- Function to refresh keybinding module (called from RefreshConfig)
function addon:RefreshKeyBinding()
    if not KeyBindingModule.initialized then
        Initialize()
    else
        -- Re-check if module should be enabled
        local isEnabled = true
        if addon.db and addon.db.profile and addon.db.profile.modules and 
           addon.db.profile.modules.keybinding then
            isEnabled = addon.db.profile.modules.keybinding.enabled ~= false
        end
        
        if isEnabled and not KeyBindingModule.enabled then
            KeyBindingModule:Enable()
        elseif not isEnabled and KeyBindingModule.enabled then
            KeyBindingModule:Disable()
        end
    end
end

-- Global access
addon.KeyBindingModule = KeyBindingModule
