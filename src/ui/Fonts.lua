local Fonts = {}
local cache = {}

function Fonts.get(size)
    assert(type(size) == "number" and size > 0, "font size must be positive")
    if not cache[size] then
        cache[size] = love.graphics.newFont("assets/monogram.ttf", size)
    end
    return cache[size]
end

function Fonts.set(size)
    love.graphics.setFont(Fonts.get(size))
end

return Fonts
