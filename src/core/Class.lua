local Class = {}
Class.__index = Class

function Class:new(...)
    local instance = setmetatable({}, self)
    if instance.init then
        instance:init(...)
    end
    return instance
end

function Class:extend()
    local subclass = {}
    subclass.__index = subclass
    setmetatable(subclass, {
        __index = self,
        __call = function(class, ...)
            return class:new(...)
        end,
    })
    return subclass
end

return Class
