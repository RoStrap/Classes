-- Pure-lua implementation of Roblox-style Enums
-- @author Validark

local Resources = require(game:GetService("ReplicatedStorage"):WaitForChild("Resources"))
local Debug = Resources:LoadLibrary("Debug")
local SortedArray = Resources:LoadLibrary("SortedArray")

local function IsValidArray(Table)
	-- @returns bool Whether table Table it is a valid array of type {"Type1", "Type2", "Type3"}

	local Count = 1
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
				return false
			end
		end
	else
		return false
	end

	return Count == HighestIndex
end

local function IsValidDictionary(Table)
	-- @returns bool Whether table Table it is a valid array of type {Type1 = 1; Type5 = 5}

	for i, v in next, Table do
		if type(i) ~= "string" or type(v) ~= "number" then
			return false
		end
	end

	return next(Table) and true or false
end

local Enumerations = {}
local EnumerationsArray = SortedArray.new(nil, function(Left, Right)
	return tostring(Left) < tostring(Right)
end)

function Enumerations:GetEnumerations()
	return EnumerationsArray:Copy()
end

local function ReadOnlyNewIndex(_, Index, _)
	Debug.Error("Cannot write to index [%q]", Index)
end

local function CompareEnumTypes(EnumItem1, EnumItem2)
	return EnumItem1.Value < EnumItem2.Value
end

local EnumContainerTemplate = {}
EnumContainerTemplate.__index = {}

function EnumContainerTemplate.__index:GetEnumerationItems()
	return EnumContainerTemplate[self]:Copy()
end

local function EnumerationNameEquals(a, b)
	return a == b.Name
end

local function EnumerationNameLessThan(a, b)
	return a < b.Name
end

local function EnumerationValueEquals(a, b)
	return a == b.Value
end

local function EnumerationValueLessThan(a, b)
	return a < b.Value
end

function EnumContainerTemplate.__index:Cast(Value, DontError)
	local EnumTypes = EnumContainerTemplate[self]
	local ValueType = type(Value)

	if ValueType == "number" then
		if EnumTypes.IsValidArray then
			local Target = EnumTypes[Value + 1]

			if Target then
				return Target
			end
		else
			local Position = EnumTypes:Find(Value, EnumerationValueEquals, EnumerationValueLessThan)

			if Position then
				return EnumTypes[Position]
			end
		end
	elseif ValueType == "string" then
		if DontError then
			for i = 1, #EnumTypes do
				if EnumTypes[i].Name == Value then
					return self[Value]
				end
			end
		else
			return self[Value]
		end
	elseif ValueType == "userdata" then
		local Position = EnumTypes:Find(Value)

		if Position then
			return EnumTypes[Position]
		end
	end

	if DontError then
		return nil
	else
		Debug.Error("[%s] is not a valid " .. tostring(self), Value)
	end
end

local function ConstructUserdata(__index, __newindex, __tostring, SortedEnumTypes)
	local Enumeration = newproxy(true)

	local EnumerationMetatable = getmetatable(Enumeration)
	EnumerationMetatable.__index = function(_, Index) return __index[Index] or Debug.Error("[%q] is not a valid EnumerationItem", Index) end
	EnumerationMetatable.__newindex = __newindex
	EnumerationMetatable.__tostring = function() return __tostring end
	EnumerationMetatable.__metatable = "[Enumeration] Requested metatable is locked"

	EnumContainerTemplate[Enumeration] = SortedEnumTypes

	return Enumeration
end

local function MakeEnumeration(_, EnumType, EnumTypes)
	if type(EnumType) ~= "string" then Debug.Error("Cannot write to non-string key of Enumeration: %s", EnumType) end
	if type(EnumTypes) ~= "table" then Debug.Error("Expected array of string EnumerationItem Names, got %s", EnumType) end
	if Enumerations[EnumType] then Debug.Error("Enumeration of EnumType " .. EnumType .. " already exists") end

	local SortedEnumTypes = SortedArray.new(nil, CompareEnumTypes)
	local EnumContainer = setmetatable({}, EnumContainerTemplate)
	local LockedEnumContainer = ConstructUserdata(EnumContainer, ReadOnlyNewIndex, EnumType, SortedEnumTypes)
	local EnumerationStringStub = "Enumeration." .. EnumType .. "."

	if IsValidArray(EnumTypes) then
		SortedEnumTypes.IsValidArray = true
		for i = 1, #EnumTypes do
			local Name = EnumTypes[i]
			local Item = ConstructUserdata({
				EnumerationType = LockedEnumContainer;
				Name = Name;
				Value = i - 1;
			}, ReadOnlyNewIndex, EnumerationStringStub .. Name)

			SortedEnumTypes[i] = Item
			EnumContainer[Name] = Item
		end
	elseif IsValidDictionary(EnumTypes) then
		SortedEnumTypes.IsValidArray = false
		local Count = 0

		for Name, Value in next, EnumTypes do
			local Item = ConstructUserdata({
				EnumerationType = LockedEnumContainer;
				Name = Name;
				Value = Value;
			}, ReadOnlyNewIndex, EnumerationStringStub .. Name)

			Count = Count + 1
			SortedEnumTypes[Count] = Item
			EnumContainer[Name] = Item
		end

		SortedEnumTypes:Sort()
	else
		Debug.Error("Expected table " .. EnumType .. " to be an array of strings of the form {\"Type1\", \"Type2\", \"Type3\"} or a dictionary of the form {Type1 = 1; Type5 = 5}")
	end

	EnumerationsArray:Insert(LockedEnumContainer)
	Enumerations[EnumType] = LockedEnumContainer
end

return ConstructUserdata(Enumerations, MakeEnumeration, "Enumerations")
