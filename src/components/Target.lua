local Component = require("src.core.Component")

local Target = Component:extend()
Target.componentName = "Target"

function Target:init()
    Component.init(self)
end

return Target
