--// Variables

local RequiredDistance, Typing, Running, ServiceConnections, Animation, OriginalSensitivity = 2000, false, false, {}
local Connect, Disconnect, GetRenderProperty, SetRenderProperty = __index(game, "DescendantAdded").Connect

local Degrade = false

do
	xpcall(function()
		local TemporaryDrawing = Drawingnew("Line")
		GetRenderProperty = getupvalue(getmetatable(TemporaryDrawing).__index, 4)
		SetRenderProperty = getupvalue(getmetatable(TemporaryDrawing).__newindex, 4)
		TemporaryDrawing.Remove(TemporaryDrawing)
	end, function()
		Degrade, GetRenderProperty, SetRenderProperty = true, function(Object, Key)
			return Object[Key]
		end, function(Object, Key, Value)
			Object[Key] = Value
		end
	end)

	local TemporaryConnection = Connect(__index(game, "DescendantAdded"), function() end)
	Disconnect = TemporaryConnection.Disconnect
	Disconnect(TemporaryConnection)
end

--// Environment

getgenv().Aimbot = {
	DeveloperSettings = {
		UpdateMode = "RenderStepped",
		TeamCheckOption = "TeamColor",
		RainbowSpeed = 1 -- Bigger = Slower
	},

	Settings = {
		Enabled = true,

		TeamCheck = false,
		AliveCheck = true,
		WallCheck = false,

		OffsetToMoveDirection = false,
		OffsetIncrement = 15,

		Sensitivity = 0, -- Animation length (in seconds) before fully locking onto target
		Sensitivity2 = 3.5, -- mousemoverel Sensitivity

		LockMode = 1, -- 1 = CFrame; 2 = mousemoverel
		LockPart = "Head", -- Body part to lock on

		TriggerKey = Enum.UserInputType.MouseButton2,
		Toggle = false,

		-- New settings for prediction
		PredictionMultiplierX = 0, -- Horizontal prediction multiplier
		PredictionMultiplierY = 0  -- Vertical prediction multiplier
	},

	FOVSettings = {
		Enabled = true,
		Visible = true,

		Radius = 90,
		NumSides = 60,

		Thickness = 1,
		Transparency = 1,
		Filled = false,

		RainbowColor = false,
		RainbowOutlineColor = false,
		Color = Color3fromRGB(255, 255, 255),
		OutlineColor = Color3fromRGB(0, 0, 0),
		LockedColor = Color3fromRGB(255, 150, 150)
	},

	Blacklisted = {},
	FOVCircle = Drawingnew("Circle"),
	FOVCircleOutline = Drawingnew("Circle")
}

local Environment = getgenv().Aimbot

SetRenderProperty(Environment.FOVCircle, "Visible", false)
SetRenderProperty(Environment.FOVCircleOutline, "Visible", false)

--// Core Functions

local GetClosestPlayer = function()
	local Settings = Environment.Settings
	local LockPart = Settings.LockPart
	local PredictionMultiplierX = Settings.PredictionMultiplierX
	local PredictionMultiplierY = Settings.PredictionMultiplierY

	if not Environment.Locked then
		RequiredDistance = Environment.FOVSettings.Enabled and Environment.FOVSettings.Radius or 2000
		local ClosestPlayers = {}

		for _, Value in next, GetPlayers(Players) do
			local Character = __index(Value, "Character")
			local Humanoid = Character and FindFirstChildOfClass(Character, "Humanoid")

			if Value ~= LocalPlayer and not tablefind(Environment.Blacklisted, __index(Value, "Name")) and Character and FindFirstChild(Character, LockPart) and Humanoid then
				local PartPosition = __index(Character[LockPart], "Position")
				local TeamCheckOption = Environment.DeveloperSettings.TeamCheckOption

				if Settings.TeamCheck and __index(Value, TeamCheckOption) == __index(LocalPlayer, TeamCheckOption) then
					continue
				end

				if Settings.AliveCheck and __index(Humanoid, "Health") <= 0 then
					continue
				end

				if Settings.WallCheck then
					local BlacklistTable = GetDescendants(__index(LocalPlayer, "Character"))

					for _, Value in next, GetDescendants(Character) do
						BlacklistTable[#BlacklistTable + 1] = Value
					end

					if #GetPartsObscuringTarget(Camera, {PartPosition}, BlacklistTable) > 0 then
						continue
					end
				end

				local Vector, OnScreen, Distance = WorldToViewportPoint(Camera, PartPosition)
				Vector = ConvertVector(Vector)
				Distance = (GetMouseLocation(UserInputService) - Vector).Magnitude

				if OnScreen then
					table.insert(ClosestPlayers, {Player = Value, Distance = Distance, Position = PartPosition})
				end
			end
		end

		-- Sort by distance
		table.sort(ClosestPlayers, function(a, b) return a.Distance < b.Distance end)

		for _, PlayerData in next, ClosestPlayers do
			local PredictedPosition = PlayerData.Position

			-- Apply prediction if any of the multipliers are non-zero
			if PredictionMultiplierX ~= 0 or PredictionMultiplierY ~= 0 then
				local Velocity = __index(__index(PlayerData.Player, "Character")[LockPart], "Velocity")
				PredictedPosition = PredictedPosition + Vector3new(Velocity.X * PredictionMultiplierX, Velocity.Y * PredictionMultiplierY, 0)
			end

			local Vector, OnScreen = WorldToViewportPoint(Camera, PredictedPosition)
			Vector = ConvertVector(Vector)

			if (GetMouseLocation(UserInputService) - Vector).Magnitude < RequiredDistance then
				RequiredDistance, Environment.Locked = PlayerData.Distance, PlayerData.Player
				break
			end
		end
	elseif (GetMouseLocation(UserInputService) - ConvertVector(WorldToViewportPoint(Camera, __index(__index(__index(Environment.Locked, "Character"), LockPart), "Position")))).Magnitude > RequiredDistance then
		CancelLock()
	end
end



Environment.Load = Load -- Aimbot.Load()

setmetatable(Environment, {__call = Load})

return Environment
