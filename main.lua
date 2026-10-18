local Game = require("src.game.Game")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setBackgroundColor(0.035, 0.045, 0.065, 1)
    love.game = Game.new()
end

function love.update(dt) love.game:update(dt) end
function love.draw() love.game:draw() end
function love.keypressed(key) love.game:keypressed(key) end
function love.resize(width, height) love.game:resize(width, height) end
