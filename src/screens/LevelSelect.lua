local LevelLoader = require("src.game.LevelLoader")
local Keymap = require("src.settings.Keymap")
local Fonts = require("src.ui.Fonts")

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
    local width = love.graphics.getWidth()
    love.graphics.setColor(0.93, 0.93, 0.9, 1)
    Fonts.set(42)
    love.graphics.printf("SELECT LEVEL", 0, 32, width, "center")
    Fonts.set(30)
    for index, level in ipairs(self.levels) do
        local label = level.name or string.format("lvl_%d.txt", level.number)
        love.graphics.print((index == self.selected and "> " or "  ") .. label, 40, 96 + (index - 1) * 44)
    end
    Fonts.set(21)
    love.graphics.print("Up/Down: select   Enter: play   Esc: back", 24, love.graphics.getHeight() - 36)
end

function LevelSelect:keypressed(key)
    if Keymap.matches("cancel", key) then
        self.game.scenes:switch("menu")
    elseif Keymap.matches("menuUp", key) then
        self.selected = (self.selected - 2) % #self.levels + 1
    elseif Keymap.matches("menuDown", key) then
        self.selected = self.selected % #self.levels + 1
    elseif Keymap.matches("confirm", key) then
        if self.levels[self.selected] then
            self.game.scenes:switch("playing", self.selected)
        end
    end
end

return LevelSelect
