local CharacterMovement = {}

local DIRECTION_KEYS = {
    {x = 0, y = -1},
    {x = 0, y = 1},
    {x = -1, y = 0},
    {x = 1, y = 0},
}

local function isCardinalDirection(direction)
    for _, cardinal in ipairs(DIRECTION_KEYS) do
        if direction.x == cardinal.x and direction.y == cardinal.y then
            return true
        end
    end
    return false
end

local function playerClass(object)
    local player = object:getComponent("Player")
    return player and player.className or nil
end

local function position(state, object)
    return state.positions[object]
end

local function objectAt(state, x, y, except)
    for _, object in ipairs(state.board.objects) do
        if object ~= except and object:hasComponent("InteractiveObject") then
            local objectPosition = position(state, object)
            if objectPosition.x == x and objectPosition.y == y then
                return object
            end
        end
    end
    return nil
end

local function canOccupy(state, x, y)
    return state.board:canWalk(x, y)
end

local function rayTarget(state, startX, startY, direction, actor)
    local x, y = startX, startY
    while canOccupy(state, x, y) do
        local target = objectAt(state, x, y, actor)
        if target then
            return target
        end
        x, y = x + direction.x, y + direction.y
    end
    return nil
end

local attempt

local function moveObject(state, object, x, y)
    state.positions[object] = {x = x, y = y}
end

local function tryEnter(state, actor, x, y)
    if not canOccupy(state, x, y) or objectAt(state, x, y, actor) then
        return false
    end
    moveObject(state, actor, x, y)
    return true
end

local function getChain(state, firstX, firstY, direction, actor)
    local chain = {}
    local x, y = firstX, firstY
    while canOccupy(state, x, y) do
        local object = objectAt(state, x, y, actor)
        if not object then
            return chain
        end
        chain[#chain + 1] = object
        x, y = x + direction.x, y + direction.y
    end
    return nil
end

local function pushableChain(state, actor, destinationX, destinationY, direction, chain)
    local actorClass = playerClass(actor)
    local actorPosition = position(state, actor)

    -- First let characters in the pushed chain perform their own skill, farthest
    -- first. This is a forced move in the same direction, not a generic shove.
    local forcedAny = false
    for index = #chain, 1, -1 do
        local pushed = chain[index]
        if playerClass(pushed) and not state.forced[pushed] then
            local beforeX, beforeY = position(state, pushed).x, position(state, pushed).y
            attempt(state, pushed, direction, true)
            local after = position(state, pushed)
            forcedAny = forcedAny or beforeX ~= after.x or beforeY ~= after.y
        end
    end

    local currentFirst = objectAt(state, destinationX, destinationY, actor)
    if not currentFirst then
        return tryEnter(state, actor, destinationX, destinationY) or forcedAny
    end

    local currentChain = getChain(state, destinationX, destinationY, direction, actor)
    if not currentChain then
        return forcedAny
    end
    for _, object in ipairs(currentChain) do
        -- A character that couldn't clear the chain is never pushed like a crate.
        if playerClass(object) then
            return forcedAny
        end
    end

    local last = position(state, currentChain[#currentChain])
    local maxDistance = 0
    while canOccupy(
        state,
        last.x + direction.x * (maxDistance + 1),
        last.y + direction.y * (maxDistance + 1)
    ) and not objectAt(
        state,
        last.x + direction.x * (maxDistance + 1),
        last.y + direction.y * (maxDistance + 1),
        actor
    ) do
        maxDistance = maxDistance + 1
    end

    local distance = actorClass == "warrior" and maxDistance or 1
    if distance <= 0 then
        return forcedAny
    end

    -- Validate the whole displacement before applying it, preserving every box
    -- if a wall, map edge, or another object blocks the chain.
    for step = 1, distance do
        local x = last.x + direction.x * step
        local y = last.y + direction.y * step
        if not canOccupy(state, x, y) then
            return forcedAny
        end
    end
    for index = #currentChain, 1, -1 do
        local object = currentChain[index]
        local current = position(state, object)
        moveObject(state, object, current.x + direction.x * distance, current.y + direction.y * distance)
    end

    -- The pushed wizard can leave a box on the pusher's cell. The ability still
    -- commits, but the pusher only advances if its destination is now free.
    if not objectAt(state, destinationX, destinationY, actor) then
        moveObject(state, actor, destinationX, destinationY)
        return true
    end
    return forcedAny
end

local function tryNormalPush(state, actor, direction, destinationX, destinationY)
    local chain = getChain(state, destinationX, destinationY, direction, actor)
    if not chain then
        return false
    end
    return pushableChain(state, actor, destinationX, destinationY, direction, chain)
end

local function tryWizard(state, actor, direction, destinationX, destinationY)
    local target = rayTarget(state, destinationX, destinationY, direction, actor)
    if target then
        local actorPosition = position(state, actor)
        local targetPosition = position(state, target)
        moveObject(state, target, actorPosition.x, actorPosition.y)
        moveObject(state, actor, targetPosition.x, targetPosition.y)
        return true
    end
    return tryEnter(state, actor, destinationX, destinationY)
end

local function tryTelekinetic(state, actor, direction, destinationX, destinationY)
    local target = rayTarget(state, destinationX, destinationY, direction, actor)
    if target then
        local targetPosition = position(state, target)
        local beyondX = targetPosition.x + direction.x
        local beyondY = targetPosition.y + direction.y
        if not canOccupy(state, beyondX, beyondY) or objectAt(state, beyondX, beyondY, actor) then
            return false
        end
        if playerClass(target) then
            if not attempt(state, target, direction, true) then
                return false
            end
        else
            moveObject(state, target, beyondX, beyondY)
        end
    end
    return tryEnter(state, actor, destinationX, destinationY)
end

local function trySorcerer(state, actor, direction, destinationX, destinationY)
    local target = rayTarget(state, destinationX, destinationY, direction, actor)
    if target then
        local targetPosition = position(state, target)
        if targetPosition.x == destinationX and targetPosition.y == destinationY then
            return false
        end
        local recoilX = targetPosition.x - direction.x
        local recoilY = targetPosition.y - direction.y
        if recoilX == destinationX and recoilY == destinationY then
            return false
        end
        if not canOccupy(state, recoilX, recoilY) or objectAt(state, recoilX, recoilY, actor) then
            return false
        end
        if playerClass(target) then
            if not attempt(state, target, {x = -direction.x, y = -direction.y}, true) then
                return false
            end
        else
            moveObject(state, target, recoilX, recoilY)
        end
    end
    return tryEnter(state, actor, destinationX, destinationY)
end

attempt = function(state, actor, direction, forced)
    if state.resolving[actor] or not isCardinalDirection(direction) then
        return false
    end
    state.resolving[actor] = true
    if forced then
        state.forced[actor] = true
    end

    local actorPosition = position(state, actor)
    local destinationX = actorPosition.x + direction.x
    local destinationY = actorPosition.y + direction.y
    local moved

    if not canOccupy(state, destinationX, destinationY) then
        moved = false
    else
        local target = objectAt(state, destinationX, destinationY, actor)
        if target and playerClass(target) then
            -- The pushed player uses the exact same class rules as a keyboard
            -- move; the initiator advances only if the cell is actually clear.
            local forcedMoved = attempt(state, target, direction, true)
            local entered = tryEnter(state, actor, destinationX, destinationY)
            moved = forcedMoved or entered
        else
            local className = playerClass(actor)
            if className == "wizard" then
                moved = tryWizard(state, actor, direction, destinationX, destinationY)
            elseif className == "telekinetic" then
                moved = tryTelekinetic(state, actor, direction, destinationX, destinationY)
            elseif className == "sorcerer" then
                moved = trySorcerer(state, actor, direction, destinationX, destinationY)
            elseif not target then
                moved = tryEnter(state, actor, destinationX, destinationY)
            else
                moved = tryNormalPush(state, actor, direction, destinationX, destinationY)
            end
        end
    end

    state.resolving[actor] = nil
    return moved
end

function CharacterMovement.move(board, actor, direction, history)
    if not board or not actor or not actor:hasComponent("Player") or not isCardinalDirection(direction) then
        return false
    end

    local state = {
        board = board,
        positions = {},
        resolving = {},
        forced = {},
    }
    local initial = {}
    for _, object in ipairs(board.objects) do
        if object:hasComponent("InteractiveObject") then
            local transform = object:getComponent("Transform")
            local objectPosition = {x = transform.gridX, y = transform.gridY}
            state.positions[object] = objectPosition
            initial[object] = {x = objectPosition.x, y = objectPosition.y}
        end
    end

    attempt(state, actor, direction, false)

    local snapshots = {}
    for _, object in ipairs(board.objects) do
        local before, after = initial[object], state.positions[object]
        if before and (before.x ~= after.x or before.y ~= after.y) then
            local transform = object:getComponent("Transform")
            snapshots[#snapshots + 1] = {
                object = object,
                gridX = before.x,
                gridY = before.y,
                x = transform.x,
                y = transform.y,
            }
        end
    end

    if #snapshots == 0 then
        return false
    end
    for _, snapshot in ipairs(snapshots) do
        local final = state.positions[snapshot.object]
        snapshot.object:getComponent("Transform"):moveTo(final.x, final.y)
    end
    if history then
        history:record(snapshots)
    end
    return true
end

return CharacterMovement
