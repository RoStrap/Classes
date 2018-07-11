-- Rigidly defined PseudoInstance class system based on Roblox classes

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Resources = require(ReplicatedStorage:WaitForChild("Resources"))

local Debug = Resources:LoadLibrary("Debug")
local Table = Resources:LoadLibrary("Table")
local Signal = Resources:LoadLibrary("Signal")
local Janitor = Resources:LoadLibrary("Janitor")
local SortedArray = Resources:LoadLibrary("SortedArray")
local Enumeration = Resources:LoadLibrary("Enumeration")

local Templates = Resources:GetLocalTable("Templates")
local Metatables = setmetatable({}, {__mode = "k"})

local function Metatable__index(self, i)
	self = Metatables[self] or self
	local Value = self.__rawdata[i]
	local ClassTemplate = self.__class

	if Value == nil then
		Value = ClassTemplate.Methods[i]
	else
		return Value
	end

	if Value == nil and not ClassTemplate.Properties[i] then
		local GetEventConstructorAndDestructorFunction = ClassTemplate.Events[i]
		if GetEventConstructorAndDestructorFunction ~= nil then
			local Event = Signal.new(GetEventConstructorAndDestructorFunction and GetEventConstructorAndDestructorFunction(self))
			self.Janitor:Add(Event, "Destroy")
			rawset(self, i, Event)
			return Event
		else
			Debug.Error("[%q] is not a valid Property of " .. tostring(self), i)
		end
	else
		return Value
	end
end

local function Metatable__newindex(this, i, v)
	local self = Metatables[this] or this
	local Type = self.__assigners and self.__assigners[i] or self.__class.Properties[i]

	if Type then
		local Bool = Type(self, v)

		if Bool == true then
			self:rawset(i, v)
		elseif Bool ~= nil then
			Debug.Error("Cannot set " .. i .. " to " .. tostring(v))
		end
	elseif self == this and self.__class.Internals[i] ~= nil then
		rawset(self, i, v)
	else
		Debug.Error(i .. " is not a modifiable property")
	end
end

local function Metatable__tostring(self)
	return (Metatables[self] or self).__class.ClassName
end

local function Metatable__rawset(self, Property, Value, Bool)
	self.__rawdata[Property] = Value

	if Bool then
		-- Add a means for controlling when exactly a property changed signal fires?
	end

	return self
end

local function Metatable__super(self, MethodName, ...)
	local Class = self.__class

	while Class.HasSuperclass do
		Class = Class.Superclass
		local Function = Class.Methods[MethodName]

		if Function ~= self.__class.Methods[MethodName] then
			return Function(self, ...)
		end
	end

	return Debug.Error("Could not find parent method " .. MethodName)
end

Enumeration.ValueType = {
	"String", "Number", "Boolean", "Table", "Coroutine", "EnumItem",
	"Axes", "BrickColor", "CFrame", "Color3", "ColorSequence", "Faces",
	"Reference", "NumberRange", "NumberSequence", "PathWaypoint", "PhysicalProperties",
	"Random", "Ray", "Rect", "Region3", "Region3int16", "TweenInfo", "UDim", "UDim2",
	"Vector2", "Vector3", "Vector3int16"
}

local ValueTypes = Enumeration.ValueType:GetEnumerationItems()

local PseudoInstance = {}

local TypeChecker = {
	[Enumeration.ValueType.Reference.Value] = function(_, Value)
		return Value == nil or typeof(Value) == "Instance"
	end;
}

local function Empty() end
local function CompareToString(a, b) return tostring(a) < tostring(b) end
local DataTableNames = SortedArray.new{"Events", "Methods", "Properties", "Internals"}
local MethodIndex = DataTableNames:Find("Methods")

local function Filter(this, self, ...)
	-- Filter out `this` and convert to `self`
	-- Try not to construct a table if possible (we keep it light up in here)

	local ArgumentCount = select("#", ...)

	if ArgumentCount > 2 then
		local Arguments
		for i = 1, ArgumentCount do
			if select(i, ...) == this then
				Arguments = {...} -- Create a table if absolutely necessary
				Arguments[i] = self

				for j = i + 1, ArgumentCount do -- Just loop through the rest normally if a table was already created
					if Arguments[j] == this then
						Arguments[j] = self
					end
				end

				return unpack(Arguments)
			end
		end
	else
		if this == ... then -- Optimize for most cases where they only returned a single parameter
			return self
		else
			return ...
		end
	end
end

-- Make properties of internal objects externally accessible
local function WrapProperties(self, Object, ...)
	for i = 1, select("#", ...) do
		local Property = select(i, ...)
		self.Properties[Property] = function(this, Value)
			local Object = this[Object]

			if Object then
				Object[Property] = Value
			end

			return true
		end
	end

	return self
end

function PseudoInstance.Register(_, ClassName, ClassData, Superclass)
	if type(ClassData) ~= "table" then Debug.Error("Register takes parameters (string ClassName, table ClassData, Superclass)") end

	for i = 1, #DataTableNames do
		local DataTableName = DataTableNames[i]

		if not ClassData[DataTableName] then
			ClassData[DataTableName] = {}
		end
	end

	local Enumerations = SortedArray.new(Enumeration:GetEnumerations(), CompareToString)

	for Property, ValueType in next, ClassData.Properties do
		if type(ValueType) ~= "function" then
			local Position = Enumerations:Find(ValueType)

			if Position then
				local EnumerationType = Enumerations[Position]

				ClassData.Properties[Property] = function(self, Value)
					self:rawset(Property, EnumerationType:Cast(Value))
				end
			else
				local Index = Enumeration.ValueType:Cast(ValueType).Value
				local TypeCheck = TypeChecker[Index]

				if not TypeCheck then
					local Type = ValueTypes[Index + 1].Name:lower()

					function TypeCheck(_, Value)
						return typeof(Value):lower() == Type
					end

					TypeChecker[Index] = TypeCheck
				end

				ClassData.Properties[Property] = TypeCheck
			end
		end
	end

	local Data = ClassData.Internals

	for _ = 1, 2 do
		for i = 1, #Data do
			Data[Data[i]] = false
			Data[i] = nil
		end
		Data = ClassData.Events
	end

	ClassData.Abstract = false

	for MethodName, Method in next, ClassData.Methods do -- Wrap to give internal access to private metatable members
		if Method == 0 then
			ClassData.Abstract = true
		else
			ClassData.Methods[MethodName] = function(self, ...)
				local this = Metatables[self]

				if this then -- External method call
					return Filter(this, self, Method(this, ...))
				else -- Internal method call
					return Method(self, ...)
				end
			end
		end
	end

	if Superclass == nil then
		Superclass = Templates.PseudoInstance
	end

	if Superclass then -- Copy inherited stuff into ClassData
		ClassData.HasSuperclass = true
		ClassData.Superclass = Superclass

		for a = 1, #DataTableNames do
			local DataTable = DataTableNames[a]
			local ClassTable = ClassData[DataTable]
			for i, v in next, Superclass[DataTable] do
				if not ClassTable[i] then
					ClassTable[i] = v == 0 and a == MethodIndex and Debug.Error(ClassName .. " failed to implement " .. i .. " from its superclass " .. Superclass.ClassName) or v
				end
			end
		end
	else
		ClassData.HasSuperclass = false
	end

	ClassData.Init = ClassData.Init or Empty
	ClassData.ClassName = ClassName
	ClassData.WrapProperties = WrapProperties
	local LockedClass = Table.Lock(ClassData)
	Templates[ClassName] = LockedClass
	return LockedClass
end

local function SortByName(a, b)
	return a.Name < b.Name
end

local function ParentalChange(self, Parent)
	local this = Metatables[Parent]

	if this then
		this.Children:Insert(self)
	end
end

local function ChildNameMatchesObject(ChildName, b)
	return ChildName == b.Name
end

local function ChildNamePrecedesObject(ChildName, b)
	return ChildName < b.Name
end

PseudoInstance:Register("PseudoInstance", { -- Generates a rigidly defined userdata class with `.new()` instantiator
	Internals = {"Children", "PropertyChangedSignals"};

	Properties = { -- Only Indeces within this table are writable, and these are the default values
		Archivable = Enumeration.ValueType.Boolean; -- Values written to these indeces must match the initial type (unless it is a function, see below)
		Parent = Enumeration.ValueType.Reference;
		Name = Enumeration.ValueType.String;
	};

	Events = {
		Changed = function(self)
			local Assigned = {}

			return function(Event)
				local CurrentClass = self.__class
				repeat
					for Property in next, CurrentClass.Properties do
						if not Assigned[Property] then -- Allow for overwriting Properties in child classes
							Assigned[Property] = self:GetPropertyChangedSignal(Property):Connect(function(Value)
								Event:Fire(Property, Value)
							end)
						end
					end
					CurrentClass = CurrentClass.HasSuperclass and CurrentClass.Superclass
				until not CurrentClass
			end, function()
				for Property, Connection in next, Assigned do
					Connection:Disconnect()
					Assigned[Property] = nil
				end
			end
		end;
	};

	Methods = {
		Clone = function(self)
			if self.Archivable then
				local CurrentClass = self.__class
				local New = Resources:LoadLibrary("PseudoInstance").new(CurrentClass.ClassName)

				repeat
					for Property in next, CurrentClass.Properties do
						if Property ~= "Parent" then
							local Old = self[Property]
							if Old ~= nil then
								if TypeChecker[Enumeration.ValueType.Reference.Value](nil, Old) then
									Old = Old:Clone()
								end

								New[Property] = Old
							end
						end
					end
					CurrentClass = CurrentClass.HasSuperclass and CurrentClass.Superclass
				until not CurrentClass

				return New
			else
				return nil
			end
		end;

		GetFullName = function(self)
			return (self.Parent and self.Parent:GetFullName() .. "." or "") .. self.Name
		end;

		IsDescendantOf = function(self, Grandparent)
			return self.Parent == Grandparent or self.Parent:IsDescendantOf(Grandparent)
		end;

		GetPropertyChangedSignal = function(self, String)
			if type(String) ~= "string" then Debug.Error("invalid argument 2: string expected, got %s", String) end
			local PropertyChangedSignal = self.PropertyChangedSignals[String]

			if not PropertyChangedSignal then
				local ClassTemplate = self.__class
				if not self.__class.Properties[String] then Debug.Error("%s is not a valid Property of PseudoInstance", String) end
				local Function -- Get previous setter function
				local CurrentClass = ClassTemplate
				repeat
					for Property, Func in next, CurrentClass.Properties do
						if Property == String then
							Function = Func
							break
						end
					end
					CurrentClass = CurrentClass.HasSuperclass and CurrentClass.Superclass
				until Function or not CurrentClass

				PropertyChangedSignal = Signal.new(function(Event)
					local assigners = self.__assigners

					if not assigners then
						assigners = {}
						self.__assigners = assigners
					end

					assigners[String] = function(this, Value)
						local Bool = Function(this, Value)
						if Bool then
							self:rawset(String, Value)
							Event:Fire(Value)
						end
						return Bool
					end
				end, function()
					self.__assigners[String] = nil
				end)

				self.PropertyChangedSignals[String] = PropertyChangedSignal
			end

			return PropertyChangedSignal
		end;

		FindFirstChild = function(self, ChildName, Recursive)
			local Children = self.Children

			if Recursive then
				for i = 1, #Children do
					local Child = Children[i]

					if Child.Name == ChildName then
						return Child
					end

					local Grandchild = Child:FindFirstChild(ChildName, Recursive)

					if Grandchild then
						return Grandchild
					end
				end
			else -- Much faster than recursive
				return Children:Find(ChildName, ChildNameMatchesObject, ChildNamePrecedesObject)
			end
		end;

		GetChildren = function(self)
			return self.Children:Copy()
		end;

		IsA = function(self, ClassName)
			local CurrentClass = self.__class

			repeat
				if ClassName == CurrentClass.ClassName then
					return true
				end
				CurrentClass = CurrentClass.HasSuperclass and CurrentClass.Superclass
			until not CurrentClass

			return ClassName == "<<</sc>>>" -- This is a reference to the old Roblox chat...
		end;

		Destroy = function(self)
			self.Archivable = false
			self.Parent = nil
			self.Janitor:Cleanup()
		end;
	};

	Init = function(self)
		local Name = self.__class.ClassName

		-- Default properties
		self.Name = Name
		self.Archivable = true

		-- Read-only
		self:rawset("ClassName", Name)

		-- Internals
		self.Children = SortedArray.new(nil, SortByName)
		self.PropertyChangedSignals = {}

		self:GetPropertyChangedSignal("Parent"):Connect(ParentalChange, self)
	end;
}, false)

local function superinit(self, ...)
	local CurrentClass = self.currentclass

	if CurrentClass.HasSuperclass then
		self.currentclass = CurrentClass.Superclass
	else
		self.currentclass = nil
		self.superinit = nil
	end

	CurrentClass.Init(self, ...)
end

function PseudoInstance.new(ClassName, ...)
	local Class = Templates[ClassName]

	if not Class then
		Resources:LoadLibrary(ClassName)
		Class = Templates[ClassName] or Debug.Error("Invalid ClassName")
	end

	if Class.Abstract then
		Debug.Error("Cannot instantiate an abstract " .. ClassName)
	end

	local self = newproxy(true)
	local Mt = getmetatable(self)

	for i, v in next, Class.Internals do
		Mt[i] = v
	end

	-- Internal members
	Mt.__class = Class
	Mt.__index = Metatable__index
	Mt.__rawdata = {}
	Mt.__newindex = Metatable__newindex
	Mt.__tostring = Metatable__tostring
	Mt.__assigners = false -- If somebody uses GetPropertyChangedSignal, then this will become an internal table of property setter functions
	Mt.__metatable = "[PseudoInstance] Locked metatable"
	Mt.__type = ClassName -- Calling `typeof` will error without having this value :/

	-- Internally accessible methods
	Mt.rawset = Metatable__rawset
	Mt.super = Metatable__super

	-- These two are only around for instantiation and are cleared after a successful and full instantiation
	Mt.superinit = superinit
	Mt.currentclass = Class

	-- Internally accessible cleaner
	Mt.Janitor = Janitor.new()

	Metatables[self] = setmetatable(Mt, Mt)

	Mt:superinit(...)
	Mt.Janitor:Add(self, "Destroy")

	return self
end

function PseudoInstance.Make(ClassName, Properties, ...)
	local Object = PseudoInstance.new(ClassName)
	local Parent = Properties.Parent

	if Parent then
		Properties.Parent = nil
	end

	for Property, Value in next, Properties do
		if type(Property) == "number" then
			Value.Parent = Object
		else
			Object[Property] = Value
		end
	end

	if Parent then
		Object.Parent = Parent
	end

	if ... then
		local Objects = {...}
		for a = 1, #Objects do
			local Object = Object:Clone()
			for Property, Value in next, Objects[a] do
				if type(Property) == "number" then
					Value.Parent = Object
				else
					Object[Property] = Value
				end
			end
			Object.Parent = not Object.Parent and Parent
			Objects[a] = Object
		end
		return Object, unpack(Objects)
	else
		return Object
	end
end

return Table.Lock(PseudoInstance)