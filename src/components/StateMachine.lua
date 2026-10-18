local Component = require("src.core.Component")

local StateMachine = Component:extend()
StateMachine.componentName = "StateMachine"

function StateMachine:init(states, initialState)
    Component.init(self)
    self.states = assert(states, "StateMachine needs a state registry")
    self.initialState = assert(initialState, "StateMachine needs an initial state")
    self.currentName = nil
    self.current = nil
end

function StateMachine:onAttach(owner)
    self.owner = owner
    self:change(self.initialState)
end

function StateMachine:change(name, data)
    local State = assert(self.states[name], "unknown state: " .. tostring(name))
    if self.current and self.currentName == name then return false end

    if self.current and self.current.exit then
        self.current:exit(data)
    end
    self.currentName = name
    self.current = State(self.owner, self)
    if self.current.enter then
        self.current:enter(data)
    end
    return true
end

function StateMachine:update(dt)
    if self.current and self.current.update then
        self.current:update(dt)
    end
end

function StateMachine:visualOffset()
    if self.current and self.current.visualOffset then
        return self.current:visualOffset()
    end
    return 0, 0, 0
end

return StateMachine
