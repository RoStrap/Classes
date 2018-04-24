-- Simple and light-weight function for setting read-only properties of a Class

local function setreadonly(Class, ReadOnly)
	-- Sets properties within ReadOnly to be accessible but unwritable to tables with metatable set to Class
	-- @param table Class the Class which should be able to access read-only properties but not write to them
	-- @param table Readonly the table full of read-only properties to copy into __index and disallow writing
	-- assumes Class:__newindex is otherwise unused

	local __index = assert(Class.__index, "Class must have __index metamethod before calling setreadonly")

	for i, v in next, ReadOnly do
		__index[i] = v
	end

	function Class:__newindex(i, v)
		if ReadOnly[i] == nil then
			rawset(self, i, v)
		else
			error("Property \"" .. tostring(i) .. "\" is read-only")
		end
	end
end

return setreadonly
