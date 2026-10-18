local MovementContext = {}
MovementContext.__index = MovementContext

function MovementContext.new(board)
    local self = setmetatable({
        board = board,
        positions = {},
        blockedObjects = {},
        blockedObjectSet = {},
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

function MovementContext:markBlocked(object)
    if not object or self.blockedObjectSet[object] then return end
    self.blockedObjectSet[object] = true
    self.blockedObjects[#self.blockedObjects + 1] = object
end

function MovementContext:enter(actor, x, y)
    if not self:canWalk(x, y) then return false end
    local blocker = self:objectAt(x, y, actor)
    if blocker then
        self:markBlocked(blocker)
        return false
    end
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
    return chain
end

function MovementContext:attempt(actor, direction)
    if not ((math.abs(direction.x) == 1 and direction.y == 0)
        or (math.abs(direction.y) == 1 and direction.x == 0)) then
        return false
    end

    local current = self:position(actor)
    local destination = {x = current.x + direction.x, y = current.y + direction.y}
    if self:canWalk(destination.x, destination.y) then
        local characterClass = actor:getComponent("CharacterClass").behavior
        return characterClass:move(self, actor, direction, destination)
    end
    return false
end

function MovementContext:walkOrPush(actor, direction, destination, maxDistance)
    local first = self:objectAt(destination.x, destination.y, actor)
    if not first then return self:enter(actor, destination.x, destination.y) end

    local currentChain = self:chainAt(destination.x, destination.y, direction, actor)
    local last = self:position(currentChain[#currentChain])
    local distance = 0
    while true do
        local x = last.x + direction.x * (distance + 1)
        local y = last.y + direction.y * (distance + 1)
        if not self:canWalk(x, y) or self:objectAt(x, y, actor) then break end
        distance = distance + 1
    end
    if maxDistance ~= "unlimited" then distance = math.min(distance, maxDistance) end
    if distance == 0 then
        self:markBlocked(currentChain[#currentChain])
        return false
    end

    for index = #currentChain, 1, -1 do
        local object = currentChain[index]
        local position = self:position(object)
        self:moveObject(object, position.x + direction.x * distance, position.y + direction.y * distance)
    end

    if not self:objectAt(destination.x, destination.y, actor) then
        self:moveObject(actor, destination.x, destination.y)
        return true
    end
    return false
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
        if not self:canWalk(beyondX, beyondY) then
            self:markBlocked(target)
            return self:enter(actor, destination.x, destination.y)
        end
        local blocker = self:objectAt(beyondX, beyondY, actor)
        if blocker then
            self:markBlocked(blocker)
            self:markBlocked(target)
            return self:enter(actor, destination.x, destination.y)
        end
        self:moveObject(target, beyondX, beyondY)
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
            self:markBlocked(target)
            return false
        end
        self:moveObject(target, recoilX, recoilY)
    end
    return self:enter(actor, destination.x, destination.y)
end

function MovementContext:moveAuraAndEnter(actor, direction, destination, radius)
    local center = self:position(actor)
    local affected = {}
    for _, object in ipairs(self.board.objects) do
        if object ~= actor and object:hasComponent("InteractiveObject") then
            local position = self:position(object)
            if math.abs(position.x - center.x) <= radius and math.abs(position.y - center.y) <= radius then
                affected[#affected + 1] = object
            end
        end
    end

    -- Move the leading objects first so a contiguous group can advance together.
    table.sort(affected, function(a, b)
        local aPosition, bPosition = self:position(a), self:position(b)
        local aProjection = aPosition.x * direction.x + aPosition.y * direction.y
        local bProjection = bPosition.x * direction.x + bPosition.y * direction.y
        return aProjection > bProjection
    end)

    local trailingObjects = {}
    for _, object in ipairs(affected) do
        local position = self:position(object)
        local nextX, nextY = position.x + direction.x, position.y + direction.y
        if nextX == center.x and nextY == center.y then
            trailingObjects[#trailingObjects + 1] = object
        else
            local blocker = self:objectAt(nextX, nextY, object)
            local canMove = self:canWalk(nextX, nextY)
            if canMove and not blocker then
                self:moveObject(object, nextX, nextY)
            else
                self:markBlocked(blocker or object)
            end
        end
    end

    local actorMoved = self:enter(actor, destination.x, destination.y)
    for _, object in ipairs(trailingObjects) do
        if actorMoved and self:canWalk(center.x, center.y) and not self:objectAt(center.x, center.y, actor) then
            self:moveObject(object, center.x, center.y)
        else
            self:markBlocked(object)
        end
    end
    return actorMoved
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
