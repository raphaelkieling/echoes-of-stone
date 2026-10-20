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
    local rowHeight = 52 * scale
    local panelHeight = math.min(height - 80 * scale, (#self.levels * rowHeight) + 112 * scale)
    local panelX, panelY = (width - panelWidth) / 2, math.max(30 * scale, (height - panelHeight) / 2)

    UI.drawPanel(panelX, panelY, panelWidth, panelHeight)
    UI.setColor("text")
    UI.setFont(50, width, height)
    love.graphics.printf("SELECT LEVEL", panelX, panelY + 17 * scale, panelWidth, "center")
    UI.drawDivider(panelX + 24 * scale, panelY + 78 * scale, panelWidth - 48 * scale)

    local rowY = panelY + 91 * scale
    for index, level in ipairs(self.levels) do
        local label = level.name or string.format("lvl_%d.txt", level.number)
        local y = rowY + (index - 1) * rowHeight
        if index == self.selected then
            UI.drawSelection(panelX + 14 * scale, y - 4 * scale, panelWidth - 28 * scale, 44 * scale)
        end
        UI.setColor(index == self.selected and "accent" or "text")
        UI.setFont(31, width, height)
        local number = string.format("%02d", index)
        love.graphics.print((index == self.selected and "> " or "  ") .. number .. "  /  " .. label,
            panelX + 32 * scale, y)

        local markerX = panelX + panelWidth - 34 * scale
        local markerY = y + 15 * scale
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
