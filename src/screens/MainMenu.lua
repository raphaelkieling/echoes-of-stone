local MainMenu = {}
MainMenu.__index = MainMenu
local Keymap = require("src.settings.Keymap")
local Fonts = require("src.ui.Fonts")

function MainMenu.new(game)
    return setmetatable({
        game = game,
        selected = 1,
        options = {"Start", "About", "Quit"},
    }, MainMenu)
end

function MainMenu:draw()
    local width, height = love.graphics.getDimensions()
    love.graphics.setColor(0.93, 0.93, 0.9, 1)
    Fonts.set(80)
    love.graphics.printf("ECHOES OF STONE", 0, height * 0.2, width, "center")
    Fonts.set(30)
    for index, label in ipairs(self.options) do
        local y = height - 190 + (index - 1) * 54
        love.graphics.printf((index == self.selected and "> " or "  ") .. label, 24, y, 180, "left")
    end
end

function MainMenu:keypressed(key)
    if Keymap.matches("menuUp", key) or Keymap.matches("menuDown", key) then
        if Keymap.matches("menuUp", key) then
            self.selected = (self.selected - 2) % #self.options + 1
        else
            self.selected = self.selected % #self.options + 1
        end
    elseif Keymap.matches("confirm", key) then
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
