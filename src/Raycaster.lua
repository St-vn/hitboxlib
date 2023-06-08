local hitboxClass = require(script.Parent)
local runService = game:GetService("RunService")
local isServer = runService:IsServer()
local bigSteppa = if isServer then runService.Heartbeat else runService.RenderStepped

local raycaster = {}
raycaster.__index = raycaster

local debugMode = false
local debugFolder = workspace:FindFirstChild("Debug")

local previousTime = workspace:GetServerTimeNow()
local active = {}

local raycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = {}
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

setmetatable(raycaster, hitboxClass)

local function DrawPath(start, goal, segments)
	local path = {}
	local previousPosition = start
	
	for segment = 1, segments do
		local direction = goal - start:Lerp(goal, segment / segments)
		
		table.insert(path, {
			Origin = previousPosition,
			Direction = direction,
			Point0 = segment / segments,
			Point1 = (segment + 1) / segments
		})
		
		previousPosition += direction
	end
	
	return path
end

local function StraightLine(start, goal, oldAlpha, newAlpha)
	local origin = start:Lerp(goal, oldAlpha)
	local direction = start:Lerp(goal, newAlpha) - origin
	local raycast = workspace:Raycast(origin, direction, raycastParams)
	
	return origin + direction, raycast
end

function raycaster.new(info)
	local self = hitboxClass.new(info.Part)
	
	self.Start = info.Start
	self.Goal = info.Goal
	
	self.Length = info.Length
	self.CastTime = info.CastTime
	self.Segments = info.Segments or math.floor((info.Start - info.Goal).Magnitude / 10)
	
	return setmetatable(self, raycaster)
end

function raycaster:PivotTo(newCFrame)
	self.Part:PivotTo(newCFrame)
end

function raycaster:DestroyPart()
	if self.Part then
		self.Part:Destroy()
	end
end

function raycaster:Raycast(oldAlpha, newAlpha)
	local position, raycast = StraightLine(self.Start, self.Goal, oldAlpha, newAlpha)
	
	if raycast then
		local part = raycast.Instance
		local model = part:FindFirstAncestorWhichIsA("Model")
		local humanoid = model and model:FindFirstChildWhichIsA("Humanoid")

		self.Signal:Fire(part, humanoid, raycast.Position)
		task.defer(self.Destroy, self)

		return raycast.Position
	end
	
	return position
end

function raycaster:DrawDebug(start, goal)
	if self.DebugParts[1] then self.DebugParts[1]:Destroy() end
	
	local direction = (start - goal)

	local debugPart = Instance.new("Part")
	debugPart.CFrame = CFrame.lookAt(start, goal) + direction * 0.5
	debugPart.Size = Vector3.new(0.5, 0.5, direction.Magnitude)
	debugPart.Anchored = true
	debugPart.CanCollide = false
	debugPart.Color = Color3.new(0, 1, 0)
	debugPart.Material = Enum.Material.Neon
	debugPart.Transparency = 0.5
	debugPart.Parent = debugFolder
	
	self.DebugParts[1] = debugPart
end

function raycaster:Activate(filter: {})
	self:HitStart()
	filter = filter or {}
	
	for _, object in {self.Part, workspace.Debug, workspace.VFX} do
		table.insert(filter, object)
	end
	
	active[self] = filter
end

function raycaster:Deactivate()
	self:HitStop()
	self:DestroyPart()

	active[self] = nil
end

bigSteppa:Connect(function()
	local currentTime = workspace:GetServerTimeNow()
	
	for self, filter in active do
		raycastParams.FilterDescendantsInstances = filter
		
		local oldAlpha = (previousTime - self.CastTime) / self.Length
		local newAlpha = (currentTime - self.CastTime) / self.Length
		
		if newAlpha >= 1 then self:Destroy() continue end
		
		local position = self:Raycast(oldAlpha, newAlpha)
		
		if self.Part and position then
			self:DrawDebug(self, self.Part.Position, position)
			
			self:PivotTo(CFrame.lookAt(position, self.Goal))
		end
	end
	
	previousTime = currentTime
end)

return raycaster
