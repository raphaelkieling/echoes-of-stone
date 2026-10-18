local MovementContext = require("src.game.MovementContext")

local CharacterMovement = {}

local function isCardinalDirection(direction)
    return direction and ((math.abs(direction.x) == 1 and direction.y == 0)
        or (math.abs(direction.y) == 1 and direction.x == 0))
end

function CharacterMovement.move(board, actor, direction, history)
    if not board or not actor or not actor:hasComponent("Player")
        or not actor:hasComponent("CharacterClass") or not isCardinalDirection(direction) then
        return false
    end

    local context = MovementContext.new(board)
    context:attempt(actor, direction, false)
    local changes = context:changedPositions()
    if #changes == 0 then return false end

    local snapshots = {}
    for _, change in ipairs(changes) do
        change.object:getComponent("Transform"):moveTo(change.toX, change.toY)
        snapshots[#snapshots + 1] = {
            object = change.object,
            gridX = change.fromX,
            gridY = change.fromY,
            x = change.x,
            y = change.y,
        }
    end
    if history then history:record(snapshots) end
    return true
end

return CharacterMovement
