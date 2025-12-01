local addon = select(2, ...);

-- Define the reload dialog
StaticPopupDialogs["DRAGONUI_RELOAD_UI"] = {
    text = "Изменение этого параметра требует\nперезагрузки интерфейса\nдля корректного применения.",
    button1 = "Перезагрузить интерфейс",
    button2 = "Не сейчас",
    OnAccept = function()
        ReloadUI()
    end,
    OnShow = function(self)
        if self.text then
            self.text:SetWidth(500)
            self.text:SetJustifyH("CENTER")
        end
        if self:GetWidth() < 550 then
            self:SetWidth(550)
        end
        local frame = CreateFrame("Frame")
        frame:SetScript("OnUpdate", function(frame)
            frame:SetScript("OnUpdate", nil)
            if self.button1 and self.button2 and self:IsShown() then
                local button1Width = self.button1:GetWidth() or 140
                local button2Width = self.button2:GetWidth() or 120
                local spacing = 13
                local totalWidth = button1Width + spacing + button2Width
                
                self.button1:ClearAllPoints()
                self.button1:SetPoint("BOTTOM", self, "BOTTOM", -(totalWidth / 2 - button1Width / 2), 16)
                self.button2:ClearAllPoints()
                self.button2:SetPoint("LEFT", self.button1, "RIGHT", spacing, 0)
            end
            frame:Hide()
        end)
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
    text_width = 700,
    width = 750
};

-- Function to create configuration options (called after DB is ready)
function addon:CreateOptionsTable()
    return {
        name = "DragonUI",
        type = 'group',
        args = {
            --  BOTÓN PARA ACTIVAR EL MODO DE EDICIÓN
            toggle_editor_mode = {
                type = 'execute',
                name = function()
                    -- El nombre del botón cambia dinámicamente y maneja la lógica de estado
                    if addon.EditorMode then
                        local success, isActive = pcall(function()
                            return addon.EditorMode:IsActive()
                        end)
                        if success and isActive then
                            return "|cffFF6347Выйти из режима редактора|r"
                        end
                    end
                    return "|cff00FF00Переместить элементы интерфейса|r"
                end,
                desc = "Разблокировать элементы интерфейса для перемещения мышью. Появится кнопка для выхода из этого режима.",
                func = function()
                    --  CORRECCIÓN 3: Ocultar el tooltip para que no se quede pegado.
                    GameTooltip:Hide()

                    -- Usar la función de la librería para cerrar su propia ventana.
                    LibStub("AceConfigDialog-3.0"):Close("DragonUI")

                    -- Llama a la función Toggle del editor_mode.lua
                    if addon.EditorMode then
                        addon.EditorMode:Toggle()
                    end
                end,
                -- FORCE button to be enabled initially to avoid AceConfig timing issues
                disabled = false,
                order = 0 -- El orden más bajo para que aparezca primero
            },
            
            -- ✅ KEYBINDING MODE BUTTON
            toggle_keybind_mode = {
                type = 'execute',
                name = function()
                    if LibStub and LibStub("LibKeyBound-1.0", true) and LibStub("LibKeyBound-1.0"):IsShown() then
                        return "|cffFF6347Режим привязки клавиш активен|r"
                    else
                        return "|cff00FF00Режим привязки клавиш|r"
                    end
                end,
                desc = "Переключить режим привязки клавиш. Наведите курсор на кнопки и нажмите клавишу для мгновенной привязки. Нажмите ESC для очистки привязок.",
                func = function()
                    GameTooltip:Hide()
                    -- Close DragonUI options window
                    LibStub("AceConfigDialog-3.0"):Close("DragonUI")
                    
                    if addon.KeyBindingModule and LibStub and LibStub("LibKeyBound-1.0", true) then
                        local LibKeyBound = LibStub("LibKeyBound-1.0")
                        LibKeyBound:Toggle()
                    else
                    end
                end,
                disabled = function()
                    return not (addon.KeyBindingModule and addon.KeyBindingModule.enabled)
                end,
                order = 0.3
            },
            
            --  SEPARADOR VISUAL
            editor_separator = {
                type = 'header',
                name = ' ', -- Un espacio en blanco actúa como separador
                order = 0.5
            },

            -- NUEVA SECCIÓN: MODULES
            modules = {
                type = 'group',
                name = "Модули",
                desc = "Включить или отключить конкретные модули DragonUI",
                order = 0.6,
                args = {
                    description = {
                        type = 'description',
                        name = "|cffFFD700Управление модулями|r\n\nВключите или отключите конкретные модули DragonUI. Когда отключено, будет отображаться оригинальный интерфейс Blizzard.",
                        order = 1
                    },

                    castbars_header = {
                        type = 'header',
                        name = "Полосы заклинаний",
                        order = 10
                    },

                    player_castbar_enabled = {
                        type = 'toggle',
                        name = "Полоса заклинаний игрока",
                        desc = "Включить полосу заклинаний игрока DragonUI. Когда отключено, показывается стандартная полоса Blizzard.",
                        get = function()
                            return addon.db.profile.castbar.enabled
                        end,
                        set = function(info, val)
                            addon.db.profile.castbar.enabled = val
                            if addon.RefreshCastbar then
                                addon.RefreshCastbar()
                            end
                        end,
                        order = 11
                    },

                    target_castbar_enabled = {
                        type = 'toggle',
                        name = "Полоса заклинаний цели",
                        desc = "Включить полосу заклинаний цели DragonUI. Когда отключено, показывается стандартная полоса Blizzard.",
                        get = function()
                            if not addon.db.profile.castbar.target then
                                return true
                            end
                            local value = addon.db.profile.castbar.target.enabled
                            if value == nil then
                                return true
                            end
                            return value == true
                        end,
                        set = function(info, val)
                            if not addon.db.profile.castbar.target then
                                addon.db.profile.castbar.target = {}
                            end
                            addon.db.profile.castbar.target.enabled = val
                            if addon.RefreshTargetCastbar then
                                addon.RefreshTargetCastbar()
                            end
                        end,
                        order = 12
                    },

                    focus_castbar_enabled = {
                        type = 'toggle',
                        name = "Полоса заклинаний фокуса",
                        desc = "Включить полосу заклинаний фокуса DragonUI. Когда отключено, показывается стандартная полоса Blizzard.",
                        get = function()
                            return addon.db.profile.castbar.focus.enabled
                        end,
                        set = function(info, value)
                            addon.db.profile.castbar.focus.enabled = value
                            if addon.RefreshFocusCastbar then
                                addon.RefreshFocusCastbar()
                            end
                        end,
                        order = 13
                    },

                    -- Main modules section
                    other_modules_header = {
                        type = 'header',
                        name = "Другие модули",
                        order = 20
                    },

                    -- UNIFIED ACTION BARS SYSTEM
                    actionbars_system_enabled = {
                        type = 'toggle',
                        name = "Система панелей действий",
                        desc = "Включить полную систему панелей действий DragonUI. Контролирует: основные панели действий, интерфейс транспорта, панели стойки/облика, панели питомца, панели множественного применения (тотемы/обладание), стиль кнопок и скрытие элементов Blizzard. Когда отключено, все функции панелей действий используют стандартный интерфейс Blizzard.",
                        get = function()
                            -- Check if the unified system is enabled by checking if all components are enabled
                            local modules = addon.db.profile.modules
                            if not modules then
                                return false
                            end

                            return (modules.mainbars and modules.mainbars.enabled) and
                                       (modules.vehicle and modules.vehicle.enabled) and
                                       (modules.stance and modules.stance.enabled) and
                                       (modules.petbar and modules.petbar.enabled) and
                                       (modules.multicast and modules.multicast.enabled) and
                                       (modules.buttons and modules.buttons.enabled) and
                                       (modules.noop and modules.noop.enabled)
                        end,
                        set = function(info, val)
                            if not addon.db.profile.modules then
                                addon.db.profile.modules = {}
                            end
                            -- Initialize all module tables if they don't exist and set their enabled state
                            local moduleNames = {"mainbars", "vehicle", "stance", "petbar", "multicast", "buttons",
                                                 "noop"}
                            for _, moduleName in ipairs(moduleNames) do
                                if not addon.db.profile.modules[moduleName] then
                                    addon.db.profile.modules[moduleName] = {}
                                end
                                addon.db.profile.modules[moduleName].enabled = val
                            end
                            StaticPopup_Show("DRAGONUI_RELOAD_UI")
                        end,
                        order = 21
                    },

                    -- MICRO MENU & BAGS
                    micromenu_enabled = {
                        type = 'toggle',
                        name = "Микроменю и сумки",
                        desc = "Применить стиль и позиционирование микроменю и системы сумок DragonUI. Включает кнопку персонажа, книгу заклинаний, таланты и т.д., а также управление сумками. Когда отключено, эти элементы используют стандартное позиционирование и стиль Blizzard.",
                        get = function()
                            return addon.db.profile.modules and addon.db.profile.modules.micromenu and
                                       addon.db.profile.modules.micromenu.enabled
                        end,
                        set = function(info, val)
                            if not addon.db.profile.modules then
                                addon.db.profile.modules = {}
                            end
                            if not addon.db.profile.modules.micromenu then
                                addon.db.profile.modules.micromenu = {}
                            end
                            addon.db.profile.modules.micromenu.enabled = val
                            StaticPopup_Show("DRAGONUI_RELOAD_UI")
                        end,
                        order = 22
                    },

                    -- COOLDOWN TIMERS
                    cooldowns_enabled = {
                        type = 'toggle',
                        name = "Таймеры перезарядки",
                        desc = "Показывать таймеры перезарядки на кнопках действий. Когда отключено, таймеры перезарядки будут скрыты, а система полностью деактивирована.",
                        get = function()
                            return addon.db.profile.modules and addon.db.profile.modules.cooldowns and
                                       addon.db.profile.modules.cooldowns.enabled
                        end,
                        set = function(info, val)
                            if not addon.db.profile.modules then
                                addon.db.profile.modules = {}
                            end
                            if not addon.db.profile.modules.cooldowns then
                                addon.db.profile.modules.cooldowns = {}
                            end
                            addon.db.profile.modules.cooldowns.enabled = val
                            -- Show reload dialog as cooldown system requires UI reload to properly enable/disable hooks
                            StaticPopup_Show("DRAGONUI_RELOAD_UI")
                        end,
                        order = 23
                    },

                    -- MINIMAP SYSTEM
                    minimap_enabled = {
                        type = 'toggle',
                        name = "Система миникарты",
                        desc = "Включить улучшения миникарты DragonUI, включая пользовательский стиль, позиционирование, иконки отслеживания и календарь. Когда отключено, используется стандартный внешний вид и позиционирование миникарты Blizzard.",
                        get = function()
                            return addon.db.profile.modules and addon.db.profile.modules.minimap and
                                       addon.db.profile.modules.minimap.enabled
                        end,
                        set = function(info, val)
                            if not addon.db.profile.modules then
                                addon.db.profile.modules = {}
                            end
                            if not addon.db.profile.modules.minimap then
                                addon.db.profile.modules.minimap = {}
                            end
                            addon.db.profile.modules.minimap.enabled = val
                            StaticPopup_Show("DRAGONUI_RELOAD_UI")
                        end,
                        order = 24
                    },

                    -- BUFF FRAME SYSTEM
                    buffs_enabled = {
                        type = 'toggle',
                        name = "Система рамок эффектов",
                        desc = "Включить рамку эффектов DragonUI с пользовательским стилем, позиционированием и функциональностью кнопки переключения. Когда отключено, используется стандартный внешний вид и позиционирование рамки эффектов Blizzard.",
                        get = function()
                            return addon.db.profile.modules and addon.db.profile.modules.buffs and
                                       addon.db.profile.modules.buffs.enabled
                        end,
                        set = function(info, val)
                            if not addon.db.profile.modules then
                                addon.db.profile.modules = {}
                            end
                            if not addon.db.profile.modules.buffs then
                                addon.db.profile.modules.buffs = {}
                            end
                            addon.db.profile.modules.buffs.enabled = val
                            if addon.BuffFrameModule then
                                addon.BuffFrameModule:Toggle(val)
                            end
                            StaticPopup_Show("DRAGONUI_RELOAD_UI")
                        end,
                        order = 25
                    },


                }
            },
            actionbars = {
                type = 'group',
                name = "Панели действий",
                order = 1,
                args = {
                    scales = {
                        type = 'group',
                        name = "Масштаб панелей действий",
                        inline = true,
                        order = 1,
                        args = {
                            scale_actionbar = {
                                type = 'range',
                                name = "Масштаб основной панели",
                                desc = "Масштаб основной панели действий",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.mainbars.scale_actionbar
                                end,
                                set = function(info, value)
                                    addon.db.profile.mainbars.scale_actionbar = value
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                end,
                                order = 1
                            },
                            scale_rightbar = {
                                type = 'range',
                                name = "Масштаб правой панели",
                                desc = "Масштаб правой панели действий (Правая дополнительная панель)",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.mainbars.scale_rightbar
                                end,
                                set = function(info, value)
                                    addon.db.profile.mainbars.scale_rightbar = value
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                end,
                                order = 2
                            },
                            scale_leftbar = {
                                type = 'range',
                                name = "Масштаб левой панели",
                                desc = "Масштаб левой панели действий (Левая дополнительная панель)",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.mainbars.scale_leftbar
                                end,
                                set = function(info, value)
                                    addon.db.profile.mainbars.scale_leftbar = value
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                end,
                                order = 3
                            },
                            scale_bottomleft = {
                                type = 'range',
                                name = "Масштаб нижней левой панели",
                                desc = "Масштаб нижней левой панели действий (Нижняя левая дополнительная панель)",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.mainbars.scale_bottomleft
                                end,
                                set = function(info, value)
                                    addon.db.profile.mainbars.scale_bottomleft = value
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                end,
                                order = 4
                            },
                            scale_bottomright = {
                                type = 'range',
                                name = "Масштаб нижней правой панели",
                                desc = "Масштаб нижней правой панели действий (Нижняя правая дополнительная панель)",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.mainbars.scale_bottomright
                                end,
                                set = function(info, value)
                                    addon.db.profile.mainbars.scale_bottomright = value
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                end,
                                order = 5
                            },
                            reset_scales = {
                                type = 'execute',
                                name = "Сбросить все масштабы",
                                desc = "Сбросить все масштабы панелей действий к значениям по умолчанию (0.9)",
                                func = function()
                                    -- Reset all scales to default value (0.9)
                                    addon.db.profile.mainbars.scale_actionbar = 0.9
                                    addon.db.profile.mainbars.scale_rightbar = 0.9
                                    addon.db.profile.mainbars.scale_leftbar = 0.9
                                    addon.db.profile.mainbars.scale_bottomleft = 0.9
                                    addon.db.profile.mainbars.scale_bottomright = 0.9
                                    
                                    -- Apply the changes
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                    
                                    
                                    -- Show reload UI dialog
                                    StaticPopup_Show("DRAGONUI_RELOAD_UI")
                                end,
                                order = 6
                            }
                        }
                    },
                    positions = {
                        type = 'group',
                        name = "Позиции панелей действий",
                        inline = true,
                        order = 2,
                        args = {
                            editor_mode_desc = {
                                type = 'description',
                                name = "|cffFFD700Совет:|r Используйте кнопку |cff00FF00Переместить элементы интерфейса|r выше для изменения позиции панелей действий мышью.",
                                order = 1
                            },
                            left_horizontal = {
                                type = 'toggle',
                                name = "Левая панель горизонтально",
                                desc = "Сделать левую дополнительную панель горизонтальной вместо вертикальной",
                                get = function()
                                    return addon.db.profile.mainbars.left.horizontal
                                end,
                                set = function(_, value)
                                    addon.db.profile.mainbars.left.horizontal = value
                                    if addon.PositionActionBars then
                                        addon.PositionActionBars()
                                    end
                                end,
                                order = 2
                            },
                            right_horizontal = {
                                type = 'toggle',
                                name = "Правая панель горизонтально",
                                desc = "Сделать правую дополнительную панель горизонтальной вместо вертикальной",
                                get = function()
                                    return addon.db.profile.mainbars.right.horizontal
                                end,
                                set = function(_, value)
                                    addon.db.profile.mainbars.right.horizontal = value
                                    if addon.PositionActionBars then
                                        addon.PositionActionBars()
                                    end
                                end,
                                order = 3
                            }
                        }
                    },
                    buttons = {
                        type = 'group',
                        name = "Внешний вид кнопок",
                        inline = true,
                        order = 2,
                        args = {
                            only_actionbackground = {
                                type = 'toggle',
                                name = "Фон только на основной панели",
                                desc = "Если включено, только кнопки основной панели действий будут иметь фон. Если выключено, все кнопки панелей действий будут иметь фон.",
                                get = function()
                                    return addon.db.profile.buttons.only_actionbackground
                                end,
                                set = function(info, value)
                                    addon.db.profile.buttons.only_actionbackground = value
                                    if addon.RefreshButtons then
                                        addon.RefreshButtons()
                                    end
                                end,
                                order = 1
                            },
                            hide_main_bar_background = {
                                type = 'toggle',
                                name = "Скрыть фон основной панели",
                                desc = "Скрыть текстуру фона основной панели действий (делает её полностью прозрачной)|cFFFF0000Требует перезагрузки интерфейса|r",
                                get = function()
                                    return addon.db.profile.buttons.hide_main_bar_background
                                end,
                                set = function(info, value)
                                    addon.db.profile.buttons.hide_main_bar_background = value
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                    -- Prompt for UI reload
                                    StaticPopup_Show("DRAGONUI_RELOAD_UI")
                                end,
                                order = 1.5
                            },
                            count = {
                                type = 'group',
                                name = "Текст количества",
                                inline = true,
                                order = 2,
                                args = {
                                    show = {
                                        type = 'toggle',
                                        name = "Показать количество",
                                        get = function()
                                            return addon.db.profile.buttons.count.show
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.count.show = value
                                            if addon.RefreshButtons then
                                                addon.RefreshButtons()
                                            end
                                        end,
                                        order = 1
                                    }
                                }
                            },
                            hotkey = {
                                type = 'group',
                                name = "Текст горячих клавиш",
                                inline = true,
                                order = 4,
                                args = {
                                    show = {
                                        type = 'toggle',
                                        name = "Показать горячие клавиши",
                                        get = function()
                                            return addon.db.profile.buttons.hotkey.show
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.hotkey.show = value
                                            if addon.RefreshButtons then
                                                addon.RefreshButtons()
                                            end
                                        end,
                                        order = 1
                                    },
                                    range = {
                                        type = 'toggle',
                                        name = "Индикатор дальности",
                                        desc = "Показывать небольшую точку индикатора дальности на кнопках",
                                        get = function()
                                            return addon.db.profile.buttons.hotkey.range
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.hotkey.range = value
                                            if addon.RefreshButtons then
                                                addon.RefreshButtons()
                                            end
                                        end,
                                        order = 2
                                    }
                                }
                            },
                            macros = {
                                type = 'group',
                                name = "Текст макросов",
                                inline = true,
                                order = 5,
                                args = {
                                    show = {
                                        type = 'toggle',
                                        name = "Показать названия макросов",
                                        get = function()
                                            return addon.db.profile.buttons.macros.show
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.macros.show = value
                                            if addon.RefreshButtons then
                                                addon.RefreshButtons()
                                            end
                                        end,
                                        order = 1
                                    }
                                }
                            },
                            pages = {
                                type = 'group',
                                name = "Номера страниц",
                                inline = true,
                                order = 6,
                                args = {
                                    show = {
                                        type = 'toggle',
                                        name = "Показать страницы",
                                        get = function()
                                            return addon.db.profile.buttons.pages.show
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.pages.show = value
                                            StaticPopup_Show("DRAGONUI_RELOAD_UI")
                                        end,
                                        order = 1
                                    }
                                }
                            },
                            cooldown = {

                                type = 'group',
                                name = "Текст перезарядки",
                                inline = true,
                                order = 7,
                                args = {
                                    min_duration = {
                                        type = 'range',
                                        name = "Минимальная длительность",
                                        desc = "Минимальная длительность для отображения текста",
                                        min = 1,
                                        max = 10,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.buttons.cooldown.min_duration
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.cooldown.min_duration = value
                                            if addon.RefreshCooldowns then
                                                addon.RefreshCooldowns()
                                            end
                                        end,
                                        order = 2
                                    },
                                    color = {
                                        type = 'color',
                                        name = "Цвет текста",
                                        desc = "Цвет текста перезарядки",
                                        get = function()
                                            local c = addon.db.profile.buttons.cooldown.color;
                                            return c[1], c[2], c[3], c[4];
                                        end,
                                        set = function(info, r, g, b, a)
                                            addon.db.profile.buttons.cooldown.color = {r, g, b, a}
                                            if addon.RefreshCooldowns then
                                                addon.RefreshCooldowns()
                                            end
                                        end,
                                        hasAlpha = true,
                                        order = 3
                                    },
                                    font_size = {
                                        type = 'range',
                                        name = "Размер шрифта",
                                        desc = "Размер текста перезарядки",
                                        min = 8,
                                        max = 24,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.buttons.cooldown.font_size
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.cooldown.font_size = value
                                            if addon.RefreshCooldowns then
                                                addon.RefreshCooldowns()
                                            end
                                        end,
                                        order = 4
                                    }
                                }
                            },
                            macros_color = {
                                type = 'color',
                                name = "Цвет текста макросов",
                                desc = "Цвет для текста макросов",
                                get = function()
                                    local c = addon.db.profile.buttons.macros.color;
                                    return c[1], c[2], c[3], c[4];
                                end,
                                set = function(info, r, g, b, a)
                                    addon.db.profile.buttons.macros.color = {r, g, b, a}
                                    if addon.RefreshButtons then
                                        addon.RefreshButtons()
                                    end
                                end,
                                hasAlpha = true,
                                order = 8
                            },
                            hotkey_shadow = {
                                type = 'color',
                                name = "Цвет тени горячих клавиш",
                                desc = "Цвет тени для текста горячих клавиш",
                                get = function()
                                    local c = addon.db.profile.buttons.hotkey.shadow;
                                    return c[1], c[2], c[3], c[4];
                                end,
                                set = function(info, r, g, b, a)
                                    addon.db.profile.buttons.hotkey.shadow = {r, g, b, a}
                                    if addon.RefreshButtons then
                                        addon.RefreshButtons()
                                    end
                                end,
                                hasAlpha = true,
                                order = 10
                            },
                            border_color = {
                                type = 'color',
                                name = "Цвет границы",
                                desc = "Цвет границы для кнопок",
                                get = function()
                                    local c = addon.db.profile.buttons.border_color;
                                    return c[1], c[2], c[3], c[4];
                                end,
                                set = function(info, r, g, b, a)
                                    addon.db.profile.buttons.border_color = {r, g, b, a}
                                    if addon.RefreshButtons then
                                        addon.RefreshButtons()
                                    end
                                end,
                                hasAlpha = true,
                                order = 10
                            }
                        }
                    }
                }
            },

            micromenu = {
                type = 'group',
                name = "Микроменю",
                order = 2,
                args = {
                    scale_menu = {
                        type = 'range',
                        name = "Масштаб меню",
                        desc = "Масштаб для микроменю",
                        min = 0.5,
                        max = 3.0,
                        step = 0.1,
                        get = function()
                            return addon.db.profile.micromenu.normal.scale_menu
                        end,
                        set = function(info, value)
                            addon.db.profile.micromenu.normal.scale_menu = value
                            if addon.RefreshMicromenu then
                                addon.RefreshMicromenu()
                            end
                        end,
                        order = 1
                    },

                    icon_spacing = {
                        type = 'range',
                        name = "Расстояние между иконками",
                        desc = "Промежуток между иконками (в пикселях)",
                        min = 5,
                        max = 40,
                        step = 1,
                        get = function()
                            return addon.db.profile.micromenu.normal.icon_spacing
                        end,
                        set = function(info, value)
                            addon.db.profile.micromenu.normal.icon_spacing = value
                            if addon.RefreshMicromenu then
                                addon.RefreshMicromenu()
                            end
                        end,
                        order = 2
                    },
                    hide_on_vehicle = {
                        type = 'toggle',
                        name = "Скрывать в транспорте",
                        desc = "Скрывать микроменю и сумки, если вы находитесь в транспорте",
                        get = function()
                            return addon.db.profile.micromenu.hide_on_vehicle
                        end,
                        set = function(info, value)
                            addon.db.profile.micromenu.hide_on_vehicle = value
                            -- Apply vehicle visibility immediately to both micromenu and bags
                            if addon.RefreshMicromenuVehicle then
                                addon.RefreshMicromenuVehicle()
                            end
                            if addon.RefreshBagsVehicle then
                                addon.RefreshBagsVehicle()
                            end
                        end,
                        order = 9
                    },
                                    }
            },

            bags = {
                type = 'group',
                name = "Сумки",
                order = 3,
                args = {
                    description = {
                        type = 'description',
                        name = "Настройте позицию и масштаб панели сумок независимо от микроменю.",
                        order = 1
                    },
                    scale = {
                        type = 'range',
                        name = "Масштаб",
                        desc = "Масштаб для панели сумок",
                        min = 0.5,
                        max = 2.0,
                        step = 0.1,
                        get = function()
                            return addon.db.profile.bags.scale
                        end,
                        set = function(info, value)
                            addon.db.profile.bags.scale = value
                            if addon.RefreshBagsPosition then
                                addon.RefreshBagsPosition()
                            end
                        end,
                        order = 2
                    }

                }
            },

            xprepbar = {
                type = 'group',
                name = "Полосы опыта и репутации",
                order = 6,
                args = {
                    bothbar_offset = {
                        type = 'range',
                        name = "Смещение обеих полос",
                        desc = "Смещение по Y, когда показаны обе полосы (опыт и репутация)",
                        min = 0,
                        max = 100,
                        step = 1,
                        get = function()
                            return addon.db.profile.xprepbar.bothbar_offset
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.bothbar_offset = value
                            if addon.RefreshXpRepBarPosition then
                                addon.RefreshXpRepBarPosition()
                            end
                        end,
                        order = 1
                    },
                    singlebar_offset = {
                        type = 'range',
                        name = "Смещение одной полосы",
                        desc = "Смещение по Y, когда показана одна полоса (опыт или репутация)",
                        min = 0,
                        max = 100,
                        step = 1,
                        get = function()
                            return addon.db.profile.xprepbar.singlebar_offset
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.singlebar_offset = value
                            if addon.RefreshXpRepBarPosition then
                                addon.RefreshXpRepBarPosition()
                            end
                        end,
                        order = 2
                    },
                    nobar_offset = {
                        type = 'range',
                        name = "Смещение без полос",
                        desc = "Смещение по Y, когда не показаны полосы опыта и репутации",
                        min = 0,
                        max = 100,
                        step = 1,
                        get = function()
                            return addon.db.profile.xprepbar.nobar_offset
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.nobar_offset = value
                            if addon.RefreshXpRepBarPosition then
                                addon.RefreshXpRepBarPosition()
                            end
                        end,
                        order = 3
                    },
                    repbar_abovexp_offset = {
                        type = 'range',
                        name = "Смещение полосы репутации над опытом",
                        desc = "Смещение по Y для полосы репутации, когда показана полоса опыта",
                        min = 0,
                        max = 50,
                        step = 1,
                        get = function()
                            return addon.db.profile.xprepbar.repbar_abovexp_offset
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.repbar_abovexp_offset = value
                            if addon.RefreshRepBarPosition then
                                addon.RefreshRepBarPosition()
                            end
                        end,
                        order = 4
                    },
                    repbar_offset = {
                        type = 'range',
                        name = "Смещение полосы репутации",
                        desc = "Смещение по Y, когда полоса опыта не показана",
                        min = 0,
                        max = 50,
                        step = 1,
                        get = function()
                            return addon.db.profile.xprepbar.repbar_offset
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.repbar_offset = value
                            if addon.RefreshRepBarPosition then
                                addon.RefreshRepBarPosition()
                            end
                        end,
                        order = 5
                    },
                    exhaustion_tick = {
                        type = 'toggle',
                        name = "Показать индикатор отдыха",
                        desc = "Показать индикатор отдыха на полосе опыта (синий маркер для отдохнувшего опыта). RetailUI полностью скрывает это.",
                        get = function()
                            return addon.db.profile.style.exhaustion_tick
                        end,
                        set = function(info, val)
                            addon.db.profile.style.exhaustion_tick = val
                            if addon.UpdateExhaustionTick then
                                addon.UpdateExhaustionTick()
                            end
                        end,
                        order = 6
                    },
                    expbar_scale = {
                        type = 'range',
                        name = "Масштаб полосы опыта",
                        desc = "Размер масштаба полосы опыта",
                        min = 0.5,
                        max = 1.5,
                        step = 0.05,
                        get = function()
                            return addon.db.profile.xprepbar.expbar_scale
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.expbar_scale = value
                            if addon.RefreshXpBarPosition then
                                addon.RefreshXpBarPosition()
                            end
                        end,
                        order = 7
                    },
                    repbar_scale = {
                        type = 'range',
                        name = "Масштаб полосы репутации",
                        desc = "Размер масштаба полосы репутации",
                        min = 0.5,
                        max = 1.5,
                        step = 0.05,
                        get = function()
                            return addon.db.profile.xprepbar.repbar_scale
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.repbar_scale = value
                            if addon.RefreshRepBarPosition then
                                addon.RefreshRepBarPosition()
                            end
                        end,
                        order = 8
                    }
                }
            },

            style = {
                type = 'group',
                name = "Грифоны",
                order = 7,
                args = {
                    gryphons = {
                        type = 'select',
                        name = "Стиль грифонов",
                        desc = "Стиль отображения грифонов на концах панели действий.",
                        values = function()
                            local order = {'old', 'new', 'flying', 'none'}
                            local labels = {
                                old = "Старый",
                                new = "Новый",
                                flying = "Летающий",
                                none = "Скрыть грифонов"
                            }
                            local t = {}
                            for _, k in ipairs(order) do
                                t[k] = labels[k]
                            end
                            return t
                        end,
                        get = function()
                            return addon.db.profile.style.gryphons
                        end,
                        set = function(info, val)
                            addon.db.profile.style.gryphons = val
                            if addon.RefreshMainbars then
                                addon.RefreshMainbars()
                            end
                        end,
                        order = 1
                    },
                    spacer = {
                        type = 'description',
                        name = " ", -- Espacio visual extra
                        order = 1.5
                    },
                    gryphon_previews = {
                        type = 'description',
                        name = "|cffFFD700Старый|r:      |TInterface\\AddOns\\DragonUI\\assets\\uiactionbar2x_:96:96:0:0:512:2048:1:357:209:543|t |TInterface\\AddOns\\DragonUI\\media\\uiactionbar2x_:96:96:0:0:512:2048:1:357:545:879|t\n" ..
                            "|cffFFD700Новый|r:      |TInterface\\AddOns\\DragonUI\\assets\\uiactionbar2x_new:96:96:0:0:512:2048:1:357:209:543|t |TInterface\\AddOns\\DragonUI\\media\\uiactionbar2x_new:96:96:0:0:512:2048:1:357:545:879|t\n" ..
                            "|cffFFD700Летающий|r: |TInterface\\AddOns\\DragonUI\\assets\\uiactionbar2x_flying:105:105:0:0:256:2048:1:158:149:342|t |TInterface\\AddOns\\DragonUI\\media\\uiactionbar2x_flying:105:105:0:0:256:2048:1:157:539:732|t",
                        order = 2
                    }
                }
            },

            additional = {
                type = 'group',
                name = "Дополнительные панели",
                desc = "Специализированные панели, которые появляются при необходимости (стойка/питомец/транспорт/тотемы)",
                order = 8,
                args = {
                    info_header = {
                        type = 'description',
                        name = "|cffFFD700Конфигурация дополнительных панелей|r\n" ..
                            "|cff00FF00Автоматически показываемые панели:|r Стойка (Воины/Друиды/Рыцари смерти) • Питомец (Охотники/Чернокнижники/Рыцари смерти) • Транспорт (Все классы) • Тотем (Шаманы)",
                        order = 0
                    },

                    -- COMPACT COMMON SETTINGS
                    common_group = {
                        type = 'group',
                        name = "Общие настройки",
                        inline = true,
                        order = 1,
                        args = {
                            size = {
                                type = 'range',
                                name = "Размер кнопок",
                                desc = "Размер кнопок для всех дополнительных панелей",
                                min = 15,
                                max = 50,
                                step = 1,
                                get = function()
                                    return addon.db.profile.additional.size
                                end,
                                set = function(info, value)
                                    addon.db.profile.additional.size = value
                                    if addon.RefreshStance then
                                        addon.RefreshStance()
                                    end
                                    if addon.RefreshPetbar then
                                        addon.RefreshPetbar()
                                    end
                                    if addon.RefreshVehicle then
                                        addon.RefreshVehicle()
                                    end
                                    if addon.RefreshMulticast then
                                        addon.RefreshMulticast()
                                    end
                                end,
                                order = 1,
                                width = "half"
                            },
                            spacing = {
                                type = 'range',
                                name = "Расстояние между кнопками",
                                desc = "Промежуток между кнопками для всех дополнительных панелей",
                                min = 0,
                                max = 20,
                                step = 1,
                                get = function()
                                    return addon.db.profile.additional.spacing
                                end,
                                set = function(info, value)
                                    addon.db.profile.additional.spacing = value
                                    if addon.RefreshStance then
                                        addon.RefreshStance()
                                    end
                                    if addon.RefreshPetbar then
                                        addon.RefreshPetbar()
                                    end
                                    if addon.RefreshVehicle then
                                        addon.RefreshVehicle()
                                    end
                                    if addon.RefreshMulticast then
                                        addon.RefreshMulticast()
                                    end
                                end,
                                order = 2,
                                width = "half"
                            }
                        }
                    },

                    -- INDIVIDUAL BARS - ORGANIZED IN 2x2 GRID
                    individual_bars_group = {
                        type = 'group',
                        name = "Позиции и настройки отдельных панелей",
                        desc = "|cffFFD700Теперь используется умная привязка:|r Панели автоматически позиционируются относительно друг друга",
                        inline = true,
                        order = 2,
                        args = {
                            -- TOP ROW: STANCE AND PET
                            stance_group = {
                                type = 'group',
                                name = "Панель стойки",
                                desc = "Воины, Друиды, Рыцари смерти",
                                inline = true,
                                order = 1,
                                args = {
                                    x_position = {
                                        type = 'range',
                                        name = "Позиция X",
                                        desc = "Горизонтальная позиция панели стойки от центра экрана. Отрицательные значения смещают влево, положительные - вправо.",
                                        min = -1500,
                                        max = 1500,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.additional.stance.x_position
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.stance.x_position = value
                                            if addon.RefreshStance then
                                                addon.RefreshStance()
                                            end
                                        end,
                                        order = 1,
                                        width = "full"
                                    },
                                    y_offset = {
                                        type = 'range',
                                        name = "Смещение Y",
                                        desc = "|cff00FF00Статическое позиционирование:|r Панель стойки использует фиксированную позицию от низа экрана (базовая Y=200).\n" ..
                                            "|cffFFFF00Смещение Y:|r Дополнительная вертикальная настройка, добавленная к базовой позиции.\n" ..
                                            "|cffFFD700Примечание:|r Положительные значения поднимают панель вверх, отрицательные - опускают вниз.",
                                        min = -1500,
                                        max = 1500,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.additional.stance.y_offset
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.stance.y_offset = value
                                            if addon.RefreshStance then
                                                addon.RefreshStance()
                                            end
                                        end,
                                        order = 2,
                                        width = "full"
                                    },
                                    button_size = {
                                        type = 'range',
                                        name = "Размер кнопок",
                                        desc = "Размер отдельных кнопок стойки в пикселях.",
                                        min = 16,
                                        max = 64,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.additional.stance.button_size
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.stance.button_size = value
                                            if addon.RefreshStance then
                                                addon.RefreshStance()
                                            end
                                        end,
                                        order = 3,
                                        width = "full"
                                    },
                                    button_spacing = {
                                        type = 'range',
                                        name = "Расстояние между кнопками",
                                        desc = "Промежуток между кнопками стойки в пикселях.",
                                        min = 0,
                                        max = 20,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.additional.stance.button_spacing
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.stance.button_spacing = value
                                            if addon.RefreshStance then
                                                addon.RefreshStance()
                                            end
                                        end,
                                        order = 4,
                                        width = "full"
                                    }
                                }
                            },
                            pet_group = {
                                type = 'group',
                                name = "Панель питомца",
                                desc = "Охотники, Чернокнижники, Рыцари смерти - Используйте режим редактора для перемещения",
                                inline = true,
                                order = 2,
                                args = {
                                    grid = {
                                        type = 'toggle',
                                        name = "Показать пустые слоты",
                                        desc = "Отображать пустые слоты действий на панели питомца",
                                        get = function()
                                            return addon.db.profile.additional.pet.grid
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.pet.grid = value
                                            if addon.RefreshPetbar then
                                                addon.RefreshPetbar()
                                            end
                                        end,
                                        order = 1,
                                        width = "full"
                                    }
                                }
                            },

                            -- BOTTOM ROW: VEHICLE AND TOTEM
                            vehicle_group = {
                                type = 'group',
                                name = "Панель транспорта",
                                desc = "Все классы (транспорт/специальные маунты)",
                                inline = true,
                                order = 3,
                                args = {
                                    x_position = {
                                        type = 'range',
                                        name = "Позиция X",
                                        desc = "Горизонтальная позиция панели транспорта",
                                        min = -500,
                                        max = 500,
                                        step = 1,
                                        get = function()
                                            return (addon.db.profile.additional.vehicle and
                                                       addon.db.profile.additional.vehicle.x_position) or 0
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.vehicle.x_position = value
                                            if addon.RefreshVehicle then
                                                addon.RefreshVehicle()
                                            end
                                        end,
                                        order = 1,
                                        width = "double"
                                    },
                                    artstyle = {
                                        type = 'toggle',
                                        name = "Стиль арта Blizzard",
                                        desc = "Использовать оригинальный стиль арта панели Blizzard",
                                        get = function()
                                            return addon.db.profile.additional.vehicle.artstyle
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.vehicle.artstyle = value
                                            if addon.RefreshVehicle then
                                                addon.RefreshVehicle()
                                            end
                                        end,
                                        order = 2,
                                        width = "full"
                                    }
                                }
                            }
                        }
                    }
                }
            },

            questtracker = {
                name = "Отслеживание заданий",
                type = "group",
                order = 9,
                args = {
                    description = {
                        type = 'description',
                        name = "Настройка позиции и поведения отслеживания заданий.",
                        order = 1
                    },
                    show_header = {
                        type = 'toggle',
                        name = "Показать фон заголовка",
                        desc = "Показать/скрыть декоративную текстуру фона заголовка",
                        get = function()
                            return addon.db.profile.questtracker.show_header ~= false
                        end,
                        set = function(_, value)
                            addon.db.profile.questtracker.show_header = value
                            if addon.RefreshQuestTracker then
                                addon.RefreshQuestTracker()
                            end
                        end,
                        order = 1.5
                    },
                    x = {
                        type = "range",
                        name = "Позиция X",
                        desc = "Смещение по горизонтали",
                        min = -500,
                        max = 500,
                        step = 1,
                        get = function()
                            return addon.db.profile.questtracker.x
                        end,
                        set = function(_, value)
                            addon.db.profile.questtracker.x = value
                            if addon.RefreshQuestTracker then
                                addon.RefreshQuestTracker()
                            end
                        end,
                        order = 2
                    },
                    y = {
                        type = "range",
                        name = "Позиция Y",
                        desc = "Смещение по вертикали",
                        min = -500,
                        max = 500,
                        step = 1,
                        get = function()
                            return addon.db.profile.questtracker.y
                        end,
                        set = function(_, value)
                            addon.db.profile.questtracker.y = value
                            if addon.RefreshQuestTracker then
                                addon.RefreshQuestTracker()
                            end
                        end,
                        order = 3
                    },
                    anchor = {
                        type = 'select',
                        name = "Точка привязки",
                        desc = "Точка привязки на экране для отслеживания заданий",
                        values = {
                            ["TOPRIGHT"] = "Верхний правый",
                            ["TOPLEFT"] = "Верхний левый",
                            ["BOTTOMRIGHT"] = "Нижний правый",
                            ["BOTTOMLEFT"] = "Нижний левый",
                            ["CENTER"] = "Центр"
                        },
                        get = function()
                            return addon.db.profile.questtracker.anchor
                        end,
                        set = function(_, value)
                            addon.db.profile.questtracker.anchor = value
                            if addon.RefreshQuestTracker then
                                addon.RefreshQuestTracker()
                            end
                        end,
                        order = 4
                    },
                    reset_position = {
                        type = 'execute',
                        name = "Сбросить позицию",
                        desc = "Сбросить позицию отслеживания заданий к значениям по умолчанию",
                        func = function()
                            addon.db.profile.questtracker.anchor = "TOPRIGHT"
                            addon.db.profile.questtracker.x = -140
                            addon.db.profile.questtracker.y = -255
                            if addon.RefreshQuestTracker then
                                addon.RefreshQuestTracker()
                            end
                        end,
                        order = 5
                    }
                }
            },

            minimap = {
                name = "Миникарта",
                type = "group",
                order = 10,
                args = {
                    --  CONFIGURACIONES BÁSICAS DEL MINIMAP
                    scale = {
                        type = "range",
                        name = "Масштаб",
                        min = 0.5,
                        max = 2,
                        step = 0.1,
                        get = function()
                            return addon.db.profile.minimap.scale
                        end,
                        set = function(_, val)
                            addon.db.profile.minimap.scale = val
                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateSettings()
                            end
                        end,
                        order = 1
                    },
                    border_alpha = {
                        type = 'range',
                        name = "Прозрачность границы",
                        desc = "Прозрачность верхней границы (0 для скрытия)",
                        min = 0,
                        max = 1,
                        step = 0.1,
                        get = function()
                            return addon.db.profile.minimap.border_alpha
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.border_alpha = value
                            if MinimapBorderTop then
                                MinimapBorderTop:SetAlpha(value)
                            end
                        end,
                        order = 2
                    },
                    

                    addon_button_skin = {
                        type = 'toggle',
                        name = "Стиль кнопок аддонов",
                        desc = "Применить стиль границ DragonUI к иконкам аддонов (например, аддоны сумок)",
                        get = function()
                            return addon.db.profile.minimap.addon_button_skin
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.addon_button_skin = value
                            if addon.RefreshMinimap then
                                addon:RefreshMinimap()
                            end
                        end,
                        order = 5.1
                    },

                    addon_button_fade = {
                        type = 'toggle',
                        name = "Затухание кнопок аддонов",
                        desc = "Иконки аддонов затухают при отсутствии наведения курсора (требует стиль кнопок аддонов)",
                        disabled = function()
                            return not addon.db.profile.minimap.addon_button_skin
                        end,
                        get = function()
                            return addon.db.profile.minimap.addon_button_fade
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.addon_button_fade = value
                            if addon.RefreshMinimap then
                                addon:RefreshMinimap()
                            end
                        end,
                        order = 5.1
                    },

                    player_arrow_size = {
                        type = 'range',
                        name = "Размер стрелки игрока",
                        desc = "Размер стрелки игрока на миникарте",
                        min = 8,
                        max = 50,
                        step = 1,
                        get = function()
                            return addon.db.profile.minimap.player_arrow_size
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.player_arrow_size = value
                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateSettings()
                            end
                        end,
                        order = 6
                    },

                    --  SECCIÓN TIEMPO Y CALENDARIO INTEGRADA
                    time_header = {
                        type = 'header',
                        name = "Время и календарь",
                        order = 4.5
                    },
                    clock = {
                        type = 'toggle',
                        name = "Показать часы",
                        desc = "Показать/скрыть часы на миникарте",
                        get = function()
                            return addon.db.profile.minimap.clock
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.clock = value
                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateSettings()
                            end
                        end,
                        order = 4.6
                    },
                    calendar = {
                        type = 'toggle',
                        name = "Показать календарь",
                        desc = "Показать/скрыть рамку календаря",
                        get = function()
                            return addon.db.profile.minimap.calendar
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.calendar = value
                            if GameTimeFrame then
                                if value then
                                    GameTimeFrame:Show()
                                else
                                    GameTimeFrame:Hide()
                                end
                            end
                        end,
                        order = 4.7
                    },
                    clock_font_size = {
                        type = 'range',
                        name = "Размер шрифта часов",
                        desc = "Размер шрифта для цифр часов на миникарте",
                        min = 8,
                        max = 20,
                        step = 1,
                        get = function()
                            return addon.db.profile.minimap.clock_font_size
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.clock_font_size = value
                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateSettings()
                            end
                        end,
                        order = 4.8
                    },

                    --  OTRAS CONFIGURACIONES DEL MINIMAP
                    display_header = {
                        type = 'header',
                        name = "Настройки отображения",
                        order = 5
                    },
                    tracking_icons = {
                        type = "toggle",
                        name = "Иконки отслеживания",
                        desc = "Показать текущие иконки отслеживания (старый стиль)",
                        get = function()
                            return addon.db.profile.minimap.tracking_icons
                        end,
                        set = function(_, val)
                            addon.db.profile.minimap.tracking_icons = val
                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateTrackingIcon()
                            end
                        end,
                        order = 5
                    },
                    zoom_buttons = {
                        type = 'toggle',
                        name = "Кнопки масштабирования",
                        desc = "Показать кнопки масштабирования (+/-)",
                        get = function()
                            return addon.db.profile.minimap.zoom_buttons
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.zoom_buttons = value
                            if MinimapZoomIn and MinimapZoomOut then
                                if value then
                                    MinimapZoomIn:Show()
                                    MinimapZoomOut:Show()
                                else
                                    MinimapZoomIn:Hide()
                                    MinimapZoomOut:Hide()
                                end
                            end
                        end,
                        order = 5
                    },

                    blip_skin = {
                        type = 'toggle',
                        name = "Новый стиль меток",
                        desc = "Использовать новые иконки объектов DragonUI на миникарте. Когда отключено, используются классические иконки Blizzard.",
                        get = function()
                            return addon.db.profile.minimap.blip_skin
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.blip_skin = value
                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateSettings()
                            end
                        end,
                        order = 5
                    },
                    zonetext_font_size = {
                        type = 'range',
                        name = "Размер текста зоны",
                        desc = "Размер шрифта текста зоны на верхней границе",
                        min = 8,
                        max = 20,
                        step = 1,
                        get = function()
                            return addon.db.profile.minimap.zonetext_font_size
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.zonetext_font_size = value
                            if MinimapZoneText then
                                local font, _, flags = MinimapZoneText:GetFont()
                                MinimapZoneText:SetFont(font, value, flags)
                            end
                        end,
                        order = 5.1
                    },

                    --  POSICIONAMIENTO
                    position_header = {
                        type = 'header',
                        name = "Позиция",
                        order = 6
                    },
                    position_reset = {
                        type = 'execute',
                        name = "Сбросить позицию",
                        desc = "Сбросить позицию миникарты к значениям по умолчанию (верхний правый угол)",
                        func = function()
                            --  SOLO RESETEAR SISTEMA WIDGETS
                            if not addon.db.profile.widgets then
                                addon.db.profile.widgets = {}
                            end

                            addon.db.profile.widgets.minimap = {
                                anchor = "TOPRIGHT",
                                posX = 0,
                                posY = 0
                            }

                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateSettings()
                            end

                        end,
                        order = 6.2
                    }
                }
            },

            castbars = {
                type = 'group',
                name = "Полосы заклинаний",
                order = 4,
                args = {
                    player_castbar = {
                        type = 'group',
                        name = "Полоса заклинаний игрока",
                        order = 1,
                        args = {
                            sizeX = {
                                type = 'range',
                                name = "Ширина",
                                desc = "Ширина полосы заклинаний",
                                min = 80,
                                max = 512,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.sizeX
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.sizeX = val
                                    addon.RefreshCastbar()
                                end,
                                order = 1
                            },
                            sizeY = {
                                type = 'range',
                                name = "Высота",
                                desc = "Высота полосы заклинаний",
                                min = 10,
                                max = 64,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.sizeY
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.sizeY = val
                                    addon.RefreshCastbar()
                                end,
                                order = 2
                            },
                            scale = {
                                type = 'range',
                                name = "Масштаб",
                                desc = "Масштаб размера полосы заклинаний",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.scale
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.scale = val
                                    addon.RefreshCastbar()
                                end,
                                order = 3
                            },
                            showIcon = {
                                type = 'toggle',
                                name = "Показать иконку",
                                desc = "Показать иконку заклинания рядом с полосой заклинаний",
                                get = function()
                                    return addon.db.profile.castbar.showIcon
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.showIcon = val
                                    addon.RefreshCastbar()
                                end,
                                order = 4
                            },
                            sizeIcon = {
                                type = 'range',
                                name = "Размер иконки",
                                desc = "Размер иконки заклинания",
                                min = 1,
                                max = 64,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.sizeIcon
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.sizeIcon = val
                                    addon.RefreshCastbar()
                                end,
                                order = 5,
                                disabled = function()
                                    return not addon.db.profile.castbar.showIcon
                                end
                            },
                            text_mode = {
                                type = 'select',
                                name = "Режим текста",
                                desc = "Выберите способ отображения текста заклинания: Простой (только название по центру) или Подробный (название + время)",
                                values = {
                                    simple = "Простой (только название по центру)",
                                    detailed = "Подробный (название + время)"
                                },
                                get = function()
                                    return addon.db.profile.castbar.text_mode or "simple"
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.text_mode = val
                                    addon.RefreshCastbar()
                                end,
                                order = 6
                            },
                            precision_time = {
                                type = 'range',
                                name = "Точность времени",
                                desc = "Количество знаков после запятой для оставшегося времени",
                                min = 0,
                                max = 3,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.precision_time
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.precision_time = val
                                end,
                                order = 7,
                                disabled = function()
                                    return addon.db.profile.castbar.text_mode == "simple"
                                end
                            },
                            precision_max = {
                                type = 'range',
                                name = "Точность максимального времени",
                                desc = "Количество знаков после запятой для общего времени",
                                min = 0,
                                max = 3,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.precision_max
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.precision_max = val
                                end,
                                order = 8,
                                disabled = function()
                                    return addon.db.profile.castbar.text_mode == "simple"
                                end
                            },
                            holdTime = {
                                type = 'range',
                                name = "Время удержания (успех)",
                                desc = "Как долго полоса остается видимой после успешного произнесения заклинания.",
                                min = 0,
                                max = 2,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.holdTime
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.holdTime = val
                                    addon.RefreshCastbar()
                                end,
                                order = 9
                            },
                            holdTimeInterrupt = {
                                type = 'range',
                                name = "Время удержания (прерывание)",
                                desc = "Как долго полоса остается видимой после прерывания.",
                                min = 0,
                                max = 2,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.holdTimeInterrupt
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.holdTimeInterrupt = val
                                    addon.RefreshCastbar()
                                end,
                                order = 10
                            },
                            reset_position = {
                                type = 'execute',
                                name = "Сбросить позицию",
                                desc = "Сбрасывает позицию X и Y к значениям по умолчанию.",
                                func = function()
                                    -- CRITICAL: Player castbar uses widget system, not x_position/y_position
                                    if not addon.db.profile.widgets then
                                        addon.db.profile.widgets = {}
                                    end
                                    if not addon.db.profile.widgets.playerCastbar then
                                        addon.db.profile.widgets.playerCastbar = {}
                                    end
                                    
                                    -- Reset to default values from database.lua
                                    local defaults = addon.defaults and addon.defaults.profile and addon.defaults.profile.widgets and addon.defaults.profile.widgets.playerCastbar
                                    if defaults then
                                        addon.db.profile.widgets.playerCastbar.anchor = defaults.anchor or "BOTTOM"
                                        addon.db.profile.widgets.playerCastbar.posX = defaults.posX or 0
                                        addon.db.profile.widgets.playerCastbar.posY = defaults.posY or 200
                                    else
                                        -- Fallback to hardcoded defaults if defaults table is not available
                                        addon.db.profile.widgets.playerCastbar.anchor = "BOTTOM"
                                        addon.db.profile.widgets.playerCastbar.posX = 0
                                        addon.db.profile.widgets.playerCastbar.posY = 200
                                    end
                                    
                                    -- Also reset legacy x_position/y_position if they exist
                                    if addon.db.profile.castbar then
                                        addon.db.profile.castbar.x_position = addon.defaults.profile.castbar.x_position or 0
                                        addon.db.profile.castbar.y_position = addon.defaults.profile.castbar.y_position or 200
                                    end
                                    
                                    -- Refresh castbar position
                                    if addon.RefreshCastbar then
                                        addon.RefreshCastbar()
                                    end
                                    
                                    -- Also update widget system if available
                                    -- Note: CastbarModule is local to castbar.lua, so we just refresh the castbar
                                    -- The RefreshCastbar call should handle position updates
                                end,
                                order = 11
                            }
                        }
                    },

                    target_castbar = {
                        type = 'group',
                        name = "Полоса заклинаний цели",
                        order = 2,
                        args = {
                            sizeX = {
                                type = 'range',
                                name = "Ширина",
                                desc = "Ширина полосы заклинаний цели",
                                min = 50,
                                max = 400,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.target and addon.db.profile.castbar.target.sizeX or
                                               150
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.sizeX = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 1
                            },
                            sizeY = {
                                type = 'range',
                                name = "Высота",
                                desc = "Высота полосы заклинаний цели",
                                min = 5,
                                max = 50,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.target and addon.db.profile.castbar.target.sizeY or
                                               10
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.sizeY = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 2
                            },
                            scale = {
                                type = 'range',
                                name = "Масштаб",
                                desc = "Масштаб полосы заклинаний цели",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.target and addon.db.profile.castbar.target.scale or
                                               1
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.scale = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 3
                            },
                            showIcon = {
                                type = 'toggle',
                                name = "Показать иконку заклинания",
                                desc = "Показать иконку заклинания рядом с полосой заклинаний цели",
                                get = function()
                                    if not addon.db.profile.castbar.target then
                                        return true
                                    end
                                    local value = addon.db.profile.castbar.target.showIcon
                                    if value == nil then
                                        return true
                                    end
                                    return value == true
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.showIcon = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 4
                            },
                            sizeIcon = {
                                type = 'range',
                                name = "Размер иконки",
                                desc = "Размер иконки заклинания",
                                min = 10,
                                max = 50,
                                step = 1,
                                get = function()
                                    return
                                        addon.db.profile.castbar.target and addon.db.profile.castbar.target.sizeIcon or
                                            20
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.sizeIcon = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 5,
                                disabled = function()
                                    return not (addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.showIcon)
                                end
                            },
                            text_mode = {
                                type = 'select',
                                name = "Режим текста",
                                desc = "Выберите способ отображения текста заклинания: Простой (только название по центру) или Подробный (название + время)",
                                values = {
                                    simple = "Простой (только название)",
                                    detailed = "Подробный (название + время)"
                                },
                                get = function()
                                    return (addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.text_mode) or "simple"
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.text_mode = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 6
                            },
                            precision_time = {
                                type = 'range',
                                name = "Точность времени",
                                desc = "Количество знаков после запятой для оставшегося времени",
                                min = 0,
                                max = 3,
                                step = 1,
                                get = function()
                                    return (addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.precision_time) or 1
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.precision_time = val
                                end,
                                order = 7,
                                disabled = function()
                                    --  CORRECCIÓN LÓGICA: Deshabilitar si el modo es "simple"
                                    return (addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.text_mode) == "simple"
                                end
                            },
                            precision_max = {
                                type = 'range',
                                name = "Точность максимального времени",
                                desc = "Количество знаков после запятой для общего времени",
                                min = 0,
                                max = 3,
                                step = 1,
                                get = function()
                                    return (addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.precision_max) or 1
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.precision_max = val
                                end,
                                order = 8,
                                disabled = function()
                                    --  CORRECCIÓN LÓGICA: Deshabilitar si el modo es "simple"
                                    return (addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.text_mode) == "simple"
                                end
                            },
                            autoAdjust = {
                                type = 'toggle',
                                name = "Автоматическая подстройка под ауры",
                                desc = "Автоматически подстраивать позицию в зависимости от аур цели (КРИТИЧЕСКАЯ ФУНКЦИЯ)",
                                get = function()
                                    if not addon.db.profile.castbar.target then
                                        return true
                                    end
                                    local value = addon.db.profile.castbar.target.autoAdjust
                                    if value == nil then
                                        return true
                                    end
                                    return value == true
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.autoAdjust = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 9
                            },
                            holdTime = {
                                type = 'range',
                                name = "Время удержания (успех)",
                                desc = "Как долго показывать полосу заклинаний после успешного завершения",
                                min = 0,
                                max = 3,
                                step = 0.1,
                                get = function()
                                    return
                                        addon.db.profile.castbar.target and addon.db.profile.castbar.target.holdTime or
                                            0.3
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.holdTime = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 10
                            },
                            holdTimeInterrupt = {
                                type = 'range',
                                name = "Время удержания (прерывание)",
                                desc = "Как долго показывать полосу заклинаний после прерывания/неудачи",
                                min = 0,
                                max = 3,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.holdTimeInterrupt or 0.8
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.holdTimeInterrupt = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 11
                            },
                            reset_position = {
                                type = 'execute',
                                name = "Сбросить позицию",
                                desc = "Сбросить позицию полосы заклинаний цели к значениям по умолчанию",
                                func = function()
                                    -- CRITICAL: Target castbar uses widget system, not x_position/y_position
                                    if not addon.db.profile.widgets then
                                        addon.db.profile.widgets = {}
                                    end
                                    if not addon.db.profile.widgets.targetCastbar then
                                        addon.db.profile.widgets.targetCastbar = {}
                                    end
                                    
                                    -- Reset to default values from database.lua
                                    local defaults = addon.defaults and addon.defaults.profile and addon.defaults.profile.widgets and addon.defaults.profile.widgets.targetCastbar
                                    if defaults then
                                        addon.db.profile.widgets.targetCastbar.anchor = defaults.anchor or "TOP"
                                        addon.db.profile.widgets.targetCastbar.anchorParent = defaults.anchorParent or "BOTTOM"
                                        addon.db.profile.widgets.targetCastbar.anchorFrame = defaults.anchorFrame or "TargetFrame"
                                        addon.db.profile.widgets.targetCastbar.posX = defaults.posX or -20
                                        addon.db.profile.widgets.targetCastbar.posY = defaults.posY or -10
                                    else
                                        -- Fallback to hardcoded defaults if defaults table is not available
                                        addon.db.profile.widgets.targetCastbar.anchor = "TOP"
                                        addon.db.profile.widgets.targetCastbar.anchorParent = "BOTTOM"
                                        addon.db.profile.widgets.targetCastbar.anchorFrame = "TargetFrame"
                                        addon.db.profile.widgets.targetCastbar.posX = -20
                                        addon.db.profile.widgets.targetCastbar.posY = -10
                                    end
                                    
                                    -- Also reset legacy x_position/y_position if they exist
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.x_position = -20
                                    addon.db.profile.castbar.target.y_position = -10
                                    
                                    -- Refresh castbar position
                                    if addon.RefreshTargetCastbar then
                                        addon.RefreshTargetCastbar()
                                    end
                                    
                                    -- Also update widget system if available
                                    -- Note: CastbarModule is local to castbar.lua, so we just refresh the castbar
                                    -- The RefreshCastbar call should handle position updates
                                end,
                                order = 12
                            }
                        }
                    },

                    focus_castbar = {
                        type = 'group',
                        name = "Полоса заклинаний фокуса",
                        order = 3,
                        args = {
                            sizeX = {
                                type = 'range',
                                name = "Ширина",
                                desc = "Ширина полосы заклинаний фокуса",
                                min = 50,
                                max = 400,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.focus.sizeX or 200
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.sizeX = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 1
                            },
                            sizeY = {
                                type = 'range',
                                name = "Высота",
                                desc = "Высота полосы заклинаний фокуса",
                                min = 5,
                                max = 50,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.focus.sizeY or 16
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.sizeY = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 2
                            },
                            scale = {
                                type = 'range',
                                name = "Масштаб",
                                desc = "Масштаб полосы заклинаний фокуса",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.focus.scale or 1
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.scale = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 3
                            },
                            showIcon = {
                                type = 'toggle',
                                name = "Показать иконку",
                                desc = "Показать иконку заклинания рядом с полосой заклинаний фокуса",
                                get = function()
                                    return addon.db.profile.castbar.focus.showIcon
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.showIcon = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 4
                            },
                            sizeIcon = {
                                type = 'range',
                                name = "Размер иконки",
                                desc = "Размер иконки заклинания",
                                min = 10,
                                max = 50,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.focus.sizeIcon or 20
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.sizeIcon = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 5,
                                disabled = function()
                                    return not addon.db.profile.castbar.focus.showIcon
                                end
                            },
                            text_mode = {
                                type = 'select',
                                name = "Режим текста",
                                desc = "Выберите способ отображения текста заклинания: Простой (только название по центру) или Подробный (название + время)",
                                values = {
                                    simple = "Простой",
                                    detailed = "Подробный"
                                },
                                get = function()
                                    return addon.db.profile.castbar.focus.text_mode or "detailed"
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.text_mode = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 6
                            },
                            precision_time = {
                                type = 'range',
                                name = "Точность времени",
                                desc = "Количество знаков после запятой для оставшегося времени",
                                min = 0,
                                max = 3,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.focus.precision_time or 1
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.focus.precision_time = val
                                end,
                                order = 7,
                                disabled = function()
                                    return addon.db.profile.castbar.focus.text_mode == "simple"
                                end
                            },
                            precision_max = {
                                type = 'range',
                                name = "Точность максимального времени",
                                desc = "Количество знаков после запятой для общего времени",
                                min = 0,
                                max = 3,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.focus.precision_max or 1
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.focus.precision_max = val
                                end,
                                order = 8,
                                disabled = function()
                                    return addon.db.profile.castbar.focus.text_mode == "simple"
                                end
                            },
                            autoAdjust = {
                                type = 'toggle',
                                name = "Автоматическая подстройка под ауры",
                                desc = "Автоматически подстраивать позицию в зависимости от аур фокуса",
                                get = function()
                                    return addon.db.profile.castbar.focus.autoAdjust
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.autoAdjust = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 9
                            },
                            holdTime = {
                                type = 'range',
                                name = "Время удержания (успех)",
                                desc = "Время показа полосы заклинаний после успешного завершения произнесения",
                                min = 0,
                                max = 3.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.focus.holdTime or 0.3
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.holdTime = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 10
                            },
                            holdTimeInterrupt = {
                                type = 'range',
                                name = "Время удержания (прерывание)",
                                desc = "Время показа полосы заклинаний после прерывания произнесения",
                                min = 0,
                                max = 3.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.focus.holdTimeInterrupt or 0.8
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.holdTimeInterrupt = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 11
                            },
                            reset_position = {
                                type = 'execute',
                                name = "Сбросить позицию",
                                desc = "Сбросить позицию полосы заклинаний фокуса к значениям по умолчанию",
                                func = function()
                                    local defaults = addon.defaults.profile.castbar.focus
                                    addon.db.profile.castbar.focus.x_position = defaults.x_position
                                    addon.db.profile.castbar.focus.y_position = defaults.y_position
                                    addon.RefreshFocusCastbar()
                                end,
                                order = 12
                            }
                        }
                    }
                }
            },

            unitframe = {
                type = 'group',
                name = "Рамки юнитов",
                order = 5,
                args = {
                    general = {
                        type = 'group',
                        name = "Общие",
                        inline = true,
                        order = 1,
                        args = {
                            scale = {
                                type = 'range',
                                name = "Общий масштаб",
                                desc = "Общий масштаб для всех рамок юнитов",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.scale = value
                                    --  TRIGGER DIRECTO SIN THROTTLING
                                    if addon.RefreshUnitFrames then
                                        addon.RefreshUnitFrames()
                                    end
                                end,
                                order = 1
                            }
                        }
                    },

                    player = {
                        type = 'group',
                        name = "Рамка игрока",
                        order = 2,
                        args = {
                            scale = {
                                type = 'range',
                                name = "Масштаб",
                                desc = "Масштаб рамки игрока",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.player.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.scale = value
                                    --  REFRESH AUTOMÁTICO
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 1
                            },
                            classcolor = {
                                type = 'toggle',
                                name = "Цвет класса",
                                desc = "Использовать цвет класса для полосы здоровья",
                                get = function()
                                    return addon.db.profile.unitframe.player.classcolor
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.classcolor = value
                                    --  TRIGGER INMEDIATO
                                    if addon.PlayerFrame and addon.PlayerFrame.UpdatePlayerHealthBarColor then
                                        addon.PlayerFrame.UpdatePlayerHealthBarColor()
                                    end
                                end,
                                order = 2
                            },
                            breakUpLargeNumbers = {
                                type = 'toggle',
                                name = "Большие числа",
                                desc = "Форматировать большие числа (1к, 1м)",
                                get = function()
                                    return addon.db.profile.unitframe.player.breakUpLargeNumbers
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.breakUpLargeNumbers = value
                                    --  AUTO-REFRESH
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 3
                            },
                            textFormat = {
                                type = 'select',
                                name = "Формат текста",
                                desc = "Как отображать значения здоровья и маны",
                                values = {
                                    numeric = "Только текущее значение",
                                    percentage = "Только процент",
                                    both = "Оба (Числа + Процент)",
                                    formatted = "Текущее/Максимальное"
                                },
                                get = function()
                                    return addon.db.profile.unitframe.player.textFormat
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.textFormat = value
                                    --  AUTO-REFRESH
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 4
                            },
                            showHealthTextAlways = {
                                type = 'toggle',
                                name = "Всегда показывать текст здоровья",
                                desc = "Показывать текст здоровья всегда (да) или только при наведении (нет)",
                                get = function()
                                    return addon.db.profile.unitframe.player.showHealthTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.showHealthTextAlways = value
                                    --  AUTO-REFRESH
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 5
                            },
                            showManaTextAlways = {
                                type = 'toggle',
                                name = "Всегда показывать текст маны",
                                desc = "Показывать текст маны/силы всегда (да) или только при наведении (нет)",
                                get = function()
                                    return addon.db.profile.unitframe.player.showManaTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.showManaTextAlways = value
                                    --  AUTO-REFRESH
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 6
                            },

                            dragon_decoration = {
                                type = 'select',
                                name = "Драконье украшение",
                                desc = "Добавить декоративного дракона на рамку игрока для премиум вида",
                                values = {
                                    none = "Нет",
                                    elite = "Элитный дракон (Золотой)",
                                    rareelite = "Редкий элитный дракон (Крылатый)"
                                },
                                get = function()
                                    return addon.db.profile.unitframe.player.dragon_decoration or "none"
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.dragon_decoration = value
                                    --  AUTO-REFRESH
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 10
                            },
                            alwaysShowAlternateManaText = {
                                type = 'toggle',
                                name = "Всегда показывать альтернативный текст маны",
                                desc = "Показывать текст маны всегда видимым (по умолчанию: только при наведении)",
                                get = function()
                                    return addon.db.profile.unitframe.player.alwaysShowAlternateManaText
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.alwaysShowAlternateManaText = value
                                    -- Apply immediately if player config exists
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 11
                            },
                            alternateManaFormat = {
                                type = 'select',
                                name = "Формат альтернативного текста маны",
                                desc = "Выберите формат текста для альтернативного отображения маны",
                                values = {
                                    numeric = "Только текущее значение",
                                    formatted = "Текущее / Макс",
                                    percentage = "Только процент",
                                    both = "Процент + Текущее/Макс"
                                },
                                get = function()
                                    return addon.db.profile.unitframe.player.alternateManaFormat or "both"
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.alternateManaFormat = value
                                    -- Apply immediately if player config exists
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 12
                            }
                        }
                    },

                    target = {
                        type = 'group',
                        name = "Рамка цели",
                        order = 3,
                        args = {
                            scale = {
                                type = 'range',
                        name = "Масштаб",
                        desc = "Масштаб рамки цели",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.target.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.scale = value
                                    --  AUTO-REFRESH
                                    if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
                                        addon.TargetFrame.RefreshTargetFrame()
                                    end
                                end,
                                order = 1
                            },
                            classcolor = {
                                type = 'toggle',
                                name = "Цвет класса",
                                desc = "Использовать цвет класса для полосы здоровья",
                                get = function()
                                    return addon.db.profile.unitframe.target.classcolor
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.classcolor = value
                                    --  TRIGGER INMEDIATO
                                    if addon.TargetFrame and addon.TargetFrame.UpdateTargetHealthBarColor then
                                        addon.TargetFrame.UpdateTargetHealthBarColor()
                                    end
                                end,
                                order = 2
                            },
                            breakUpLargeNumbers = {
                                type = 'toggle',
                                name = "Большие числа",
                                desc = "Форматировать большие числа (1к, 1м)",
                                get = function()
                                    return addon.db.profile.unitframe.target.breakUpLargeNumbers
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.breakUpLargeNumbers = value
                                    --  AUTO-REFRESH
                                    if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
                                        addon.TargetFrame.RefreshTargetFrame()
                                    end
                                end,
                                order = 3
                            },
                            textFormat = {
                                type = 'select',
                                name = "Формат текста",
                                desc = "Как отображать значения здоровья и маны",
                                values = {
                                    numeric = "Только текущее значение",
                                    percentage = "Только процент",
                                    both = "Оба (Числа + Процент)",
                                    formatted = "Текущее/Максимальное"
                                },
                                get = function()
                                    return addon.db.profile.unitframe.target.textFormat
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.textFormat = value
                                    --  AUTO-REFRESH
                                    if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
                                        addon.TargetFrame.RefreshTargetFrame()
                                    end
                                end,
                                order = 4
                            },
                            showHealthTextAlways = {
                                type = 'toggle',
                                name = "Всегда показывать текст здоровья",
                                desc = "Показывать текст здоровья всегда (да) или только при наведении (нет)",
                                get = function()
                                    return addon.db.profile.unitframe.target.showHealthTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.showHealthTextAlways = value
                                    --  AUTO-REFRESH
                                    if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
                                        addon.TargetFrame.RefreshTargetFrame()
                                    end
                                end,
                                order = 5
                            },
                            showManaTextAlways = {
                                type = 'toggle',
                                name = "Всегда показывать текст маны",
                                desc = "Показывать текст маны/ресурса всегда (да) или только при наведении (нет)",
                                get = function()
                                    return addon.db.profile.unitframe.target.showManaTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.showManaTextAlways = value
                                    --  AUTO-REFRESH
                                    if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
                                        addon.TargetFrame.RefreshTargetFrame()
                                    end
                                end,
                                order = 6
                            },
                            enableNumericThreat = {
                                type = 'toggle',
                                name = "Числовой индикатор угрозы",
                                desc = "Показывать процент угрозы в числовом виде",
                                get = function()
                                    return addon.db.profile.unitframe.target.enableNumericThreat
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.enableNumericThreat = value
                                    --  AUTO-REFRESH
                                    if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
                                        addon.TargetFrame.RefreshTargetFrame()
                                    end
                                end,
                                order = 7
                            },
                            enableThreatGlow = {
                                type = 'toggle',
                                name = "Свечение угрозы",
                                desc = "Показывать эффект свечения угрозы",
                                get = function()
                                    return addon.db.profile.unitframe.target.enableThreatGlow
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.enableThreatGlow = value
                                    --  AUTO-REFRESH
                                    if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
                                        addon.TargetFrame.RefreshTargetFrame()
                                    end
                                end,
                                order = 8
                            }
                        }
                    },

                    tot = {
    type = 'group',
    name = "Цель цели",
    order = 4,
    args = {
        info = {
            type = 'description',
            name = "|cffFFD700Примечание:|r DragonUI стилизует стандартную рамку цели цели WoW.\n\n" ..
                  "|cffFF6347Если вы её не видите:|r\n" ..
                  "1. Нажмите |cff00FF00ESC|r -> Интерфейс -> Бой\n" ..
                  "2. Установите галочку |cff00FF00'Цель цели'|r\n" ..
                  "3. Перезагрузите интерфейс",
            order = 0
        },
        scale = {
                                type = 'range',
                                name = "Масштаб",
                                desc = "Масштаб рамки цели цели",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.tot.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.tot.scale = value
                                    if addon.TargetOfTarget and addon.TargetOfTarget.RefreshToTFrame then
                                        addon.TargetOfTarget.RefreshToTFrame()
                                    end
                                end,
                                order = 1
                            },
                            classcolor = {
                                type = 'toggle',
                                name = "Цвет класса",
                                desc = "Использовать цвет класса для полосы здоровья",
                                get = function()
                                    return addon.db.profile.unitframe.tot.classcolor
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.tot.classcolor = value
                                    if addon.TargetOfTarget and addon.TargetOfTarget.RefreshToTFrame then
                                        addon.TargetOfTarget.RefreshToTFrame()
                                    end
                                end,
                                order = 2
                            },
                            x = {
                                type = 'range',
                                name = "Позиция X",
                                desc = "Смещение по горизонтали",
                                min = -200,
                                max = 200,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.tot.x
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.tot.x = value
                                    if addon.TargetOfTarget and addon.TargetOfTarget.RefreshToTFrame then
                                        addon.TargetOfTarget.RefreshToTFrame()
                                    end
                                end,
                                order = 3
                            },
                            y = {
                                type = 'range',
                                name = "Позиция Y",
                                desc = "Смещение по вертикали",
                                min = -200,
                                max = 200,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.tot.y
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.tot.y = value
                                    if addon.TargetOfTarget and addon.TargetOfTarget.RefreshToTFrame then
                                        addon.TargetOfTarget.RefreshToTFrame()
                                    end
                                end,
                                order = 4
                            }
                        }
                    },

                    fot = {
                        type = 'group',
                        name = "Цель фокуса",
                        order = 4.5,
                        args = {
                            scale = {
                                type = 'range',
                                name = "Масштаб",
                                desc = "Масштаб рамки цели фокуса",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.fot.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.fot.scale = value
                                    if addon.TargetOfFocus and addon.TargetOfFocus.RefreshToFFrame then
                                        addon.TargetOfFocus.RefreshToFFrame()
                                    end
                                end,
                                order = 1
                            },
                            classcolor = {
                                type = 'toggle',
                                name = "Цвет класса",
                                desc = "Использовать цвет класса для полосы здоровья",
                                get = function()
                                    return addon.db.profile.unitframe.fot.classcolor
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.fot.classcolor = value
                                    if addon.TargetOfFocus and addon.TargetOfFocus.RefreshToFFrame then
                                        addon.TargetOfFocus.RefreshToFFrame()
                                    end
                                end,
                                order = 2
                            },
                            x = {
                                type = 'range',
                                name = "Позиция X",
                                desc = "Смещение по горизонтали",
                                min = -200,
                                max = 200,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.fot.x
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.fot.x = value
                                    if addon.TargetOfFocus and addon.TargetOfFocus.RefreshToFFrame then
                                        addon.TargetOfFocus.RefreshToFFrame()
                                    end
                                end,
                                order = 3
                            },
                            y = {
                                type = 'range',
                                name = "Позиция Y",
                                desc = "Смещение по вертикали",
                                min = -200,
                                max = 200,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.fot.y
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.fot.y = value
                                    if addon.TargetOfFocus and addon.TargetOfFocus.RefreshToFFrame then
                                        addon.TargetOfFocus.RefreshToFFrame()
                                    end
                                end,
                                order = 4
                            }
                        }
                    },

                    focus = {
                        type = 'group',
                        name = "Рамка фокуса",
                        order = 5,
                        args = {
                            scale = {
                                type = 'range',
                        name = "Масштаб",
                        desc = "Масштаб рамки фокуса",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.focus.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.scale = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 1
                            },
                            classcolor = {
                                type = 'toggle',
                                name = "Цвет класса",
                                desc = "Использовать цвет класса для полосы здоровья",
                                get = function()
                                    return addon.db.profile.unitframe.focus.classcolor
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.classcolor = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 2
                            },
                            breakUpLargeNumbers = {
                                type = 'toggle',
                                name = "Большие числа",
                                desc = "Форматировать большие числа (1к, 1м)",
                                get = function()
                                    return addon.db.profile.unitframe.focus.breakUpLargeNumbers
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.breakUpLargeNumbers = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 3
                            },
                            textFormat = {
                                type = 'select',
                                name = "Формат текста",
                                desc = "Как отображать значения здоровья и маны",
                                values = {
                                    numeric = "Только текущее значение",
                                    percentage = "Только процент",
                                    both = "Оба (Числа + Процент)",
                                    formatted = "Текущее/Максимальное"
                                },
                                get = function()
                                    return addon.db.profile.unitframe.focus.textFormat
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.textFormat = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 4
                            },
                            showHealthTextAlways = {
                                type = 'toggle',
                                name = "Всегда показывать текст здоровья",
                                desc = "Показывать текст здоровья всегда (да) или только при наведении (нет)",
                                get = function()
                                    return addon.db.profile.unitframe.focus.showHealthTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.showHealthTextAlways = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 5
                            },
                            showManaTextAlways = {
                                type = 'toggle',
                                name = "Всегда показывать текст маны",
                                desc = "Показывать текст маны/ресурса всегда (да) или только при наведении (нет)",
                                get = function()
                                    return addon.db.profile.unitframe.focus.showManaTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.showManaTextAlways = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 6
                            },
                            override = {
                                type = 'toggle',
                                name = "Override Position",
                                desc = "Override default positioning",
                                get = function()
                                    return addon.db.profile.unitframe.focus.override
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.override = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 6
                            }
                            -- X/Y Position options removed - now using centralized widget system
                        }
                    },

                    pet = {
                        type = 'group',
                        name = "Рамка питомца",
                        order = 6,
                        args = {
                            scale = {
                                type = 'range',
                        name = "Масштаб",
                        desc = "Масштаб рамки питомца",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.pet.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.scale = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 1
                            },
                            textFormat = {
                                type = 'select',
                                name = "Формат текста",
                                desc = "Как отображать значения здоровья и маны",
                                values = {
                                    numeric = "Только текущее значение",
                                    percentage = "Только процент",
                                    both = "Оба (Числа + Процент)",
                                    formatted = "Текущее/Максимальное"
                                },
                                get = function()
                                    return addon.db.profile.unitframe.pet.textFormat
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.textFormat = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 2
                            },
                            breakUpLargeNumbers = {
                                type = 'toggle',
                                name = "Большие числа",
                                desc = "Форматировать большие числа (1к, 1м)",
                                get = function()
                                    return addon.db.profile.unitframe.pet.breakUpLargeNumbers
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.breakUpLargeNumbers = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 3
                            },
                            showHealthTextAlways = {
                                type = 'toggle',
                                name = "Всегда показывать текст здоровья",
                                desc = "Всегда отображать текст здоровья (иначе только при наведении)",
                                get = function()
                                    return addon.db.profile.unitframe.pet.showHealthTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.showHealthTextAlways = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 4
                            },
                            showManaTextAlways = {
                                type = 'toggle',
                                name = "Всегда показывать текст маны",
                                desc = "Всегда отображать текст маны/энергии/ярости (иначе только при наведении)",
                                get = function()
                                    return addon.db.profile.unitframe.pet.showManaTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.showManaTextAlways = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 5
                            },
                            enableThreatGlow = {
                                type = 'toggle',
                                name = "Свечение угрозы",
                                desc = "Показывать эффект свечения угрозы",
                                get = function()
                                    return addon.db.profile.unitframe.pet.enableThreatGlow
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.enableThreatGlow = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 6
                            },
                            override = {
                                type = 'toggle',
                                name = "Override Position",
                                desc = "Allows the pet frame to be moved freely. When unchecked, it will be positioned relative to the player frame.",
                                get = function()
                                    return addon.db.profile.unitframe.pet.override
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.override = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 7
                            },
                            -- REMOVED: Anchor options are not needed for a simple movable frame.
                            -- The X and Y coordinates will be relative to the center of the screen when override is active.
                            x = {
                                type = 'range',
                                name = "X Position",
                                desc = "Horizontal position (only active if Override is checked)",
                                min = -2500,
                                max = 2500,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.pet.x
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.x = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 10,
                                disabled = function()
                                    return not addon.db.profile.unitframe.pet.override
                                end
                            },
                            y = {
                                type = 'range',
                                name = "Y Position",
                                desc = "Vertical position (only active if Override is checked)",
                                min = -2500,
                                max = 2500,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.pet.y
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.y = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 11,
                                disabled = function()
                                    return not addon.db.profile.unitframe.pet.override
                                end
                            }
                        }
                    },

                    party = {
                        type = 'group',
                        name = "Рамки группы",
                        order = 6,
                        args = {
                            info_text = {
                                type = 'description',
                                name = "|cffFFD700Конфигурация рамок группы|r\n\nПользовательский стиль для рамок участников группы с автоматическим отображением текста здоровья/маны и цветами класса.",
                                order = 0
                            },
                            scale = {
                                type = 'range',
                                name = "Масштаб",
                                desc = "Масштаб рамок группы",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.party.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.scale = value
                                    --  AUTO-REFRESH
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 1
                            },
                            classcolor = {
                                type = 'toggle',
                                name = "Цвет класса",
                                desc = "Использовать цвет класса для полос здоровья в рамках группы",
                                get = function()
                                    return addon.db.profile.unitframe.party.classcolor
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.classcolor = value
                                    --  AUTO-REFRESH
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 2
                            },
                            breakUpLargeNumbers = {
                                type = 'toggle',
                                name = "Большие числа",
                                desc = "Форматировать большие числа (1к, 1м)",
                                get = function()
                                    return addon.db.profile.unitframe.party.breakUpLargeNumbers
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.breakUpLargeNumbers = value
                                    --  AUTO-REFRESH
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 3
                            },
                            showHealthTextAlways = {
                                type = 'toggle',
                                name = "Всегда показывать текст здоровья",
                                desc = "Всегда показывать текст здоровья на рамках группы (вместо только при наведении)",
                                get = function()
                                    return addon.db.profile.unitframe.party.showHealthTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.showHealthTextAlways = value
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 3.1
                            },
                            showManaTextAlways = {
                                type = 'toggle',
                                name = "Всегда показывать текст маны",
                                desc = "Всегда показывать текст маны на рамках группы (вместо только при наведении)",
                                get = function()
                                    return addon.db.profile.unitframe.party.showManaTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.showManaTextAlways = value
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 3.2
                            },
                            textFormat = {
                                type = 'select',
                                name = "Формат текста",
                                desc = "Выберите способ отображения текста здоровья и маны",
                                values = {
                                    ['numeric'] = 'Только текущее значение (2345)',
                                    ['formatted'] = 'Форматированное текущее (2.3k)', 
                                    ['percentage'] = 'Только процент (75%)',
                                    ['both'] = 'Процент + Текущее (75% | 2.3k)'
                                },
                                get = function()
                                    return addon.db.profile.unitframe.party.textFormat or 'both'
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.textFormat = value
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 3.3
                            },
                            orientation = {
                                type = 'select',
                                name = "Ориентация",
                                desc = "Ориентация рамок группы",
                                values = {
                                    ['vertical'] = 'Вертикальная',
                                    ['horizontal'] = 'Горизонтальная'
                                },
                                get = function()
                                    return addon.db.profile.unitframe.party.orientation
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.orientation = value
                                    --  AUTO-REFRESH
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 4
                            },
                            padding = {
                                type = 'range',
                                name = "Отступ",
                                desc = "Расстояние между рамками группы",
                                min = 0,
                                max = 50,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.party.padding
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.padding = value
                                    --  AUTO-REFRESH
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 5
                            },
                           
                        }
                    }
                }
            },

            profiles = (function()
                -- Obtenemos la tabla de opciones de perfiles estándar
                local profileOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(addon.db)

                -- Modificamos los textos para que sean más concisos
                profileOptions.name = "Профили"
                profileOptions.desc = "Управление профилями настроек интерфейса."
                profileOptions.order = 99

                --  COMPROBAMOS QUE LA TABLA DE PERFIL EXISTE ANTES DE MODIFICARLA
                if profileOptions.args and profileOptions.args.profile then
                    profileOptions.args.profile.name = "Активный профиль"
                    profileOptions.args.profile.desc = "Выберите профиль для использования в ваших настройках."
                end

                -- AÑADIMOS LA DESCRIPCIÓN Y EL BOTÓN DE RECARGA
                profileOptions.args.reload_warning = {
                    type = 'description',
                    name = "\n|cffFFD700Рекомендуется перезагрузить интерфейс после смены профиля.|r",
                    order = 15 -- Justo después del selector de perfiles
                }

                profileOptions.args.reload_execute = {
                    type = 'execute',
                    name = "Перезагрузить интерфейс",
                    func = function()
                        ReloadUI()
                    end,
                    order = 16 -- Justo después del texto de advertencia
                }

                return profileOptions
            end)()
        }
    }
end
