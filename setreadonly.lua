-- Simple and light-weight function for setting read-only properties of a Class

local function setreadonly(Class, ReadOnlyProperties)
	-- Sets properties within ReadOnlyProperties to be accessible but unwritable to tables with metatable set to Class
	-- @param table Class the Class which should be able to access read-only properties but not write to them
	-- @param table ReadOnlyProperties the table full of read-only properties to copy into __index and disallow writing to
	-- This assumes Class:__newindex is otherwise unused, and __index is already declared

	local __index = assert(Class.__index, "Class must have __index metamethod before calling setreadonly")

	for i, v in next, ReadOnlyProperties do
		__index[i] = v
	end

	function Class:__newindex(i, v)
		if ReadOnlyProperties[i] == nil then
			rawset(self, i, v)
		else
			error("Property \"" .. tostring(i) .. "\" is read-only")
		end
	end
end

return setreadonly
