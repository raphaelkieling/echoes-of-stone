local LevelLoader = require("src.game.LevelLoader")
local Scene = require("src.core.Scene")
local Keymap = require("src.settings.Keymap")
local UI = require("src.ui.Theme")

local LevelSelect = Scene:extend()

function LevelSelect:init(game)
    Scene.init(self, "LevelSelect", game)
    self.levels = LevelLoader.listLevels()
    self.selected = 1
end

function LevelSelect:draw()
    local width, height = love.graphics.getDimensions()
    local scale = UI.scale(width, height)
    local panelWidth = math.min(width - 40 * scale, 720 * scale)
    local rowHeight = 42 * scale
    local panelHeight = math.min(height - 48 * scale, (#self.levels * rowHeight) + 88 * scale)
    local panelX, panelY = (width - panelWidth) / 2, math.max(18 * scale, (height - panelHeight) / 2)

    UI.drawPanel(panelX, panelY, panelWidth, panelHeight)
    UI.setColor("text")
    UI.setFont(44, width, height)
    love.graphics.printf("SELECT LEVEL", panelX, panelY + 10 * scale, panelWidth, "center")
    UI.drawDivider(panelX + 18 * scale, panelY + 59 * scale, panelWidth - 36 * scale)

    local rowY = panelY + 68 * scale
    for index, level in ipairs(self.levels) do
        local label = level.name or string.format("lvl_%d.txt", level.number)
        local y = rowY + (index - 1) * rowHeight
        if index == self.selected then
            UI.drawSelection(panelX + 10 * scale, y + 2 * scale, panelWidth - 20 * scale, 38 * scale)
        end
        UI.setColor(index == self.selected and "accent" or "text")
        UI.setFont(29, width, height)
        local textY = y + (rowHeight - love.graphics.getFont():getHeight()) / 2
        local number = string.format("%02d", index)
        love.graphics.print((index == self.selected and "> " or "  ") .. number .. "  /  " .. label,
            panelX + 22 * scale, textY - 2)

        local markerX = panelX + panelWidth - 26 * scale
        local markerY = y + rowHeight / 2
        local markerRadius = 8 * scale
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("fill", markerX, markerY, markerRadius + 2 * scale)
        if self.game.levelProgress:isCompleted(level.path) then
            UI.setColor("accent")
            love.graphics.circle("fill", markerX, markerY, markerRadius)
            UI.setColor("text")
            love.graphics.setLineWidth(2 * scale)
            love.graphics.circle("line", markerX, markerY, markerRadius)
        else
            UI.setColor("text", index == self.selected and 1 or 0.7)
            love.graphics.setLineWidth(2 * scale)
            love.graphics.circle("line", markerX, markerY, markerRadius)
        end
    end
    self:drawChildren(nil, self)
end

function LevelSelect:keypressed(key)
    if Keymap.matches("cancel", key) then
        self.game.audio:play("uiClick")
        self.game.scenes:switch("menu")
    elseif Keymap.matches("menuUp", key) then
        self.selected = (self.selected - 2) % #self.levels + 1
        self.game.audio:play("uiClick")
    elseif Keymap.matches("menuDown", key) then
        self.selected = self.selected % #self.levels + 1
        self.game.audio:play("uiClick")
    elseif Keymap.matches("confirm", key) then
        if self.levels[self.selected] then
            self.game.audio:play("uiClick")
            self.game.scenes:switch("playing", self.selected)
        end
    end
end

return LevelSelect
