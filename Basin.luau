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
	ItemType: any,
	Directory: Folder?,
	
	--[Methods]--
	New:			(ItemType: any, Amount: number) -> (BasinClass?, Success, Reason?),
	Pull:			(Amount: number?) -> (ObjectClass? | {ObjectClass}?, Success, Reason?),
	Reserve:	(Amount: number) -> (Success, Reason?),
	Destroy:	()							 -> (Success, Reason?)
}
export type BasinClass = typeof(setmetatable(
	{} :: BasinProperties,
	{}
))

local Object = {} 
Object.__index = Object

--[[
	Creates a new object in the specified object pool.
	This is not intended to be used manually, as it can cause
	bugs if used.
]]
function Object.New(ItemType: any, Basin: BasinClass): (Success, ObjectClass?, Reason?)
	local self: ObjectClass = setmetatable({} :: ObjectProperties, Object)

	self.ParentBasin = Basin
	self.Item = ItemType:Clone()
	self.InUse = false
	
	return true, self
end

--[[
	Pushes the object back into its parent object pool.
	Also pushes the item back to its parent object pool directory.

	If the object's item is an NPC, it will respawn it after
	being moved to the directory. If the object's item is a
	particle, then it will stop the particle after being moved
	to the directory.
]]
function Object:Push(): (Success, Reason?)
	self.Item.Parent = self.ParentBasin.Directory
	self.InUse = false
	--TODO: Add detection for if it's a particle emitter or NPC
	return true
end

local Basin = {}
Basin.__index = Basin

--[[
	Creates a new basin with the specified item type and the amount of objects.
	Returns nil and false if it goes wrong.
]]
function Basin.New(ItemType: any, Amount: number): (BasinClass?, Success, Reason?)
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
	self.ItemType = ItemType

	local CurrentObjectCount: number = 0
	local Pool = self.Pool
	while CurrentObjectCount < Amount do
		local 
			ObjSuccess: Success, 
			Obj: ObjectClass? = Object.New(ItemType, self)
		if not ObjSuccess then return nil, false, Reject("Failed to create object of item type '" .. tostring(ItemType) .. "'!") end
		Pool[#Pool + 1] = Obj :: ObjectClass
		CurrentObjectCount += 1
	end

	return self, true
end

--[[
	Pulls a specified number of objects from the basin. Will skip Objects that are InUse.
	Default amount is 1, so the first and only argument can remain empty if the user desires.
]]
function Basin:Pull(Amount: number?): (ObjectClass? | {ObjectClass}?, Success, Reason?)
	if not Amount or Amount < 0 then return nil, false, Reject("Cannot pull a negative number of objects!") end
	local AmountToPull: number = Amount or 1
	
	local Pulled: {ObjectClass} | ObjectClass = {}
	local AmountPulled: number = 0

	local Pool: {ObjectClass} = self.Pool
	local Index: number = 1
	while AmountPulled < AmountToPull do
		if Index > #Pool then return nil, false, Reject("Not enough avaliable objects in pool to pull " .. tostring(Amount) .. " objects!") end
		local Obj: ObjectClass = Pool[Index]

		if Obj.InUse then 
			Index += 1
			continue
		end

		if AmountToPull == 1 then
			Pulled = Obj
			Obj.InUse = true
			AmountPulled = 1
			break
		end

		Obj.InUse = true
		Pulled[#Pulled + 1] = Obj
		Index += 1
		AmountPulled += 1
	end
	
	if AmountPulled == AmountToPull then return Pulled, true end
	return nil, false, Reject("Failed to pull " .. tostring(Amount or 1) .. " objects from ObjectPool!")
end

--[[
	Updates the size of the basin. Note that shrinking the basin will result in objects
	being destroyed if they do not fit into the new basin size.	

	Note that by "update", this means the size of the basin will be set to the new amount.
]]
function Basin:Reserve(Amount: number): (Success, Reason?)
	if not Amount or Amount < 1 then return false, Reject("Reserve amount cannot be set to a value less than one.") end

	local Pool: {ObjectClass} = self.Pool
	if Amount > self.Size then
		local ItemType: any = self.ItemType
		local ObjCreated: number = 0

		while ObjCreated < (Amount - self.Size) do
			local ObjSuccess: Success, Obj: ObjectClass? = Object.New(ItemType, self)
			if not ObjSuccess then return false, Reject("Failed to create object of item type '" .. tostring(self.ItemType) .. "' while changing reserve size.") end
			Pool[#Pool + 1] = Obj :: ObjectClass
			ObjCreated += 1
		end

		return true
	end

	const clear: typeof(table.clear) = table.clear
	const remove: typeof(table.remove) = table.remove

	local ObjRemoved: number = 0
	local ToRemove: number = (#Pool - Amount)
	local Index: number = #Pool

	while ObjRemoved < ToRemove and Index >= 1 do
		local Obj = Pool[Index]
		
		if Obj.Item:IsA("Instance") then Obj.Item:Destroy() end
		Obj.Item = nil

		remove(Pool, Index)
		ObjRemoved += 1
		Index -= 1
	end

	if ObjRemoved == ToRemove then
		self.Size = Amount
		return true
	end

	return false, Reject("Failed to change the reserves of the target ObjectPool to " .. tostring(Amount) .. "!")
end

--[[
	Destroys the basin's contents, directory, and itself.
]]
function Basin:Destroy(): (Success, Reason?)
	self.Directory:Destroy()

	const clear: typeof(table.clear) = table.clear
	const remove: typeof(table.remove) = table.remove
	for Index: number, Obj: ObjectClass in pairs(self.Pool) do
		if Obj.Item then
			if Obj.Item:IsA("Instance") then Obj.Item:Destroy() end
			Obj.Item = nil
		end

		remove(self.Pool, Index)
	end

	clear(self)
	return true
end

return Basin
