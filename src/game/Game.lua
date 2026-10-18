local SceneManager = require("src.core.SceneManager")
local Assets = require("src.game.Assets")
local CRT = require("src.rendering.CRT")
local MainMenu = require("src.screens.MainMenu")
local LevelSelect = require("src.screens.LevelSelect")
local Playing = require("src.screens.Playing")

local Game = {}
Game.__index = Game

function Game.new()
    local self = setmetatable({}, Game)
    self.assets = Assets.new()
    self.scenes = SceneManager(self)
    self.crt = CRT()
    self.scenes:register("menu", MainMenu.new)
    self.scenes:register("levels", LevelSelect.new)
    self.scenes:register("playing", Playing.new)
    self.scenes:switch("levels")
    return self
end

function Game:update(dt) self.scenes:update(dt) end
function Game:draw() self.crt:draw(function() self.scenes:draw() end) end
function Game:keypressed(key) self.scenes:keypressed(key) end
function Game:resize(width, height)
    self.crt:resize(width, height)
    self.scenes:resize(width, height)
end

return Game
