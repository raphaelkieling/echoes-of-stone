local Component = require("src.core.Component")

local Floor = Component:extend()
Floor.componentName = "Floor"

function Floor:init()
    Component.init(self)
end

return Floor
