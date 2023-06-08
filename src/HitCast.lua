local hitboxClass = require(script.Parent)

local HitCastHitbox = {}
HitCastHitbox.__index = HitCastHitbox

local attachmentName = "DmgPoint"
local debugFolder = workspace:FindFirstChild("Debug")
local debugMode = false

local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local active = {}

setmetatable(HitCastHitbox, hitboxClass)

local function GetList(part: BasePart, getDescendants: boolean | nil)
	return if getDescendants then part:GetDescendants() else part:GetChildren()
end

local function SetupAttachments(list)
	local attachments = {}
	
	for _, attachment in list do
		if attachment:IsA("Attachment") and attachment.Name == attachmentName then
			attachments[attachment] = attachment:GetAttribute("Radius")
		end
	end
	
	return attachments
end

function HitCastHitbox.new(part: BasePart, getDescendants: boolean | nil, attachments :{} | nil)
	attachments = if attachments then attachments else SetupAttachments(GetList(part, getDescendants))
	
	local self = hitboxClass.new(part)
	self.Attachments = next(attachments) and attachments or nil
	self.BasePart = part
	
	return setmetatable(self, HitCastHitbox)
end

function HitCastHitbox.Spawn(info) -- {BasePart, GetDescendants, Filter}
	local attachments = SetupAttachments(info.Attachments)
	
	local hitbox = HitCastHitbox.new(workspace.Terrain, info.GetDescendants, attachments)
	hitbox:Activate(info.Filter)
	hitbox.Signal:Connect(info.Callback)
	
	task.delay(info.Length, hitbox.Destroy, hitbox)
end

function HitCastHitbox.SpawnFromPart(info) -- {BasePart, GetDescendants, Filter}
	local hitbox = HitCastHitbox.new(info.BasePart, info.GetDescendants)
	hitbox:Activate(info.Filter)
	hitbox.Signal:Connect(info.Callback)

	task.delay(info.Length, hitbox.Destroy, hitbox)
end

function HitCastHitbox:DrawDebug(attachment, radius)
	if debugMode and not self.DebugParts[attachment] then
		local debugPart = Instance.new("Part")
		debugPart.Shape = Enum.PartType.Ball
		debugPart.Size = Vector3.new(radius)
		debugPart.Anchored = true
		debugPart.CanCollide = false
		debugPart.BrickColor = BrickColor.new("Really red")
		debugPart.Transparency = 0.75
		debugPart.CFrame = attachment.WorldCFrame
		debugPart.Material = Enum.Material.Neon
		debugPart.TopSurface = Enum.SurfaceType.Smooth
		debugPart.BottomSurface = Enum.SurfaceType.Smooth
		debugPart.Parent = debugFolder
		
		self.DebugParts[attachment] = debugPart
	elseif debugMode and self.DebugParts[attachment] then
		self.DebugParts[attachment].CFrame = attachment.WorldCFrame
	end
end

function HitCastHitbox:Activate(filter: {})
	filter = filter or {}
	
	self:HitStart(filter)
	
	active[self] = filter
end

function HitCastHitbox:Deactivate()
	self:HitStop()
	
	active[self] = nil
end

game:GetService("RunService").Heartbeat:Connect(function()
	for hitbox, filter in active do
		params.FilterDescendantsInstances = filter
		
		if hitbox.Attachments then
			for attachment, radius in hitbox.Attachments do
				local parts = workspace:GetPartBoundsInRadius(attachment.WorldPosition, radius, params)
				
				hitbox:DrawDebug(attachment, radius)
				
				for _, part in parts do
					if hitbox:Validate(part) then
						local model = part:FindFirstAncestorWhichIsA("Model")
						local humanoid = model:FindFirstChildWhichIsA("Humanoid")
						
						if not humanoid then continue end
	                    hitbox:Tag(model)
	                    hitbox.Signal:Fire(part, humanoid)
	                end
	            end
			end
		else
			local parts = workspace:GetPartsInPart(hitbox.BasePart, params)

			--hitbox:DrawDebug(attachment, radius)

			for _, part in parts do
				if hitbox:Validate(part) then
					local model = part:FindFirstAncestorWhichIsA("Model")
					local humanoid = model:FindFirstChildWhichIsA("Humanoid")

					if not humanoid then continue end
					hitbox:Tag(model)
					hitbox.Signal:Fire(part, humanoid)
				end
			end
		end
    end
end)

return HitCastHitbox
