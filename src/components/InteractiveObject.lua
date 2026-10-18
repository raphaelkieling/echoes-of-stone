local Component = require("src.core.Component")

local InteractiveObject = Component:extend()
InteractiveObject.componentName = "InteractiveObject"

function InteractiveObject:init()
    Component.init(self)
end

return InteractiveObject
