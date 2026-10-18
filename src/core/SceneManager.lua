local Class = require("src.core.Class")

local SceneManager = Class:extend()

function SceneManager:init(game)
    self.game = game
    self.factories = {}
    self.current = nil
    self.currentName = nil
end

function SceneManager:register(name, factory)
    self.factories[name] = factory
end

function SceneManager:switch(name, ...)
    local factory = assert(self.factories[name], "unknown scene: " .. tostring(name))
    if self.current and self.current.leave then
        self.current:leave()
    end
    self.currentName = name
    self.current = factory(self.game)
    if self.current.enter then
        self.current:enter(...)
    end
end

function SceneManager:update(dt)
    if self.current and self.current.update then
        self.current:update(dt)
    end
end

function SceneManager:draw()
    if self.current and self.current.draw then
        self.current:draw()
    end
end

function SceneManager:keypressed(key)
    if self.current and self.current.keypressed then
        self.current:keypressed(key)
    end
end

function SceneManager:resize(width, height)
    if self.current and self.current.resize then
        self.current:resize(width, height)
    end
end

return SceneManager
