local CharacterClass = require("src.characters.CharacterClass")

local Dwarf = CharacterClass:extend()
Dwarf.id = "dwarf"
Dwarf.name = "Dwarf"
Dwarf.sprite = {x = 0, y = 0, scale = 2.25}

return Dwarf
