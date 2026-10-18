local Fonts = require("src.ui.Fonts")

local Theme = {
    colors = {
        text = {0.91, 0.88, 0.78, 1},
        muted = {0.59, 0.56, 0.48, 1},
        accent = {0.79, 0.68, 0.43, 1},
        panel = {0.075, 0.068, 0.055, 0.96},
        selected = {0.20, 0.18, 0.13, 0.98},
    },
}

function Theme.scale(width, height)
    return math.max(0.75, math.min(width / 1280, height / 720, 1.4))
end

function Theme.setColor(name, alpha)
    local color = Theme.colors[name]
    love.graphics.setColor(color[1], color[2], color[3], alpha or color[4])
end

function Theme.setFont(size, width, height)
    Fonts.set(math.max(14, math.floor(size * Theme.scale(width, height))))
end

function Theme.drawPanel(x, y, width, height)
    love.graphics.push("all")
    Theme.setColor("panel")
    love.graphics.rectangle("fill", x, y, width, height)
    Theme.setColor("muted", 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x + 1, y + 1, width - 2, height - 2)
    love.graphics.pop()
end

function Theme.drawSelection(x, y, width, height)
    love.graphics.push("all")
    Theme.setColor("selected")
    love.graphics.rectangle("fill", x, y, width, height)
    Theme.setColor("accent")
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x + 1, y + 1, width - 2, height - 2)
    love.graphics.pop()
end

function Theme.drawDivider(x, y, width)
    love.graphics.push("all")
    Theme.setColor("muted", 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y, x + width, y)
    love.graphics.pop()
end

return Theme
