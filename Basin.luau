--!strict
type Success	= boolean
type Reason		= string

local function Reject(Reason: Reason): Reason
	print(string.format("[Basin]: %s", Reason))
	return Reason
end

export type ObjectProperties = {
	--[Properties]--
	InUse: boolean,
	ParentBasin: BasinClass,
	Item: any,

	--[Methods]--
	New:	(ItemType: any, Pool: BasinClass) -> (Success, ObjectClass?, Reason?),
	Push: () -> (Success, Reason?)
}
export type ObjectClass = typeof(setmetatable(
	{} :: ObjectProperties,
	{}
))

export type BasinProperties = {
	--[Properties]--
	Size: number,
	Pool: {ObjectClass},
	Directory: Folder?,
	
	--[Methods]--
	New:			(ItemType: any, Amount: number) -> (Success, BasinClass, Reason?),
	Pull:			(Amount: number?) -> (Success, ObjectClass? | {ObjectClass}?, Reason?),
	Reserve:	(Amount: number) -> (Success, Reason?),
	Cleanup:  (Amount: number) -> (Success, Reason?),
	Destroy:	()							 -> (Success, Reason?)
}
export type BasinClass = typeof(setmetatable(
	{} :: BasinProperties,
	{}
))

local Object = {} 
Object.__index = Object

function Object.New(ItemType: any, Basin: BasinClass): (Success, ObjectClass?, Reason?)
	local self: ObjectClass = setmetatable({} :: ObjectProperties, Object)

	self.ParentBasin = Basin
	self.Item = ItemType:Clone()
	self.InUse = false
	
	return true, self
end

function Object:Push(): (Success, Reason?)
	self.Item.Parent = self.ParentBasin.Directory
	self.InUse = false
	-- Add detection for if it's a particle emitter or NPC
	return true
end

local Basin = {}
Basin.__index = Basin

function Basin.New(ItemType: any, Amount: number): (Success, BasinClass, Reason?)
	local self: BasinClass = setmetatable(
		{} :: BasinProperties,
		Basin
	)

	if not world.Hidden.ObjectPools then 
		local ObjectPoolsFolder = Folder.New()	
		ObjectPoolsFolder.Name = "ObjectPools"
		ObjectPoolsFolder.Parent = world.Hidden
	end

	local CreationTime = math.floor(os.clock() * 1000)
	local Directory = Folder.New()
	Directory.Parent = world.Hidden.ObjectPools
	Directory.Name = tostring(CreationTime)

	self.Size = Amount
	self.Pool = {}
	self.Directory = Directory

	local CurrentObjectCount: number = 1
	local Pool = self.Pool
	while CurrentObjectCount < Amount do
		Pool[#Pool + 1] = ItemType:Clone()	
		CurrentObjectCount += 1
	end

	return true, self
end

function Basin.Pull(Amount: number?): (Success, ObjectClass? | {ObjectClass}?, Reason?)
	return false, nil, Reject("Failed to pull " .. tostring(Amount or 1) .. " objects from ObjectPool!")
end

function Basin:Reserve(Amount: number): (Success, Reason?)
	return false, Reject("Failed to change the reserves of the target ObjectPool to " .. tostring(Amount) .. "!")
end

function Basin:Cleanup(Amount: number): (Success, Reason?)
	return false, Reject("Failed to clean up " .. tostring(Amount) .. " objects the target ObjectPool!")
end

function Basin:Destroy(): (Success, Reason?)
	return false, Reject("Failed to destroy the target ObjectPool!")
end

return Basin
