local Fonts = require("src.ui.Fonts")
local json = require("vendor.json")

local Console = {}
Console.__index = Console
local SETTINGS_PATH = "console-settings.json"

local function loadPreferences()
    if not love or not love.filesystem then return {toggles = {}} end
    local contents = love.filesystem.read(SETTINGS_PATH)
    if not contents then return {toggles = {}} end
    local ok, preferences = pcall(json.decode, contents)
    if not ok or type(preferences) ~= "table" then return {toggles = {}} end
    if type(preferences.toggles) ~= "table" then preferences.toggles = {} end
    return preferences
end

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

function Console.new(events)
    return setmetatable({
        events = events,
        open = false,
        input = "",
        commands = {},
        output = {},
        preferences = loadPreferences(),
        suggestionSelection = 1,
        suppressTextInput = false,
    }, Console)
end

function Console:registerCommand(name, description, callback)
	assert(type(name) == "string" and name:match("^[%w%- ]+$")
		and not name:match("^ ") and not name:match(" $") and not name:match("  "),
		"invalid console command name")
    assert(type(callback) == "function", "console command callback must be a function")
    self.commands[name] = {name = name, description = description or "", callback = callback}
end

function Console:registerToggleCommand(name, description, callback)
    self:registerCommand(name, description, callback)
    self.commands[name].toggle = true
end

function Console:savePreferences()
    if not love or not love.filesystem then return false end
    local ok, contents = pcall(json.encode, self.preferences)
    if not ok then return false end
    local written = love.filesystem.write(SETTINGS_PATH, contents)
    return written == true
end

function Console:applyToggles(context)
    for name, command in pairs(self.commands) do
        if command.toggle then
            local enabled = self.preferences.toggles[name] == true
            pcall(command.callback, context, enabled, self)
        end
    end
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
	local matches = self:matchingCommands(self.input)
	if #matches == 1 then
		self.input = matches[1].name .. " "
    elseif #matches > 1 then
        local names = {}
        for _, command in ipairs(matches) do names[#names + 1] = command.name end
        self.input = commonPrefix(names)
    end
end

function Console:resolveCommand(input)
	local normalized = input:lower():match("^%s*(.-)%s*$")
	local selected, arguments
	for name, command in pairs(self.commands) do
		local commandName = name:lower()
		if normalized == commandName then
			return command, {}
		elseif normalized:sub(1, #commandName + 1) == commandName .. " "
			and (not selected or #commandName > #selected.name) then
			selected = command
			arguments = splitWords(normalized:sub(#commandName + 1))
		end
	end
	return selected, arguments
end

function Console:execute(context)
	local command, arguments = self:resolveCommand(self.input)
	if not command then
		local name = self.input:match("^%s*(%S+)")
		if self.events then self.events:emit("command.unknown", {command = name}) end
		self:write("Unknown command: " .. self.input)
		return
	end

	local ok, result
	if command.toggle then
		local mode = ((arguments or {})[1] or "toggle"):lower()
		local current = self.preferences.toggles[command.name] == true
		local enabled
		if mode == "on" then
			enabled = true
		elseif mode == "off" then
			enabled = false
		elseif mode == "toggle" then
			enabled = not current
		else
			self:write("Usage: " .. command.name .. " [on|off|toggle]")
			return
		end
		self.preferences.toggles[command.name] = enabled
		self:savePreferences()
		ok, result = pcall(command.callback, context, enabled, self)
	else
		ok, result = pcall(command.callback, context, arguments or {}, self)
	end
	if self.events then
		self.events:emit("command.executed", {command = command.name, succeeded = ok})
	end
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
		local prefix = self.input:match("^%s*(.-)%s*$") or ""
        local matches = self:matchingCommands(prefix)
        if #matches > 0 then
            if key == "up" then
                self.suggestionSelection = (self.suggestionSelection - 2) % #matches + 1
            else
                self.suggestionSelection = self.suggestionSelection % #matches + 1
            end
        end
	elseif key == "return" or key == "kpenter" then
		local command = self:resolveCommand(self.input)
		if command then
			self:execute(context)
            self.input = ""
            self.suggestionSelection = 1
        else
			local prefix = self.input:match("^%s*(.-)%s*$") or ""
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

    local screenWidth, screenHeight = love.graphics.getDimensions()
    local width = math.min(screenWidth - 32, 880)
    local x = (screenWidth - width) / 2
    local prefix = self.input:match("^%s*(.-)%s*$") or ""
    local matches = self:matchingCommands(prefix)
    local y = 24
	local rowHeight = 28
    local maxHeight = math.max(150, screenHeight - 48)
	local height = math.min(maxHeight, 120 + #matches * rowHeight)
	local visibleCount = math.max(1, math.floor((height - 120) / rowHeight))
    local firstIndex = math.max(1, math.min(self.suggestionSelection, #matches - visibleCount + 1))
    local lastIndex = math.min(#matches, firstIndex + visibleCount - 1)
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

	Fonts.set(22)
    for index = firstIndex, lastIndex do
        local command = matches[index]
		local rowY = y + 76 + (index - firstIndex) * rowHeight
        local selected = index == self.suggestionSelection
        if selected then
            love.graphics.setColor(0.055, 0.19, 0.12, 0.78)
            love.graphics.rectangle("fill", x + 12, rowY - 2, width - 24, 22)
        end
        love.graphics.setColor(selected and 0.43 or 0.72,
            selected and 1 or 0.86, selected and 0.64 or 0.78, 1)
		local statusWidth = command.toggle and 112 or 0
		local description = command.name .. "  -  " .. command.description
		local maxTextWidth = width - 48 - statusWidth
		local font = love.graphics.getFont()
		while #description > 3 and font:getWidth(description) > maxTextWidth do
			description = description:sub(1, -2)
		end
		if description ~= command.name .. "  -  " .. command.description then
			description = description:sub(1, -4) .. "..."
		end
		love.graphics.print(description, x + 22, rowY - 1)
		if command.toggle then
			local enabled = self.preferences.toggles[command.name] == true
			local indicator = enabled and "[x] ON" or "[ ] OFF"
			love.graphics.setColor(enabled and 0.43 or 0.60,
				enabled and 1 or 0.66, enabled and 0.64 or 0.60, 1)
			love.graphics.printf(indicator, x + width - statusWidth - 18,
				rowY - 1, statusWidth, "right")
		end
    end

    if #self.output > 0 then
        love.graphics.setColor(0.48, 0.72, 0.6, 1)
        Fonts.set(17)
        love.graphics.print(self.output[#self.output], x + 18, y + height - 23)
    end
    love.graphics.pop()
end

return Console
