local Component = require("src.core.Component")

local CharacterClass = Component:extend()
CharacterClass.componentName = "CharacterClass"

function CharacterClass:init(classObject)
    Component.init(self)
    assert(classObject and classObject.id and classObject.move, "invalid character class")
    self.behavior = classObject
end

function CharacterClass:set(classObject)
    assert(classObject and classObject.id and classObject.move, "invalid character class")
    self.behavior = classObject
end

function CharacterClass:getId()
    return self.behavior.id
end

return CharacterClass
