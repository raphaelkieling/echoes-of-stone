local MainMenu = {}
MainMenu.__index = MainMenu

function MainMenu.new(game)
    return setmetatable({game = game, selected = 1, options = {"Start", "Quit"}}, MainMenu)
end

function MainMenu:draw()
    local width, height = love.graphics.getDimensions()
    love.graphics.setColor(0.93, 0.93, 0.9, 1)
    love.graphics.printf("SOKOBAN", 0, height * 0.25, width, "center")
    for index, label in ipairs(self.options) do
        local y = height - 120 + (index - 1) * 32
        love.graphics.printf((index == self.selected and "> " or "  ") .. label, 24, y, 180, "left")
    end
end

function MainMenu:keypressed(key)
    if key == "up" or key == "w" or key == "down" or key == "s" then
        self.selected = self.selected == 1 and 2 or 1
    elseif key == "return" or key == "kpenter" then
        if self.selected == 1 then
            self.game.scenes:switch("levels")
        else
            love.event.quit()
        end
    end
end

return MainMenu
