local Node = require("src.core.Node")

-- A scene is a root node managed by SceneManager, never a GameObject component.
local Scene = Node:extend()

function Scene:init(name, game)
	Node.init(self, name or "Scene")
	self.game = game
	self.drawSpace = nil
end

return Scene
