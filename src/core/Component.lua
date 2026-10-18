local Class = require("src.core.Class")

local Component = Class:extend()
Component.componentName = "Component"

function Component:init()
    self.owner = nil
end

function Component:onAttach(_owner) end
function Component:update(_dt) end
function Component:draw(_context) end

return Component
