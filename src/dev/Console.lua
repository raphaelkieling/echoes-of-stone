local Fonts = require("src.ui.Fonts")

local Console = {}
Console.__index = Console

local function splitWords(text)
    local words = {}
    for word in text:gmatch("%S+") do
        words[#words + 1] = word
    end
    return words
end

local function commonPrefix(strings)
    if #strings == 0 then return "" end
    local prefix = strings[1]
    for index = 2, #strings do
        while strings[index]:sub(1, #prefix) ~= prefix do
            prefix = prefix:sub(1, -2)
            if prefix == "" then return "" end
        end
    end
    return prefix
end

function Console.new()
    return setmetatable({
        open = false,
        input = "",
        commands = {},
        output = {},
        suppressTextInput = false,
    }, Console)
end

function Console:registerCommand(name, description, callback)
    assert(type(name) == "string" and name:match("^[%w%-]+$"), "invalid console command name")
    assert(type(callback) == "function", "console command callback must be a function")
    self.commands[name] = {name = name, description = description or "", callback = callback}
end

function Console:write(message)
    self.output[#self.output + 1] = tostring(message)
    while #self.output > 3 do table.remove(self.output, 1) end
end

function Console:matchingCommands(prefix)
    local matches = {}
    for name, command in pairs(self.commands) do
        if name:sub(1, #prefix) == prefix then matches[#matches + 1] = command end
    end
    table.sort(matches, function(a, b) return a.name < b.name end)
    return matches
end

function Console:complete()
    if self.input:find("%s") then return end
    local matches = self:matchingCommands(self.input)
    if #matches == 1 then
        self.input = matches[1].name .. " "
    elseif #matches > 1 then
        local names = {}
        for _, command in ipairs(matches) do names[#names + 1] = command.name end
        self.input = commonPrefix(names)
    end
end

function Console:execute(context)
    local words = splitWords(self.input)
    local name = table.remove(words, 1)
    if not name then return end
    local command = self.commands[name:lower()]
    if not command then
        self:write("Unknown command: " .. name)
        return
    end

    local ok, result = pcall(command.callback, context, words, self)
    if not ok then
        self:write("Error: " .. tostring(result))
    elseif result then
        self:write(result)
    end
end

function Console:keypressed(key, scancode, context)
    local isConsoleKey = key == "`" or key == "~" or scancode == "grave"
    if not self.open then
        if isConsoleKey then
            self.open = true
            self.input = ""
            self.suppressTextInput = true
            return true, "opened"
        end
        return false
    end

    if isConsoleKey then
        self.open = false
        self.input = ""
        return true, "closed"
    elseif key == "escape" then
        self.open = false
        self.input = ""
    elseif key == "return" or key == "kpenter" then
        self:execute(context)
        self.input = ""
    elseif key == "tab" then
        self:complete()
    elseif key == "backspace" then
        self.input = self.input:sub(1, -2)
    end
    return true
end

function Console:textinput(text)
    if not self.open then return end
    if self.suppressTextInput then
        self.suppressTextInput = false
        if text == "`" or text == "~" then return end
    end
    if text:match("^[%g ]+$") then self.input = self.input .. text end
end

function Console:draw()
    if not self.open then return end

    local width = math.min(love.graphics.getWidth() - 32, 920)
    local x = (love.graphics.getWidth() - width) / 2
    local y, height = 28, 210
    love.graphics.push("all")
    love.graphics.setColor(0.015, 0.02, 0.035, 0.96)
    love.graphics.rectangle("fill", x, y, width, height, 8, 8)
    love.graphics.setColor(0.38, 0.82, 1, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, 8, 8)

    love.graphics.setColor(0.68, 0.78, 0.86, 1)
    Fonts.set(16)
    love.graphics.print("DEV CONSOLE    TAB: autocomplete    ENTER: run    ESC: close", x + 18, y + 14)
    love.graphics.setColor(1, 1, 1, 1)
    Fonts.set(24)
    love.graphics.print("> " .. self.input .. "_", x + 18, y + 43)

    local prefix = self.input:match("^(%S*)") or ""
    local matches = self:matchingCommands(prefix)
    Fonts.set(17)
    for index = 1, math.min(#matches, 3) do
        local command = matches[index]
        love.graphics.setColor(index == 1 and 0.58 or 0.78, index == 1 and 0.92 or 0.82, 1, 1)
        love.graphics.print(command.name .. "  -  " .. command.description,
            x + 26, y + 82 + (index - 1) * 23)
    end

    if #self.output > 0 then
        love.graphics.setColor(0.78, 0.82, 0.86, 1)
        Fonts.set(15)
        love.graphics.print(self.output[#self.output], x + 18, y + height - 25)
    end
    love.graphics.pop()
end

return Console
