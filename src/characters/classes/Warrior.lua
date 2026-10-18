local CharacterClass = require("src.characters.CharacterClass")

local Warrior = CharacterClass:extend()
Warrior.id = "warrior"
Warrior.name = "Warrior"
Warrior.sprite = {x = 4, y = 1, scale = 2.25}

function Warrior:move(context, actor, direction, destination)
    return context:walkOrPush(actor, direction, destination, "unlimited")
end

return Warrior
