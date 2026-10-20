local Component = require("src.core.Component")

-- Marks an object as part of board interactions: it occupies a cell and can
-- be detected or moved by character abilities without depending on its type.
local InteractiveObject = Component:extend()
InteractiveObject.componentName = "InteractiveObject"

function InteractiveObject:init()
    Component.init(self)
end

return InteractiveObject
