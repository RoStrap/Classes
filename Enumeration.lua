-- Pure-lua implementation of Enums
-- @author Validark

local Resources = require(game:GetService("ReplicatedStorage"):WaitForChild("Resources"))
local Debug = Resources:LoadLibrary("Debug")
local SortedArray = Resources:LoadLibrary("SortedArray")

local function IsValidArray(Table)
	-- @returns bool Whether table Table it is a valid array of type {"Type1", "Type2", "Type3"}

	local Count = 1
	local Unwarned = true
	local HighestIndex = next(Table)

	if type(HighestIndex) == "number" then
		for i, _ in next, Table, HighestIndex do
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

local Enumerations = {}
local EnumerationsArray = SortedArray.new()

function Enumerations:GetEnumerations()
	return EnumerationsArray:Copy()
end

local function ReadOnlyNewIndex(_, Index, _)
	Debug.Error("Cannot write to index [%q]", Index)
end

local function Comparison(Left, Right)
	return tostring(Left) < tostring(Right)
end

local function ConstructUserdata(__index, __newindex, String)
	local Enumeration = newproxy(true)

	local EnumerationMetatable = getmetatable(Enumeration)
	EnumerationMetatable.__index = function(_, Index) return __index[Index] or Debug.Error("[%q] is not a valid EnumerationItem", Index) end
	EnumerationMetatable.__newindex = __newindex
	EnumerationMetatable.__tostring = function() return String end
	EnumerationMetatable.__metatable = "[Enumeration] Requested metatable is locked"
	EnumerationMetatable.__lt = Comparison

	return Enumeration
end

local function MakeEnumeration(_, EnumType, EnumTypes)
	if type(EnumType) ~= "string" then Debug.Error("Cannot write to non-string key of Enumeration: %s", EnumType) end
	if type(EnumTypes) ~= "table" then Debug.Error("Expected array of string EnumerationItem Names, got %s", EnumType) end
	if not IsValidArray(EnumTypes) then Debug.Error("Expected table " .. EnumType .. " to be an array of strings of the form {\"Type1\", \"Type2\", \"Type3\"}") end
	if Enumerations[EnumType] then Debug.Error("Enumeration of EnumType " .. EnumType .. " already exists") end

	local EnumContainer = {}

	for i = 1, #EnumTypes do
		local Name = EnumTypes[i]
		local Item = ConstructUserdata({
			EnumType = EnumType;
			Name = Name;
			Value = i - 1;
		}, ReadOnlyNewIndex, "Enumeration." .. EnumType .. "." .. Name)

		EnumTypes[i] = Item
		EnumContainer[Name] = Item
	end

	function EnumContainer:GetEnumerationItems()
		local EnumerationItems = {}

		for i = 1, #EnumTypes do
			EnumerationItems[i] = EnumTypes[i]
		end

		return EnumerationItems
	end

	local Enumerator = ConstructUserdata(EnumContainer, ReadOnlyNewIndex, EnumType)
	EnumerationsArray:Insert(Enumerator)
	Enumerations[EnumType] = Enumerator
end

return ConstructUserdata(Enumerations, MakeEnumeration, "Enumerations")
