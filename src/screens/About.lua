local Keymap = require("src.settings.Keymap")
local Scene = require("src.core.Scene")
local UI = require("src.ui.Theme")

local About = Scene:extend()

function About:init(game)
    Scene.init(self, "About", game)
end

function About:draw()
    local width, height = love.graphics.getDimensions()
    love.graphics.setColor(0.045, 0.04, 0.032, 1)
    love.graphics.rectangle("fill", 0, 0, width, height)
    local scale = UI.scale(width, height)
    local panelWidth = math.min(width - 40 * scale, 760 * scale)
    local panelHeight = math.min(height - 48 * scale, 520 * scale)
    local panelX, panelY = (width - panelWidth) / 2, (height - panelHeight) / 2
    UI.drawPanel(panelX, panelY, panelWidth, panelHeight)

    UI.setColor("text")
    UI.setFont(60, width, height)
    love.graphics.printf("ABOUT", panelX, panelY + 25 * scale, panelWidth, "center")
    UI.setColor("muted")
    UI.setFont(18, width, height)
    love.graphics.printf("ECHOES OF STONE  //  CREDITS", panelX, panelY + 88 * scale, panelWidth, "center")
    UI.drawDivider(panelX + 30 * scale, panelY + 120 * scale, panelWidth - 60 * scale)

    UI.setColor("accent")
    UI.setFont(27, width, height)
    love.graphics.printf("MADE WITH", panelX, panelY + 147 * scale, panelWidth, "center")
    UI.setColor("text")
    UI.setFont(31, width, height)
    love.graphics.printf("LOVE2D", panelX, panelY + 181 * scale, panelWidth, "center")

    UI.setColor("accent")
    UI.setFont(27, width, height)
    love.graphics.printf("ASSET CREDITS", panelX, panelY + 240 * scale, panelWidth, "center")
    UI.setColor("text")
    UI.setFont(25, width, height)
    love.graphics.printf("32 Rogues  /  Seth B.", panelX, panelY + 278 * scale, panelWidth, "center")
    UI.setColor("muted")
    UI.setFont(20, width, height)
    love.graphics.printf("sethbb.itch.io/32rogues", panelX, panelY + 311 * scale, panelWidth, "center")
    UI.setColor("text")
    UI.setFont(25, width, height)
    love.graphics.printf("Monogram  /  Data Goblin", panelX, panelY + 354 * scale, panelWidth, "center")
    UI.setColor("muted")
    UI.setFont(20, width, height)
    love.graphics.printf("datagoblin.itch.io/monogram", panelX, panelY + 387 * scale, panelWidth, "center")
    self:drawChildren(nil, self)
end

function About:keypressed(key)
    if Keymap.matches("cancel", key) or Keymap.matches("confirm", key) then
        self.game.audio:play("uiClick")
        self.game.scenes:switch("menu")
    end
end

return About
