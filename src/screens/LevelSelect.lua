local LevelLoader = require("src.game.LevelLoader")
local Keymap = require("src.settings.Keymap")
local UI = require("src.ui.Theme")

local LevelSelect = {}
LevelSelect.__index = LevelSelect

function LevelSelect.new(game)
    return setmetatable({
        game = game,
        levels = LevelLoader.listLevels(),
        selected = 1,
    }, LevelSelect)
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
    end
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
