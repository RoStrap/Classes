-- Replicated PseudoInstances
-- @author Validark
-- Notes:
--	Events of ReplicatedPseudoInstances should always be fired with LocalPlayer as the first parameter

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IsServer = RunService:IsServer()
local IsClient = RunService:IsClient()
local ReplicateToClients = IsServer and not IsClient -- Don't Replicate in SoloTestMode
local ReplicateToServer = not IsServer and IsClient

local Resources = require(ReplicatedStorage:WaitForChild("Resources"))
local Debug = Resources:LoadLibrary("Debug")
local Enumeration = Resources:LoadLibrary("Enumeration")
local SortedArray = Resources:LoadLibrary("SortedArray")
local PseudoInstance = Resources:LoadLibrary("PseudoInstance")

local Templates = Resources:GetLocalTable("Templates")

local RemoteEvent = Resources:GetRemoteEvent("PseudoInstanceReplicator")
local RemoteFunction = Resources:GetRemoteFunction("PseudoInstanceStartupVerify")

local ReplicatedInstances = {}
local LoadedPlayers = setmetatable({}, {__mode = "k"})

local function YieldUntilReadyToFire(Player, ...)
	repeat until LoadedPlayers[Player] or not wait()
	local Old = LoadedPlayers[Player]
	LoadedPlayers[Player] = Old + 1
	RemoteEvent:FireClient(Player, Old + 1, ...)
end

local function FireClient(Player, ...)
	local Old = LoadedPlayers[Player]

	if Old then
		LoadedPlayers[Player] = Old + 1
		RemoteEvent:FireClient(Player, Old + 1, ...)
	else
		coroutine.resume(coroutine.create(YieldUntilReadyToFire), Player, ...)
	end
end

local function FireAllClients(...)
	local Playerlist = Players:GetPlayers()

	for i = 1, #Playerlist do
		FireClient(Playerlist[i], ...)
	end
end

local ParentalDepths = {}

-- A SortedArray of Ids to objects sorted according to Parental depth
-- This will ensure that you don't replicate child instances and try to set their parents before the parents exist
local ReplicationOrder = SortedArray.new(nil, function(a, b)
	return ParentalDepths[a] < ParentalDepths[b]
end)

local function EqualParentalDepths(a, b)
	return ParentalDepths[a] == ParentalDepths[b]
end

local function IsDescendantOfAPlayer(Object)
	if Object.ClassName == "Player" then
		return Object
	else
		local Playerlist = Players:GetPlayers()
		for i = 1, #Playerlist do
			local Player = Playerlist[i]
			if Object:IsDescendantOf(Player) then
				return Player
			end
		end

		return false
	end
end

local function OnPropertyChanged(self, i)
	local v = self[i]
	local Id = self.__id

	if i == "Parent" then
		if v then
			local ReplicateToAllPlayers = v == Players or v == Workspace or v == ReplicatedStorage or v:IsDescendantOf(Workspace) or v:IsDescendantOf(ReplicatedStorage)
			local PlayerToReplicateTo

			if not ReplicateToAllPlayers then
				PlayerToReplicateTo = v:IsDescendantOf("Players") and IsDescendantOfAPlayer(v)
			end

			-- If replicating to the server, we want to cache these and replicate them upon player joining (conditional upon parent)
			if ReplicateToAllPlayers then
				-- Get parental depth and cache it
				local ParentalDepth = 0
				local Current = self

				repeat
					Current = Current.Parent
					ParentalDepth = ParentalDepth + 1
				until Current == nil

				local Position = ReplicationOrder:Find(Id, EqualParentalDepths)
				ParentalDepths[Id] = ParentalDepth

				if Position then
					ReplicationOrder:SortIndex(Position)
				else
					ReplicationOrder:Insert(Id)
				end

				ReplicatedInstances[Id] = self

				FireAllClients(self.__class.ClassName, Id, self.__rawdata)

				return
			elseif PlayerToReplicateTo then
				FireClient(PlayerToReplicateTo, self.__class.ClassName, Id, self.__rawdata)
			end
		end
		ReplicatedInstances[Id] = nil
	elseif ReplicatedInstances[Id] then
		FireAllClients(self.__class.ClassName, Id, i, v)
	else
		local PlayerToReplicateTo = v:IsDescendantOf("Players") and IsDescendantOfAPlayer(v)
		if PlayerToReplicateTo then
			FireClient(PlayerToReplicateTo, self.__class.ClassName, Id, i, v)
		end
	end
end

if ReplicateToClients then
	Players.PlayerAdded:Connect(function(Player)
		if RemoteFunction:InvokeClient(Player) then -- Yield until player loads
			local NumReplicationOrder = #ReplicationOrder

			for i = 1, NumReplicationOrder do
				local Id = ReplicationOrder[i]
				local self = ReplicatedInstances[Id]

				RemoteEvent:FireClient(Player, i, self.__class.ClassName, Id, self.__rawdata)
			end

			LoadedPlayers[Player] = NumReplicationOrder
		end
	end)

	RemoteEvent.OnServerEvent:Connect(function(Player, ClassName, Id, Event, ...) -- Fire events on the Server when they are fired on the client
		Event = (Templates[ClassName].Storage[Id] or Debug.Error("Object not found"))[Event]
		-- On the server, the first parameter will always be Player. This removes a duplicate.
		-- This also adds some security because a client cannot simply spoof it

		Event:Fire(Player, select(2, ...))
	end)
elseif ReplicateToServer then
	local OnClientEventNumber = 1 -- Guarenteed that this will resolve in the order in which replication is intended to occur

	RemoteEvent.OnClientEvent:Connect(function(EventNumber, ClassName, Id, RawData, Assigned) -- Handle objects being replicated to clients
		repeat until OnClientEventNumber == EventNumber or not wait()

		local Template = Templates[ClassName]

		if not Template then
			Resources:LoadLibrary(ClassName)
			Template = Templates[ClassName] or Debug.Error("Invalid ClassName")
		end

		local LocalTable = Template.Storage
		local Object = LocalTable[Id]

		if not Object then
			Object = PseudoInstance.new(ClassName, Id)
			LocalTable[Id] = Object
		end

		if Assigned == nil then
			for Property, Value in next, RawData do
				if Object[Property] ~= Value then
					Object[Property] = Value
				end
			end
		else
			Object[RawData] = Assigned
		end

		OnClientEventNumber = OnClientEventNumber + 1
	end)

	function RemoteFunction.OnClientInvoke()
		return true
	end
end

local Ids = 0 -- Globally shared Id for instances, would break beyond 2^53 instances ever

return PseudoInstance:Register("ReplicatedPseudoInstance", {
	Storage = false; -- Mark this Class as abstract
	Internals = {"__id"};
	Properties = {};
	Events = {};
	Methods = {
		Destroy = function(self)
			if self.__id then
				ReplicatedInstances[self.__id] = nil
				self.__class.Storage[self.__id] = nil
			end
			self:super("Destroy")
		end;
	};

	Init = function(self, Id)
		self:superinit()

		if ReplicateToClients then
			if not Id then
				Id = Ids + 1
				Ids = Id
			end
			self.Changed:Connect(OnPropertyChanged, self)
		elseif ReplicateToServer then
			if Id then
				for Event in next, self.__class.Events do
					if Event ~= "Changed" then
						self[Event]:Connect(function(...)
							RemoteEvent:FireServer(self.__class.ClassName, Id, Event, ...)
						end)
					end
				end
			end
		end

		if Id then
			(self.__class.Storage or Debug.Error(self.__class.ClassName .. " is an abstract class and cannot be instantiated"))[Id] = self
			self.__id = Id
			ReplicatedInstances[Id] = self
		end
	end;
})
