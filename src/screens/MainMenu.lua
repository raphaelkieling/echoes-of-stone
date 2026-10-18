local MainMenu = {}
MainMenu.__index = MainMenu
local Keymap = require("src.settings.Keymap")

function MainMenu.new(game)
    return setmetatable({
        game = game,
        selected = 1,
        options = {"Start", "Quit"},
        titleFont = love.graphics.newFont(64),
        optionFont = love.graphics.newFont(22),
    }, MainMenu)
end

function MainMenu:draw()
    local width, height = love.graphics.getDimensions()
    love.graphics.setColor(0.93, 0.93, 0.9, 1)
    love.graphics.setFont(self.titleFont)
    love.graphics.printf("ECHOES OF STONE", 0, height * 0.2, width, "center")
    love.graphics.setFont(self.optionFont)
    for index, label in ipairs(self.options) do
        local y = height - 126 + (index - 1) * 42
        love.graphics.printf((index == self.selected and "> " or "  ") .. label, 24, y, 180, "left")
    end
end

function MainMenu:keypressed(key)
    if Keymap.matches("menuUp", key) or Keymap.matches("menuDown", key) then
        self.selected = self.selected == 1 and 2 or 1
    elseif Keymap.matches("confirm", key) then
        if self.selected == 1 then
            self.game.scenes:switch("levels")
        else
            love.event.quit()
        end
    end
end

return MainMenu
