local MainMenu = {}
MainMenu.__index = MainMenu
local Keymap = require("src.settings.Keymap")
local UI = require("src.ui.Theme")

function MainMenu.new(game)
    return setmetatable({
        game = game,
        selected = 1,
        options = {"Start", "About", "Quit"},
    }, MainMenu)
end

function MainMenu:draw()
    local width, height = love.graphics.getDimensions()
    local scale = UI.scale(width, height)
    UI.setColor("text")
    UI.setFont(88, width, height)
    love.graphics.printf("ECHOES OF STONE", 0, height * 0.18, width, "center")
    local ruleWidth = math.min(width * 0.72, 900 * scale)
    UI.drawDivider((width - ruleWidth) / 2, height * 0.39, ruleWidth)

    local panelX, panelY = 44 * scale, height - 330 * scale
    local panelWidth, panelHeight = 360 * scale, 250 * scale
    UI.drawPanel(panelX, panelY, panelWidth, panelHeight)
    UI.setColor("accent")
    UI.setFont(23, width, height)
    love.graphics.print("MAIN MENU", panelX + 24 * scale, panelY + 17 * scale)
    UI.drawDivider(panelX + 20 * scale, panelY + 52 * scale, panelWidth - 40 * scale)

    local rowY = panelY + 67 * scale
    for index, label in ipairs(self.options) do
        local y = rowY + (index - 1) * 55 * scale
        if index == self.selected then
            UI.drawSelection(panelX + 14 * scale, y - 5 * scale, panelWidth - 28 * scale, 46 * scale)
        end
        UI.setColor(index == self.selected and "accent" or "text")
        UI.setFont(34, width, height)
        love.graphics.print((index == self.selected and "> " or "  ") .. label,
            panelX + 28 * scale, y)
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
