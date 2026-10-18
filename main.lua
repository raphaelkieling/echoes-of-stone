local Game = require("src.game.Game")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setBackgroundColor(0.045, 0.04, 0.032, 1)
    love.game = Game.new()
end

function love.update(dt) love.game:update(dt) end
function love.draw() love.game:draw() end
function love.keypressed(key, scancode, isrepeat) love.game:keypressed(key, scancode, isrepeat) end
function love.textinput(text) love.game:textinput(text) end
function love.resize(width, height) love.game:resize(width, height) end
function love.mousepressed(x, y, button, isTouch, presses) love.game:mousepressed(x, y, button, isTouch, presses) end
function love.mousemoved(x, y, dx, dy, isTouch) love.game:mousemoved(x, y, dx, dy, isTouch) end
function love.mousereleased(x, y, button, isTouch, presses) love.game:mousereleased(x, y, button, isTouch, presses) end
function love.touchpressed(id, x, y, dx, dy, pressure) love.game:touchpressed(id, x, y, dx, dy, pressure) end
function love.touchmoved(id, x, y, dx, dy, pressure) love.game:touchmoved(id, x, y, dx, dy, pressure) end
function love.touchreleased(id, x, y, dx, dy, pressure) love.game:touchreleased(id, x, y, dx, dy, pressure) end
function love.quit()
	if love.game and love.game.events then love.game.events:emit("game.closed", {}) end
end
