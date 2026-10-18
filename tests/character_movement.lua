local Board = require("src.game.Board")
local GameObject = require("src.core.GameObject")
local Transform = require("src.components.Transform")
local InteractiveObject = require("src.components.InteractiveObject")
local Player = require("src.components.Player")
local CharacterClasses = require("src.characters.Classes")
local Box = require("src.components.Box")
local CharacterMovement = require("src.game.CharacterMovement")
local ActionHistory = require("src.game.ActionHistory")

local tests = {}

local function makeBoard(xStart, xEnd, y, walls)
    local board = Board(nil, xEnd - xStart + 1, 1)
    for x = xStart, xEnd do
        board:setCell(x, y, {walkable = not (walls and walls[x])})
    end
    return board
end

local function spawnPlayer(board, x, y, classId)
    local player = GameObject("test-player")
    player:addComponent(Transform(x, y, 64, 3))
    player:addComponent(InteractiveObject())
    local playerComponent = Player()
    player:addComponent(playerComponent)
    playerComponent:setClass(CharacterClasses.create(classId))
    board:addObject(player)
    return player
end

local function spawnBox(board, x, y)
    local box = GameObject("test-box")
    box:addComponent(Transform(x, y, 64, 2))
    box:addComponent(InteractiveObject())
    box:addComponent(Box())
    board:addObject(box)
    return box
end

local function pos(object)
    local transform = object:getComponent("Transform")
    return transform.gridX, transform.gridY
end

local function assertPosition(object, x, y)
    local actualX, actualY = pos(object)
    assert(actualX == x and actualY == y,
        string.format("expected (%d,%d), got (%d,%d)", x, y, actualX, actualY))
end

local function run(board, player, direction)
    return CharacterMovement.move(board, player, direction, ActionHistory())
end

function tests.dwarf_walks_one_tile()
    local board = makeBoard(0, 4, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    assert(run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 2, 0)
end

function tests.dwarf_pushes_one_box_one_tile()
    local board = makeBoard(0, 4, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local box = spawnBox(board, 2, 0)
    assert(run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 2, 0)
    assertPosition(box, 3, 0)
end

function tests.dwarf_pushes_a_contiguous_chain()
    local board = makeBoard(0, 5, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local first = spawnBox(board, 2, 0)
    local second = spawnBox(board, 3, 0)
    assert(run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 2, 0)
    assertPosition(first, 3, 0)
    assertPosition(second, 4, 0)
end

function tests.dwarf_cannot_push_into_wall_or_off_map()
    local board = makeBoard(0, 3, 0, {[3] = true})
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local box = spawnBox(board, 2, 0)
    assert(not run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 1, 0)
    assertPosition(box, 2, 0)
end

function tests.wizard_swaps_with_first_object_in_ray()
    local board = makeBoard(0, 6, 0)
    local wizard = spawnPlayer(board, 1, 0, Player.Classes.WIZARD)
    local box = spawnBox(board, 4, 0)
    assert(run(board, wizard, {x = 1, y = 0}))
    assertPosition(wizard, 4, 0)
    assertPosition(box, 1, 0)
end

function tests.player_can_change_class_and_use_the_new_ability()
    local board = makeBoard(0, 6, 0)
    local player = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local box = spawnBox(board, 4, 0)
    player:getComponent("Player"):setClass(Player.Classes.WIZARD)
    assert(run(board, player, {x = 1, y = 0}))
    assertPosition(player, 4, 0)
    assertPosition(box, 1, 0)
end

function tests.wizard_walks_when_ray_is_clear()
    local board = makeBoard(0, 4, 0)
    local wizard = spawnPlayer(board, 1, 0, Player.Classes.WIZARD)
    assert(run(board, wizard, {x = 1, y = 0}))
    assertPosition(wizard, 2, 0)
end

function tests.wizard_does_not_see_through_a_wall()
    local board = makeBoard(0, 5, 0, {[3] = true})
    local wizard = spawnPlayer(board, 1, 0, Player.Classes.WIZARD)
    local box = spawnBox(board, 4, 0)
    assert(run(board, wizard, {x = 1, y = 0}))
    assertPosition(wizard, 2, 0)
    assertPosition(box, 4, 0)
end

function tests.warrior_pushes_chain_as_far_as_possible()
    local board = makeBoard(0, 7, 0)
    local warrior = spawnPlayer(board, 1, 0, Player.Classes.WARRIOR)
    local first = spawnBox(board, 2, 0)
    local second = spawnBox(board, 3, 0)
    assert(run(board, warrior, {x = 1, y = 0}))
    assertPosition(warrior, 2, 0)
    assertPosition(first, 6, 0)
    assertPosition(second, 7, 0)
end

function tests.warrior_stops_the_chain_before_another_object()
    local board = makeBoard(0, 6, 0)
    local warrior = spawnPlayer(board, 1, 0, Player.Classes.WARRIOR)
    local first = spawnBox(board, 2, 0)
    local blocker = spawnBox(board, 4, 0)
    assert(run(board, warrior, {x = 1, y = 0}))
    assertPosition(warrior, 2, 0)
    assertPosition(first, 3, 0)
    assertPosition(blocker, 4, 0)
end

function tests.telekinetic_pushes_the_first_object_one_cell()
    local board = makeBoard(0, 6, 0)
    local telekinetic = spawnPlayer(board, 1, 0, Player.Classes.TELEKINETIC)
    local box = spawnBox(board, 4, 0)
    assert(run(board, telekinetic, {x = 1, y = 0}))
    assertPosition(telekinetic, 2, 0)
    assertPosition(box, 5, 0)
end

function tests.telekinetic_does_not_move_object_into_blocker()
    local board = makeBoard(0, 5, 0)
    local telekinetic = spawnPlayer(board, 1, 0, Player.Classes.TELEKINETIC)
    local box = spawnBox(board, 3, 0)
    spawnBox(board, 4, 0)
    assert(not run(board, telekinetic, {x = 1, y = 0}))
    assertPosition(telekinetic, 1, 0)
    assertPosition(box, 3, 0)
end

function tests.sorcerer_pulls_a_distant_object_back()
    local board = makeBoard(0, 6, 0)
    local sorcerer = spawnPlayer(board, 1, 0, Player.Classes.SORCERER)
    local box = spawnBox(board, 4, 0)
    assert(run(board, sorcerer, {x = 1, y = 0}))
    assertPosition(sorcerer, 2, 0)
    assertPosition(box, 3, 0)
end

function tests.sorcerer_cannot_pull_an_adjacent_object()
    local board = makeBoard(0, 4, 0)
    local sorcerer = spawnPlayer(board, 1, 0, Player.Classes.SORCERER)
    local box = spawnBox(board, 2, 0)
    assert(not run(board, sorcerer, {x = 1, y = 0}))
    assertPosition(sorcerer, 1, 0)
    assertPosition(box, 2, 0)
end

function tests.sorcerer_cannot_pull_onto_its_destination()
    local board = makeBoard(0, 4, 0)
    local sorcerer = spawnPlayer(board, 1, 0, Player.Classes.SORCERER)
    local box = spawnBox(board, 3, 0)
    assert(not run(board, sorcerer, {x = 1, y = 0}))
    assertPosition(sorcerer, 1, 0)
    assertPosition(box, 3, 0)
end

function tests.pushed_wizard_uses_swap_and_leaves_pusher_blocked()
    local board = makeBoard(0, 5, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local wizard = spawnPlayer(board, 2, 0, Player.Classes.WIZARD)
    local box = spawnBox(board, 4, 0)
    assert(run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 1, 0)
    assertPosition(wizard, 4, 0)
    assertPosition(box, 2, 0)
end

function tests.pushed_wizard_with_clear_ray_walks_and_pusher_follows()
    local board = makeBoard(0, 4, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local wizard = spawnPlayer(board, 2, 0, Player.Classes.WIZARD)
    assert(run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 2, 0)
    assertPosition(wizard, 3, 0)
end

function tests.pushing_a_player_through_a_box_chain_uses_their_ability()
    local board = makeBoard(0, 5, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local box = spawnBox(board, 2, 0)
    local wizard = spawnPlayer(board, 3, 0, Player.Classes.WIZARD)
    assert(run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 2, 0)
    assertPosition(box, 3, 0)
    assertPosition(wizard, 4, 0)
end

return tests
