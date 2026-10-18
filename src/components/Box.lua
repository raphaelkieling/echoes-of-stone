local Component = require("src.core.Component")

local Box = Component:extend()
Box.componentName = "Box"

function Box:init()
    Component.init(self)
end

return Box
