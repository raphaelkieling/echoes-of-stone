local Component = require("src.core.Component")

local Player = Component:extend()
Player.componentName = "Player"
Player.Classes = require("src.characters.Classes")

function Player:init()
    Component.init(self)
end

function Player:setClass(classObject, assets)
    if type(classObject) == "string" then
        classObject = Player.Classes.create(classObject)
    end
    local existing = self:getClass()
    local character = self.owner:getComponent("Character")
    if existing then
        if character then
            character:replaceComponent("CharacterClass", classObject)
        else
            error("class replacement requires a Character component")
        end
        self:updateAppearance(classObject, assets)
        return classObject
    end
    if character then
        character:addComponent(classObject)
    else
        self.owner:addComponent(classObject)
    end
    self:updateAppearance(classObject, assets)
    return classObject
end

function Player:getClass()
    return self.owner and self.owner:getComponent("CharacterClass") or nil
end

function Player:getStateMachine()
    return self.owner and self.owner:getComponent("StateMachine") or nil
end

function Player:updateAppearance(classObject, assets)
    if not assets then return end
    local sprite = classObject.sprite
    local animation = self.owner:getComponent("Animation")
    local renderer = self.owner:getComponent("SpriteRenderer")
    if animation then animation:set(assets:playerAnimation(sprite.x, sprite.y)) end
    if renderer then
        renderer:setAppearance(assets.players, sprite.scale, 3, assets.outlineShader)
    end
end

return Player
