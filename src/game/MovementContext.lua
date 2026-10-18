local MovementContext = {}
MovementContext.__index = MovementContext

local function isPlayer(object)
    return object:hasComponent("Player")
end

function MovementContext.new(board)
    local self = setmetatable({
        board = board,
        positions = {},
        resolving = {},
        forced = {},
    }, MovementContext)

    for _, object in ipairs(board.objects) do
        if object:hasComponent("InteractiveObject") then
            local transform = object:getComponent("Transform")
            self.positions[object] = {x = transform.gridX, y = transform.gridY}
        end
    end
    return self
end

function MovementContext:position(object)
    return self.positions[object]
end

function MovementContext:canWalk(x, y)
    return self.board:canWalk(x, y)
end

function MovementContext:objectAt(x, y, except)
    for _, object in ipairs(self.board.objects) do
        if object ~= except and object:hasComponent("InteractiveObject") then
            local position = self.positions[object]
            if position.x == x and position.y == y then return object end
        end
    end
end

function MovementContext:moveObject(object, x, y)
    self.positions[object] = {x = x, y = y}
end

function MovementContext:enter(actor, x, y)
    if not self:canWalk(x, y) or self:objectAt(x, y, actor) then return false end
    self:moveObject(actor, x, y)
    return true
end

function MovementContext:rayTarget(startX, startY, direction, actor)
    local x, y = startX, startY
    while self:canWalk(x, y) do
        local target = self:objectAt(x, y, actor)
        if target then return target end
        x, y = x + direction.x, y + direction.y
    end
end

function MovementContext:chainAt(firstX, firstY, direction, actor)
    local chain = {}
    local x, y = firstX, firstY
    while self:canWalk(x, y) do
        local object = self:objectAt(x, y, actor)
        if not object then return chain end
        chain[#chain + 1] = object
        x, y = x + direction.x, y + direction.y
    end
end

function MovementContext:attempt(actor, direction, forced)
    if self.resolving[actor]
        or not ((math.abs(direction.x) == 1 and direction.y == 0)
            or (math.abs(direction.y) == 1 and direction.x == 0)) then
        return false
    end

    self.resolving[actor] = true
    if forced then self.forced[actor] = true end

    local current = self:position(actor)
    local destination = {x = current.x + direction.x, y = current.y + direction.y}
    local moved = false
    if self:canWalk(destination.x, destination.y) then
        local target = self:objectAt(destination.x, destination.y, actor)
        if target and isPlayer(target) then
            local pushedMoved = self:attempt(target, direction, true)
            local actorEntered = self:enter(actor, destination.x, destination.y)
            moved = pushedMoved or actorEntered
        else
            local characterClass = actor:getComponent("CharacterClass").behavior
            moved = characterClass:move(self, actor, direction, destination)
        end
    end

    self.resolving[actor] = nil
    return moved
end

function MovementContext:walkOrPush(actor, direction, destination, maxDistance)
    local chain = self:chainAt(destination.x, destination.y, direction, actor)
    if not chain then return false end

    local forcedAny = false
    for index = #chain, 1, -1 do
        local pushed = chain[index]
        if isPlayer(pushed) and not self.forced[pushed] then
            local before = self:position(pushed)
            local beforeX, beforeY = before.x, before.y
            self:attempt(pushed, direction, true)
            local after = self:position(pushed)
            forcedAny = forcedAny or beforeX ~= after.x or beforeY ~= after.y
        end
    end

    local first = self:objectAt(destination.x, destination.y, actor)
    if not first then return self:enter(actor, destination.x, destination.y) or forcedAny end

    local currentChain = self:chainAt(destination.x, destination.y, direction, actor)
    if not currentChain then return forcedAny end
    for _, object in ipairs(currentChain) do
        if isPlayer(object) then return forcedAny end
    end

    local last = self:position(currentChain[#currentChain])
    local distance = 0
    while true do
        local x = last.x + direction.x * (distance + 1)
        local y = last.y + direction.y * (distance + 1)
        if not self:canWalk(x, y) or self:objectAt(x, y, actor) then break end
        distance = distance + 1
    end
    if maxDistance ~= "unlimited" then distance = math.min(distance, maxDistance) end
    if distance == 0 then return forcedAny end

    for index = #currentChain, 1, -1 do
        local object = currentChain[index]
        local position = self:position(object)
        self:moveObject(object, position.x + direction.x * distance, position.y + direction.y * distance)
    end

    if not self:objectAt(destination.x, destination.y, actor) then
        self:moveObject(actor, destination.x, destination.y)
        return true
    end
    return forcedAny
end

function MovementContext:swapWithFirstInRay(actor, direction, destination)
    local target = self:rayTarget(destination.x, destination.y, direction, actor)
    if not target then return self:enter(actor, destination.x, destination.y) end
    local actorPosition = self:position(actor)
    local targetPosition = self:position(target)
    self:moveObject(target, actorPosition.x, actorPosition.y)
    self:moveObject(actor, targetPosition.x, targetPosition.y)
    return true
end

function MovementContext:pushFirstInRay(actor, direction, destination)
    local target = self:rayTarget(destination.x, destination.y, direction, actor)
    if target then
        local targetPosition = self:position(target)
        local beyondX, beyondY = targetPosition.x + direction.x, targetPosition.y + direction.y
        if not self:canWalk(beyondX, beyondY) or self:objectAt(beyondX, beyondY, actor) then return false end
        if isPlayer(target) then
            if not self:attempt(target, direction, true) then return false end
        else
            self:moveObject(target, beyondX, beyondY)
        end
    end
    return self:enter(actor, destination.x, destination.y)
end

function MovementContext:pullFirstInRay(actor, direction, destination)
    local target = self:rayTarget(destination.x, destination.y, direction, actor)
    if target then
        local targetPosition = self:position(target)
        if targetPosition.x == destination.x and targetPosition.y == destination.y then return false end
        local recoilX = targetPosition.x - direction.x
        local recoilY = targetPosition.y - direction.y
        if recoilX == destination.x and recoilY == destination.y
            or not self:canWalk(recoilX, recoilY)
            or self:objectAt(recoilX, recoilY, actor) then
            return false
        end
        if isPlayer(target) then
            if not self:attempt(target, {x = -direction.x, y = -direction.y}, true) then return false end
        else
            self:moveObject(target, recoilX, recoilY)
        end
    end
    return self:enter(actor, destination.x, destination.y)
end

function MovementContext:changedPositions()
    local changes = {}
    for _, object in ipairs(self.board.objects) do
        local after = self.positions[object]
        if after then
            local transform = object:getComponent("Transform")
            if transform.gridX ~= after.x or transform.gridY ~= after.y then
                changes[#changes + 1] = {
                    object = object,
                    fromX = transform.gridX,
                    fromY = transform.gridY,
                    x = transform.x,
                    y = transform.y,
                    toX = after.x,
                    toY = after.y,
                }
            end
        end
    end
    return changes
end

return MovementContext
