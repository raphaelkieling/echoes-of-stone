local Class = require("src.core.Class")

local ActionHistory = Class:extend()

function ActionHistory:init()
    self.actions = {}
end

function ActionHistory:record(snapshots)
    if #snapshots > 0 then
        self.actions[#self.actions + 1] = snapshots
    end
end

function ActionHistory:undo()
    local snapshots = table.remove(self.actions)
    if not snapshots then
        return false
    end
    for _, snapshot in ipairs(snapshots) do
        snapshot.object:getComponent("Transform"):restore(snapshot)
        local player = snapshot.object:getComponent("Player")
        local stateMachine = player and player:getStateMachine()
        if stateMachine then
            stateMachine:change(#snapshots > 1 and "pushing" or "walking")
        end
    end
    return true
end

function ActionHistory:clear()
    self.actions = {}
end

return ActionHistory
