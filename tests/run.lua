package.path = "./?.lua;./?/init.lua;" .. package.path

local suites = {
    {name = "character_movement", tests = require("tests.character_movement")},
    {name = "narrative_triggers", tests = require("tests.narrative_triggers")},
    {name = "board_win_condition", tests = require("tests.board_win_condition")},
    {name = "target_component", tests = require("tests.target_component")},
    {name = "level_progress", tests = require("tests.level_progress")},
}
local passed, failed = 0, 0

for _, suite in ipairs(suites) do
    local names = {}
    for name in pairs(suite.tests) do
        names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local ok, errorMessage = pcall(suite.tests[name])
        if ok then
            passed = passed + 1
            print("PASS " .. suite.name .. "." .. name)
        else
            failed = failed + 1
            io.stderr:write("FAIL " .. suite.name .. "." .. name .. ": " .. tostring(errorMessage) .. "\n")
        end
    end
end

print(string.format("\n%d tests passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
