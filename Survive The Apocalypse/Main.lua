local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local cfg = {
	bat_hit_on = false,
	bat_hit_range = 50,
}

local function get_root(model)
	return model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("Torso")
		or model:FindFirstChildWhichIsA("BasePart")
end

local function is_player_character(model)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name == model.Name or player.Character == model then
			return true
		end
	end
	return false
end

local function is_alive(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return true
	end
	return humanoid.Health > 0
end

local function find_combat_tool(character)
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		local swing = tool:FindFirstChild("Swing")
		local hit_targets = tool:FindFirstChild("HitTargets")
		if swing and hit_targets then
			return tool, swing, hit_targets
		end
	end

	for _, child in ipairs(character:GetChildren()) do
		local swing = child:FindFirstChild("Swing")
		local hit_targets = child:FindFirstChild("HitTargets")
		if swing and hit_targets then
			return child, swing, hit_targets
		end
	end

	return nil
end

local function get_closest_zombie(characters, my_character, max_range)
	local my_root = get_root(my_character)
	if not my_root then
		return nil
	end

	local closest, closest_dist = nil, math.huge

	for _, child in ipairs(characters:GetChildren()) do
		if child ~= my_character and not is_player_character(child) and is_alive(child) then
			local root = get_root(child)
			if root then
				local dist = (my_root.Position - root.Position).Magnitude
				if dist <= max_range and dist < closest_dist then
					closest_dist = dist
					closest = child
				end
			end
		end
	end

	return closest
end

local Lib
do
	local ok_load, result = pcall(function()
		return loadstring(game:HttpGet("https://raw.githubusercontent.com/lec1e/Matcha-UI-Libraries/refs/heads/main/INS%20UI.lua"))()
	end)
	Lib = (ok_load and result) or INSui
end

if not Lib then
	error("[STA] INS ui failed to load — check HttpGet / INSui global")
end

local win = Lib:CreateWindow({
	title = "Survive the Apocalypse",
	subtitle = "Melee",
	size = Vector2.new(560, 420),
	menuKey = "p",
	configName = "sta_melee",
	configFolder = "sta_melee",
	checkboxStyle = true,
	smartFps = true,
	startOpen = true,
})

pcall(function()
	win:AddSettingsTab("cog")
end)

Lib:Category("COMBAT")
local tab = win:Tab("Melee", "swords")
local sec = tab:Section("Combat", "Left", "auto-swing closest zombie in range")

local melee_toggle = sec:Toggle("Enabled", false, function(on)
	cfg.bat_hit_on = on == true
end)
pcall(function()
	melee_toggle:AddKeybind("b", "Toggle")
end)

sec:Slider("Range", 50, 1, 1, 500, "studs", function(v)
	cfg.bat_hit_range = tonumber(v) or 50
end)

sec:Info("Press P to open/close. Keybind: B")

RunService.Heartbeat:Connect(function()
	if not cfg.bat_hit_on then
		return
	end

	local range = cfg.bat_hit_range or 50
	local characters = game.Workspace:FindFirstChild("Characters")
	if not characters then
		return
	end

	local character = characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
	if not (character and is_alive(character)) then
		return
	end

	local tool, swing, hit_targets = find_combat_tool(character)
	if not tool then
		return
	end

	local zombie = get_closest_zombie(characters, character, range)
	if not zombie then
		return
	end

	swing:FireServer()
	hit_targets:FireServer({ zombie })
end)
