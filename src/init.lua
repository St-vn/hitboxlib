local hitboxClass = {}
hitboxClass.__index = hitboxClass

local signalClass = require(script.Parent.Signal)

local rayParams = RaycastParams.new()
rayParams.FilterDescendantsInstances = {}
rayParams.FilterType = Enum.RaycastFilterType.Whitelist

function hitboxClass.new(part)
	return setmetatable({
		Part = part,
		Signal = signalClass.new()
	}, hitboxClass)
end

function hitboxClass:DestroyDebugParts()
	if not self.DebugParts then return end
	
	for key, debugPart in self.DebugParts do
		self[key] = debugPart:Destroy()
	end
end

function hitboxClass:HitStart(filter: {})
	filter = filter or {self.Part.Parent}
	
	self.Hit = {}
	self.DebugParts = {}
	
	table.insert(filter, self.Part)
end

function hitboxClass:HitStop()
	self.Filter = nil
	self.Hit = nil
	
	self:DestroyDebugParts()
end

function hitboxClass:Validate(part: BasePart): boolean
	for model in self.Hit do
		if part:IsDescendantOf(model) then
			return false
		end
	end

	return true
end

function hitboxClass:Tag(model: Model)
	self.Hit[model] = true
end

function hitboxClass:Destroy()
	self:Deactivate()
	self.Signal:Destroy()

	for key in self do
		self[key] = nil
	end
end

local debugFolder = workspace:FindFirstChild("Debug")

if not debugFolder then
	debugFolder = Instance.new("Folder")
	debugFolder.Name = "Debug"
	debugFolder.Parent = workspace
end

return hitboxClass
