local Component = require("src.core.Component")

local Wall = Component:extend()
Wall.componentName = "Wall"

function Wall:init()
    Component.init(self)
end

return Wall
