local Keymap = require("src.settings.Keymap")
local Fonts = require("src.ui.Fonts")

local About = {}
About.__index = About

function About.new(game)
    return setmetatable({game = game}, About)
end

function About:draw()
    local width, height = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, width, height)

    love.graphics.setColor(1, 1, 1, 1)
    Fonts.set(58)
    love.graphics.printf("ABOUT", 0, height * 0.13, width, "center")

    Fonts.set(28)
    love.graphics.printf("MADE WITH", 0, height * 0.32, width, "center")
    Fonts.set(24)
    love.graphics.printf("LOVE2D", 0, height * 0.39, width, "center")

    Fonts.set(28)
    love.graphics.printf("ASSETS", 0, height * 0.49, width, "center")
    Fonts.set(23)
    love.graphics.printf("32 Rogues - Seth B.", 0, height * 0.55, width, "center")
    Fonts.set(19)
    love.graphics.printf("https://sethbb.itch.io/32rogues", 0, height * 0.60, width, "center")
    Fonts.set(23)
    love.graphics.printf("Monogram - Data Goblin", 0, height * 0.66, width, "center")
    Fonts.set(19)
    love.graphics.printf("https://datagoblin.itch.io/monogram", 0, height * 0.71, width, "center")

    love.graphics.setColor(0.72, 0.72, 0.72, 1)
    Fonts.set(19)
    love.graphics.printf("Esc - back", 0, height - 48, width, "center")
end

function About:keypressed(key)
    if Keymap.matches("cancel", key) or Keymap.matches("confirm", key) then
        self.game.scenes:switch("menu")
    end
end

return About
