-- Pure-lua implementation of Enums
-- @author Validark

local Enumerations = {}

local function ReadOnlyNewIndex(_, Index, _)
	error("[Enumeration] Cannot write to index \"" .. tostring(Index) .. "\"", 2)
end

local ReadOnlyMetatable = "[Enumeration] Requested metatable is locked"

local function ReadOnlyIndex(Table)
	return function(_, Index)
		return Table[Index] or error("[Enumeration] \"" .. tostring(Index) .. "\" is not a valid EnumerationItem", 2)
	end
end

local function IsValidArray(Table)
	-- @returns bool Whether table Table it is a valid array of type {"Type1", "Type2", "Type3"}

	local Count = 0
	local HighestIndex = 0
	local Unwarned = true

	for i, v in next, Table do
		if type(i) ~= "number" or 0 >= i then
			warn("[Enumeration] Table EnumTypes is not a valid array, got key", typeof(i), tostring(i))
			Unwarned = false
		end

		if type(v) ~= "string" then
			warn("[Enumeration] Table EnumTypes is not a valid array, got value", typeof(v), tostring(v))
			Unwarned = false
		end

		if HighestIndex < i then HighestIndex = i end
		Count = Count + 1
	end

	return Unwarned and Count == HighestIndex
end

local function MakeEnumeration(_, EnumType, EnumTypes)
	if type(EnumType) ~= "string" then error("[Enumeration] Expected string to instantiate Enumeration, got " .. typeof(EnumType) .. " " .. tostring(EnumType), 2) end
	if type(EnumTypes) ~= "table" then error("[Enumeration] Expected array of EnumerationItem Names, got " .. typeof(EnumType) .. " " .. tostring(EnumType), 2) end
	if not IsValidArray(EnumTypes) then error("[Enumeration] Expected table to be an array of the form {\"Type1\", \"Type2\", \"Type3\"}", 2) end
	if Enumerations[EnumType] then error("[Enumeration] Enumeration of EnumType " .. tostring(EnumType) .. " already exists", 2) end

	for i = 1, #EnumTypes do
		local Name = EnumTypes[i]
		local Item = newproxy(true)
		local ItemMetatable = getmetatable(Item)
		ItemMetatable.__index = ReadOnlyIndex{
			EnumType = EnumType;
			Name = Name;
			Value = i - 1;
		}
		ItemMetatable.__newindex = ReadOnlyNewIndex
		ItemMetatable.__metatable = ReadOnlyMetatable
		ItemMetatable.__tostring = function() return "Enumeration." .. EnumType .. "." .. Name end

		EnumTypes[i] = nil
		EnumTypes[Name] = Item
	end

	local Enumerator = newproxy(true)
	local EnumeratorMetatable = getmetatable(Enumerator)
	EnumeratorMetatable.__index = ReadOnlyIndex(EnumTypes);
	EnumeratorMetatable.__newindex = ReadOnlyNewIndex;
	EnumeratorMetatable.__metatable = ReadOnlyMetatable;
	EnumeratorMetatable.__tostring = function() return EnumType end;

	Enumerations[EnumType] = Enumerator
end

local Enumeration = newproxy(true)
local EnumerationMetatable = getmetatable(Enumeration)
EnumerationMetatable.__index = ReadOnlyIndex(Enumerations)
EnumerationMetatable.__newindex = MakeEnumeration
EnumerationMetatable.__metatable = ReadOnlyMetatable
EnumerationMetatable.__tostring = function() return "Enumerations" end
EnumerationMetatable.__namecall = function(_, ...)
	if select(select("#", ...), ...) == "GetEnumerations" then
		-- Returns an array of all the Enumerations ever created
		local t = {}
		local Count = 0

		for _, Enumerator in next, Enumerations do
			Count = Count + 1
			t[Count] = Enumerator
		end

		return t
	else
		error("[Enumeration] The only method of Enumeration is \"GetEnumerations\"", 2)
	end
end

return Enumeration
