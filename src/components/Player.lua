local Component = require("src.core.Component")

local Player = Component:extend()
Player.componentName = "Player"

Player.Classes = {
    DWARF = "dwarf",
    WIZARD = "wizard",
    WARRIOR = "warrior",
    TELEKINETIC = "telekinetic",
    SORCERER = "sorcerer",
}

function Player:init(className)
    Component.init(self)
    assert(className, "a player needs a character class")
    self.className = className
end

return Player
