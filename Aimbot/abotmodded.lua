--// Variables

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local RequiredDistance, Typing, Running, ServiceConnections, Animation, OriginalSensitivity = 2000, false, false, {}, nil, nil

local function DrawingNew(Type)
    local Success, Object = pcall(Drawing.new, Type)
    return Success and Object or nil
end

local function SafeGetRenderProperty(Object, Key)
    local Success, Value = pcall(function()
        return Object[Key]
    end)
    return Success and Value or nil
end

local function SafeSetRenderProperty(Object, Key, Value)
    pcall(function()
        Object[Key] = Value
    end)
end

-- Degrade detection for compatibility fallback
local Degrade, GetRenderProperty, SetRenderProperty = false, nil, nil

do
    local TemporaryDrawing = DrawingNew("Line")
    if TemporaryDrawing then
        GetRenderProperty = function(Object, Key)
            return SafeGetRenderProperty(Object, Key)
        end
        SetRenderProperty = function(Object, Key, Value)
            SafeSetRenderProperty(Object, Key, Value)
        end
        TemporaryDrawing:Remove()
    else
        Degrade = true
        GetRenderProperty = SafeGetRenderProperty
        SetRenderProperty = SafeSetRenderProperty
    end
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
        Color = Color3.fromRGB(255, 255, 255),
        OutlineColor = Color3.fromRGB(0, 0, 0),
        LockedColor = Color3.fromRGB(255, 150, 150)
    },

    Blacklisted = {},
    FOVCircle = DrawingNew("Circle"),
    FOVCircleOutline = DrawingNew("Circle")
}

local Environment = getgenv().Aimbot

-- Ensure FOV circles are hidden initially
SetRenderProperty(Environment.FOVCircle, "Visible", false)
SetRenderProperty(Environment.FOVCircleOutline, "Visible", false)

--// Core Functions

local function GetClosestPlayer()
    local Settings = Environment.Settings
    local LockPart = Settings.LockPart
    local PredictionMultiplierX = Settings.PredictionMultiplierX
    local PredictionMultiplierY = Settings.PredictionMultiplierY

    if not Environment.Locked then
        RequiredDistance = Environment.FOVSettings.Enabled and Environment.FOVSettings.Radius or 2000
        local ClosestPlayers = {}

        for _, Player in next, Players:GetPlayers() do
            local Character = Player.Character
            local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

            if Player ~= LocalPlayer and not table.find(Environment.Blacklisted, Player.Name) and Character and Character:FindFirstChild(LockPart) and Humanoid then
                local PartPosition = Character[LockPart].Position
                local TeamCheckOption = Environment.DeveloperSettings.TeamCheckOption

                if Settings.TeamCheck and Player[TeamCheckOption] == LocalPlayer[TeamCheckOption] then
                    continue
                end

                if Settings.AliveCheck and Humanoid.Health <= 0 then
                    continue
                end

                if Settings.WallCheck then
                    local BlacklistTable = LocalPlayer.Character:GetDescendants()
                    for _, Value in next, Character:GetDescendants() do
                        table.insert(BlacklistTable, Value)
                    end

                    if #Camera:GetPartsObscuringTarget({PartPosition}, BlacklistTable) > 0 then
                        continue
                    end
                end

                local Vector, OnScreen = Camera:WorldToViewportPoint(PartPosition)
                Vector = Vector2.new(Vector.X, Vector.Y)
                local Distance = (UserInputService:GetMouseLocation() - Vector).Magnitude

                if OnScreen then
                    table.insert(ClosestPlayers, {Player = Player, Distance = Distance, Position = PartPosition})
                end
            end
        end

        -- Sort by distance
        table.sort(ClosestPlayers, function(a, b) return a.Distance < b.Distance end)

        for _, PlayerData in next, ClosestPlayers do
            local PredictedPosition = PlayerData.Position

            -- Apply prediction if any of the multipliers are non-zero
            if PredictionMultiplierX ~= 0 or PredictionMultiplierY ~= 0 then
                local Velocity = Character[LockPart].Velocity
                PredictedPosition = PredictedPosition + Vector3.new(Velocity.X * PredictionMultiplierX, Velocity.Y * PredictionMultiplierY, 0)
            end

            local Vector, OnScreen = Camera:WorldToViewportPoint(PredictedPosition)
            Vector = Vector2.new(Vector.X, Vector.Y)

            if (UserInputService:GetMouseLocation() - Vector).Magnitude < RequiredDistance then
                RequiredDistance, Environment.Locked = PlayerData.Distance, PlayerData.Player
                break
            end
        end
    elseif (UserInputService:GetMouseLocation() - Vector2.new(Camera:WorldToViewportPoint(Environment.Locked.Character[LockPart].Position).X, Camera:WorldToViewportPoint(Environment.Locked.Character[LockPart].Position).Y)).Magnitude > RequiredDistance then
        Environment.Locked = nil
    end
end



Environment.Load = function() -- Add your loading logic if needed
end

return Environment
