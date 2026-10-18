local Fonts = require("src.ui.Fonts")

local UndoHistoryOverlay = {}
local numberFont

local COLORS = {
	{0.98, 0.34, 0.27},
	{0.20, 0.78, 1.00},
	{1.00, 0.75, 0.20},
	{0.67, 0.48, 1.00},
	{0.26, 0.90, 0.52},
	{1.00, 0.42, 0.78},
}

local function colorForPlayer(index)
	return COLORS[(index - 1) % #COLORS + 1]
end

local function collectPaths(board, actions)
	local paths = {}
	for playerIndex, player in ipairs(board.players) do
		local transform = player:getComponent("Transform")
		local points = {{x = transform.x, y = transform.y}}
		local undoNumber = 0

		for actionIndex = #actions, 1, -1 do
			for _, snapshot in ipairs(actions[actionIndex]) do
				if snapshot.object == player then
					undoNumber = undoNumber + 1
					points[#points + 1] = {
						x = (snapshot.gridX + 0.5) * transform.cellSize,
						y = (snapshot.gridY + 0.5) * transform.cellSize,
						number = undoNumber,
					}
					break
				end
			end
		end

		if undoNumber > 0 then
			paths[#paths + 1] = {
				player = player,
				playerIndex = playerIndex,
				points = points,
				undoCount = undoNumber,
				color = colorForPlayer(playerIndex),
			}
		end
	end
	return paths
end

function UndoHistoryOverlay.drawWorld(board, actions)
	local paths = collectPaths(board, actions)
	love.graphics.push("all")
	for _, path in ipairs(paths) do
		local color = path.color
		love.graphics.setColor(color[1], color[2], color[3], 0.72)
		love.graphics.setLineWidth(3)
		for index = 1, #path.points - 1 do
			local from, to = path.points[index], path.points[index + 1]
			love.graphics.line(from.x, from.y, to.x, to.y)
		end

		for index = 2, #path.points do
			local point = path.points[index]
			local number = tostring(point.number)
			numberFont = numberFont or love.graphics.newFont(24)
			local markerRadius = math.min(29, math.max(18, numberFont:getWidth(number) / 2 + 5))
			love.graphics.setColor(color[1], color[2], color[3], 1)
			love.graphics.circle("fill", point.x, point.y, markerRadius)
			love.graphics.setColor(0, 0, 0, 0.9)
			love.graphics.setLineWidth(2)
			love.graphics.circle("line", point.x, point.y, markerRadius - 1)
			love.graphics.setFont(numberFont)
			local textX = point.x - numberFont:getWidth(number) / 2
			local textY = point.y - numberFont:getHeight() / 2
			love.graphics.setColor(0, 0, 0, 0.75)
			love.graphics.print(number, textX + 1, textY + 1)
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.print(number, textX, textY)
			love.graphics.print(number, textX + 0.6, textY)
		end
	end
	love.graphics.pop()
	return paths
end

function UndoHistoryOverlay.drawLegend(paths)
	if #paths == 0 then return end
	love.graphics.push("all")
	local x, y = 16, 18
	for _, path in ipairs(paths) do
		local color = path.color
		local characterClass = path.player:getComponent("CharacterClass")
		local name = characterClass and characterClass.behavior.name or ("Player " .. path.playerIndex)
		love.graphics.setColor(0, 0, 0, 0.78)
		love.graphics.rectangle("fill", x - 6, y - 3, 230, 26)
		love.graphics.setColor(color[1], color[2], color[3], 1)
		love.graphics.rectangle("fill", x, y + 3, 14, 14)
		love.graphics.setColor(1, 1, 1, 1)
		Fonts.set(16)
		love.graphics.print(name .. "  -  " .. path.undoCount .. " undos", x + 22, y)
		y = y + 30
	end
	love.graphics.pop()
end

return UndoHistoryOverlay
