local Scene = require("src.core.Scene")
local Keymap = require("src.settings.Keymap")
local UI = require("src.ui.Theme")
local GameConfig = require("src.settings.GameConfig")

local MainMenu = Scene:extend()

function MainMenu:init(game)
    Scene.init(self, "MainMenu", game)
    self.selected = 1
    self.options = {"Start", "About", "Quit"}
end

function MainMenu:draw()
    local width, height = love.graphics.getDimensions()
    local scale = UI.scale(width, height)
    UI.setColor("text")
    UI.setFont(88, width, height)
    love.graphics.printf(GameConfig.title:upper(), 0, height * 0.18, width, "center")

    local panelX, panelY = 44 * scale, height - 230 * scale
    local panelWidth, panelHeight = 360 * scale, 150 * scale
    UI.drawPanel(panelX, panelY, panelWidth, panelHeight)

    local rowY = panelY + 18 * scale
    for index, label in ipairs(self.options) do
        local y = rowY + (index - 1) * 43 * scale
        if index == self.selected then
            UI.drawSelection(panelX + 14 * scale, y - 3 * scale, panelWidth - 28 * scale, 38 * scale)
        end
        UI.setColor(index == self.selected and "accent" or "text")
        UI.setFont(30, width, height)
        love.graphics.print((index == self.selected and "> " or "  ") .. label,
            panelX + 28 * scale, y)
    end
    self:drawChildren(nil, self)
end

function MainMenu:keypressed(key)
    if Keymap.matches("menuUp", key) or Keymap.matches("menuDown", key) then
        if Keymap.matches("menuUp", key) then
            self.selected = (self.selected - 2) % #self.options + 1
        else
            self.selected = self.selected % #self.options + 1
        end
        self.game.audio:play("uiClick")
    elseif Keymap.matches("confirm", key) then
        self.game.audio:play("uiClick")
        if self.selected == 1 then
            self.game.scenes:switch("levels")
        elseif self.selected == 2 then
            self.game.scenes:switch("about")
        else
            love.event.quit()
        end
    end
end

return MainMenu
