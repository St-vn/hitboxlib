-- still doesn't work properly

local hitboxClass = require(script.Parent)
local runService = game:GetService("RunService")
local isServer = runService:IsServer()
local step = if isServer then runService.Heartbeat else runService.RenderStepped

local boxCaster = {}
boxCaster.__index = boxCaster

local debugMode = false
local debugFolder = workspace:FindFirstChild("Debug")

local previousTime = workspace:GetServerTimeNow()
local active = {}

local boxParams = OverlapParams.new()
boxParams.FilterDescendantsInstances = {}
boxParams.FilterType = Enum.RaycastFilterType.Exclude

local rayParams = RaycastParams.new()
rayParams.FilterDescendantsInstances = {}
rayParams.FilterType = Enum.RaycastFilterType.Include

setmetatable(boxCaster, hitboxClass)

local function Distance(position1, position2)
	return (position1 - position2).Magnitude
end

local function DistanceCheck(self, origin, list)
	if #list > 0 then
		rayParams.FilterDescendantsInstances = list
		
		local closest = nil
		local closestPosition = nil
		
		table.sort(list, function(part1, part2)
			return Distance(part1.Position, origin) < Distance(part2.Position, origin)
		end)
		
		for i = 1, self.MaxTouch do
			local part = list[i]
			
			if not part then break end
			
			local distance = (part.Position - origin).Magnitude
			local result = workspace:Raycast(origin, part.Position - origin, rayParams)
			
			if result and self:Validate(part) then
				
				if not closest and result then
					closest = part
					
					closestPosition = result.Position
				end
				
				local model = part:FindFirstAncestorWhichIsA("Model")
				local humanoid = model and model:FindFirstChildWhichIsA("Humanoid")
				
				if model ~= workspace then -- filter baseplate method when
					self:Tag(model)
				end	
				
				self.TouchedParts += 1
				self.Signal:Fire(part, humanoid, result.Position)
				
				if self:HasReachedMaxTouch() then
					self:Deactivate()
					task.defer(self.Destroy, self)

					return
				end

			end
		end
		
		return closestPosition
	end
end

local function StraightLine(self, oldAlpha, newAlpha)
	local origin = self.Start:Lerp(self.Goal, oldAlpha)
	local newPosition = self.Start:Lerp(self.Goal, newAlpha)
	local direction = newPosition - origin
	local list = self:DrawBox(origin, newPosition, self.Size)
	
	--local boxcast = DistanceCheck(self, origin, newPosition, list)
	
	return DistanceCheck(self, origin, list) or (origin + direction)
end

function boxCaster.new(info)
	local self = hitboxClass.new(info.Part)
	
	self.Start = info.Start
	self.Goal = info.Goal
	self.Length = info.Length
	self.CastTime = info.CastTime
	
	self.Segments = info.Segments or math.floor((info.Start - info.Goal).Magnitude / 10)
	self.Size = info.Size or Vector2.new(1, 1)
	self.MaxTouch = info.MaxTouch or 1

	return setmetatable(self, boxCaster)
end

function boxCaster:PivotTo(newCFrame)
	self.Part:PivotTo(newCFrame)
end

function boxCaster:DrawBox(start, goal, size)
	local direction = (start - goal)

	local part = Instance.new("Part")
	part.CFrame = CFrame.lookAt(start, goal) + direction * 0.5
	part.Size = Vector3.new(size.X, size.Y, direction.Magnitude)
	part.Anchored = true
	part.CanCollide = false
	part.Color = Color3.new(0, 0, 1)
	part.Material = Enum.Material.Neon
	part.Transparency = if debugMode then 0.5 else 1
	part.Parent = debugFolder

	task.delay(.1, part.Destroy, part)

	return workspace:GetPartsInPart(part, boxParams)
end

--[[function boxCaster:DrawDebug(start, goal)
	if self.DebugParts[1] then self.DebugParts[1]:Destroy() end
	
	local direction = (start - goal)

	local debugPart = Instance.new("Part")
	debugPart.CFrame = CFrame.lookAt(start, goal) + direction * 0.5
	debugPart.Size = Vector3.new(self.Size.X, self.Size.Y, direction.Magnitude)
	debugPart.Anchored = true
	debugPart.CanCollide = false
	debugPart.Color = Color3.new(0, 1, 0)
	debugPart.Material = Enum.Material.Neon
	debugPart.Transparency = 1--if debugMode then 0.5 else 1
	debugPart.Parent = debugFolder
	
	self.DebugParts[1] = debugPart
end]]

function boxCaster:DestroyPart()
	if self.Part then
		self.Part:Destroy()
	end
end

function boxCaster:HasReachedMaxTouch()
	return not self.MaxTouch or (self.MaxTouch <= self.TouchedParts)
end

function boxCaster:Boxcast(oldAlpha, newAlpha)
	local endPosition = StraightLine(self, oldAlpha, newAlpha)
	
	--[[for i = 1, self.MaxTouch do
		local position, boxcast = StraightLine(self, oldAlpha, newAlpha)

		if boxcast and boxcast.Instance then
			--print(boxcast.Instance, boxcast.Instance.Parent)
			local part = boxcast.Instance
			local model = part:FindFirstAncestorWhichIsA("Model")
			local humanoid = model and model:FindFirstChildWhichIsA("Humanoid")

			self.TouchedParts += 1
			self:Tag(model)
			self.Signal:Fire(part, humanoid, boxcast.Position)

			if self:HasReachedMaxTouch() then
				self:Deactivate()
				task.defer(self.Destroy, self)
				
				return
			end

			return boxcast.Position
		end
	end]]
	
	return endPosition
end

function boxCaster:Activate(filter: {})
	self:HitStart(filter)
	self.TouchedParts = 0
	
	for _, object in {self.Part, workspace.Debug, workspace.VFX} do
		table.insert(filter, object)
	end
	
	if self.Part then
		self:PivotTo(CFrame.lookAt(self.Start, self.Goal))
	end

	active[self] = filter
end

function boxCaster:Deactivate()
	self:HitStop()
	self:DestroyPart()
	self.TouchedParts = nil

	active[self] = nil
end

step:Connect(function()
	local currentTime = workspace:GetServerTimeNow()
	local i = 1
	
	for self, filter in active do
		boxParams.FilterDescendantsInstances = filter

		local oldAlpha = (previousTime - self.CastTime) / self.Length
		local newAlpha = math.min(1, (currentTime - self.CastTime) / self.Length)
		
		if newAlpha >= 1 then
			self.Signal:Fire(nil, nil, self.Goal)
			self:Destroy()
			
			continue
		end

		local position = self:Boxcast(oldAlpha, newAlpha)
		
		--self:DrawDebug(self.Start:Lerp(self.Goal, oldAlpha), position)
		
		if self.Part and position then
			self:PivotTo(CFrame.lookAt(position, self.Goal))
		end
		
		self.Position = position
		
		i += 1
	end

	previousTime = currentTime
end)

return boxCaster
