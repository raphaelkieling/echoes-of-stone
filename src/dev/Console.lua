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
        suggestionSelection = 1,
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
            self.suggestionSelection = 1
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
    elseif key == "up" or key == "down" then
        local prefix = self.input:match("^(%S*)") or ""
        local matches = self:matchingCommands(prefix)
        if #matches > 0 then
            if key == "up" then
                self.suggestionSelection = (self.suggestionSelection - 2) % #matches + 1
            else
                self.suggestionSelection = self.suggestionSelection % #matches + 1
            end
        end
    elseif key == "return" or key == "kpenter" then
        local commandName = self.input:match("^%s*(%S+)")
        local hasArguments = self.input:match("^%s*%S+%s+%S+") ~= nil
        local isCompleteCommand = commandName and self.commands[commandName:lower()]
        if isCompleteCommand and (hasArguments or self.input:match("^%s*%S+%s*$")) then
            self:execute(context)
            self.input = ""
            self.suggestionSelection = 1
        else
            local prefix = self.input:match("^(%S*)") or ""
            local matches = self:matchingCommands(prefix)
            local suggestion = matches[self.suggestionSelection]
            if suggestion then
                self.input = suggestion.name .. " "
                self.suggestionSelection = 1
            else
                self:execute(context)
                self.input = ""
                self.suggestionSelection = 1
            end
        end
    elseif key == "tab" then
        self:complete()
        self.suggestionSelection = 1
    elseif key == "backspace" then
        self.input = self.input:sub(1, -2)
        self.suggestionSelection = 1
    end
    return true
end

function Console:textinput(text)
    if not self.open then return end
    if self.suppressTextInput then
        self.suppressTextInput = false
        if text == "`" or text == "~" then return end
    end
    if text:match("^[%g ]+$") then
        self.input = self.input .. text
        self.suggestionSelection = 1
    end
end

function Console:draw()
    if not self.open then return end

    local screenWidth = love.graphics.getWidth()
    local width = math.min(screenWidth - 32, 880)
    local x = (screenWidth - width) / 2
    local y, height = 24, 184
    love.graphics.push("all")
    love.graphics.setColor(0.008, 0.018, 0.018, 0.98)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(0.22, 0.92, 0.58, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x + 1, y + 1, width - 2, height - 2)

    love.graphics.setColor(0.45, 0.95, 0.69, 1)
    Fonts.set(21)
    love.graphics.print("DEV CONSOLE", x + 18, y + 10)
    love.graphics.setColor(0.84, 1, 0.91, 1)
    Fonts.set(29)
    love.graphics.print("> " .. self.input .. "_", x + 18, y + 37)

    local prefix = self.input:match("^(%S*)") or ""
    local matches = self:matchingCommands(prefix)
    Fonts.set(19)
    for index = 1, math.min(#matches, 3) do
        local command = matches[index]
        local rowY = y + 76 + (index - 1) * 22
        local selected = index == self.suggestionSelection
        if selected then
            love.graphics.setColor(0.055, 0.19, 0.12, 0.78)
            love.graphics.rectangle("fill", x + 12, rowY - 2, width - 24, 22)
        end
        love.graphics.setColor(selected and 0.43 or 0.72,
            selected and 1 or 0.86, selected and 0.64 or 0.78, 1)
        love.graphics.print(command.name .. "  -  " .. command.description,
            x + 22, rowY - 1)
    end

    if #self.output > 0 then
        love.graphics.setColor(0.48, 0.72, 0.6, 1)
        Fonts.set(17)
        love.graphics.print(self.output[#self.output], x + 18, y + height - 23)
    end
    love.graphics.pop()
end

return Console
