local NarrativeCatalog = {items = {}, loaded = false}

function NarrativeCatalog.register(id, narrative)
	assert(type(id) == "string" and id ~= "", "narrative ID must be a non-empty string")
	assert(type(narrative) == "table", "narrative definition must be a table")
	assert(type(narrative.steps) == "table", "narrative " .. id .. " needs a steps table")
	assert(#narrative.steps > 0, "narrative " .. id .. " needs at least one step")
	assert(not NarrativeCatalog.items[id], "duplicate narrative ID: " .. id)
	narrative.id = id
	-- Narrative sequences block gameplay in the first version. This keeps their
	-- input and dialogue behavior explicit until non-blocking barks are needed.
	narrative.blocking = true
	NarrativeCatalog.items[id] = narrative
	return narrative
end

function NarrativeCatalog.load()
	if NarrativeCatalog.loaded then return NarrativeCatalog end
	NarrativeCatalog.loaded = true

	local directory = "src/narratives"
	for _, filename in ipairs(love.filesystem.getDirectoryItems(directory)) do
		local moduleName = filename:match("^([%w_]+)%.lua$")
		if moduleName and moduleName:lower() ~= "narrativecatalog" then
			require(directory:gsub("/", ".") .. "." .. moduleName)
		end
	end
	return NarrativeCatalog
end

function NarrativeCatalog.get(id)
	return NarrativeCatalog.items[id]
end

return NarrativeCatalog
