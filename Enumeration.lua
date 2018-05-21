-- Pure-lua implementation of Enums

local Resources = require(game:GetService("ReplicatedStorage"):WaitForChild("Resources"))
local Debug = Resources:LoadLibrary("Debug")

local Enumerations = {}
local EnumerationsArray = {}

local function ReadOnlyNewIndex(_, Index, _)
	Debug.Error("Cannot write to index [%q]", Index)
end

local ReadOnlyMetatable = "[Enumeration] Requested metatable is locked"

local function ReadOnlyIndex(Table)
	return function(_, Index)
		return Table[Index] or Debug.Error("[%q] is not a valid EnumerationItem", Index)
	end
end

local function GetEnumerationsNameCall(Table, MethodName)
	return function(_, ...)
		if select(select("#", ...), ...) == MethodName then
			-- Returns a copy of array Table

			local Copy = {}

			for i = 1, #Table do
				Copy[i] = Table[i]
			end

			return Copy
		else
			Debug.Error("The only valid method of this object is \"" .. MethodName .. "\"")
		end
	end
end

local function IsValidArray(Table)
	-- @returns bool Whether table Table it is a valid array of type {"Type1", "Type2", "Type3"}

	local Count = 1
	local Unwarned = true
	local HighestIndex = next(Table)

	if type(HighestIndex) == "number" then
		for i, v in next, Table, HighestIndex do
			if type(i) == "number" and HighestIndex < i then
				HighestIndex = i
			end
			Count = Count + 1
		end

		for i = 1, Count do
			if type(Table[i]) ~= "string" then
				Debug.Warn("Table of EnumTypes is not a valid array, got %s at index %s", Table[i], i)
				Unwarned = false
			end
		end
	else
		Debug.Warn("Table of EnumTypes is either empty or has a non-integer key")
		Unwarned = false
	end

	return Unwarned and Count == HighestIndex
end

local function MakeEnumeration(_, EnumType, EnumTypes)
	if type(EnumType) ~= "string" then Debug.Error("Cannot write to non-string key of Enumeration: %s", EnumType) end
	if type(EnumTypes) ~= "table" then Debug.Error("Expected array of string EnumerationItem Names, got %s", EnumType) end
	if not IsValidArray(EnumTypes) then Debug.Error("Expected table " .. EnumType .. " to be an array of strings of the form {\"Type1\", \"Type2\", \"Type3\"}") end
	if Enumerations[EnumType] then Debug.Error("Enumeration of EnumType " .. EnumType .. " already exists") end

	local EnumContainer = {}

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

		EnumTypes[i] = Item
		EnumContainer[Name] = Item
	end

	local Enumerator = newproxy(true)
	local EnumeratorMetatable = getmetatable(Enumerator)
	EnumeratorMetatable.__index = ReadOnlyIndex(EnumContainer)
	EnumeratorMetatable.__newindex = ReadOnlyNewIndex
	EnumeratorMetatable.__metatable = ReadOnlyMetatable
	EnumeratorMetatable.__tostring = function() return EnumType end
	EnumeratorMetatable.__namecall = GetEnumerationsNameCall(EnumTypes, "GetEnumerationItems")

	local InsertedIntoEnumerationsArray -- Place into ordered EnumerationsArray so we don't have to do table.sort upon every GetEnumerations()

	for i = 1, #EnumerationsArray do
		if EnumType < tostring(EnumerationsArray[i]) then -- Determine whether `key` precedes `EnumerationsArray[i]` alphabetically
			InsertedIntoEnumerationsArray = true
			table.insert(EnumerationsArray, i, Enumerator)
			break
		end
	end

	if not InsertedIntoEnumerationsArray then
		table.insert(EnumerationsArray, Enumerator)
	end

	Enumerations[EnumType] = Enumerator
end

local Enumeration = newproxy(true)
local EnumerationMetatable = getmetatable(Enumeration)
EnumerationMetatable.__index = ReadOnlyIndex(Enumerations)
EnumerationMetatable.__newindex = MakeEnumeration
EnumerationMetatable.__metatable = ReadOnlyMetatable
EnumerationMetatable.__tostring = function() return "Enumerations" end
EnumerationMetatable.__namecall = GetEnumerationsNameCall(EnumerationsArray, "GetEnumerations")

return Enumeration
