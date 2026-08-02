local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local cfg = {
	bat_hit_on = false,
	bat_hit_range = 50,
	attack_rate = 15,
	hits_per_attack = 2,
}

local cached_tool, cached_swing, cached_hit
local cached_char
local accum = 0

local function get_root(model)
	return model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("Torso")
		or model:FindFirstChildWhichIsA("BasePart")
end

local function is_alive(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return true
	end
	return humanoid.Health > 0
end

local function player_lookup()
	local by_name, by_model = {}, {}
	for _, player in ipairs(Players:GetPlayers()) do
		by_name[player.Name] = true
		local ch = player.Character
		if ch then
			by_model[ch] = true
		end
	end
	return by_name, by_model
end

local function find_combat_tool(character)
	if cached_char == character and cached_swing and cached_hit and cached_swing.Parent and cached_hit.Parent then
		return cached_tool, cached_swing, cached_hit
	end

	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		local swing = tool:FindFirstChild("Swing")
		local hit_targets = tool:FindFirstChild("HitTargets")
		if swing and hit_targets then
			cached_char, cached_tool, cached_swing, cached_hit = character, tool, swing, hit_targets
			return tool, swing, hit_targets
		end
	end

	for _, child in ipairs(character:GetChildren()) do
		local swing = child:FindFirstChild("Swing")
		local hit_targets = child:FindFirstChild("HitTargets")
		if swing and hit_targets then
			cached_char, cached_tool, cached_swing, cached_hit = character, child, swing, hit_targets
			return child, swing, hit_targets
		end
	end

	cached_char, cached_tool, cached_swing, cached_hit = character, nil, nil, nil
	return nil
end

local function get_closest_zombie(characters, my_character, max_range, by_name, by_model)
	local my_root = get_root(my_character)
	if not my_root then
		return nil
	end

	local my_pos = my_root.Position
	local closest, closest_dist = nil, max_range

	for _, child in ipairs(characters:GetChildren()) do
		if child ~= my_character and not by_model[child] and not by_name[child.Name] and is_alive(child) then
			local root = get_root(child)
			if root then
				local dist = (my_pos - root.Position).Magnitude
				if dist <= closest_dist then
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
	accum = 0
end)
pcall(function()
	melee_toggle:AddKeybind("b", "Toggle")
end)

sec:Slider("Range", 50, 1, 1, 500, "studs", function(v)
	cfg.bat_hit_range = tonumber(v) or 50
end)

sec:Slider("Attack Rate", 15, 1, 1, 40, "/s", function(v)
	cfg.attack_rate = math.max(1, math.floor(tonumber(v) or 15))
end)

sec:Slider("Hits / Attack", 2, 1, 1, 6, "x", function(v)
	cfg.hits_per_attack = math.max(1, math.floor(tonumber(v) or 2))
end)

sec:Info("Press P to open/close. Keybind: B")

RunService.Heartbeat:Connect(function(dt)
	if not cfg.bat_hit_on then
		accum = 0
		return
	end

	accum += dt
	local interval = 1 / math.max(1, cfg.attack_rate)
	if accum < interval then
		return
	end
	accum -= interval
	if accum > interval then
		accum = 0
	end

	local characters = workspace:FindFirstChild("Characters")
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

	local by_name, by_model = player_lookup()
	local zombie = get_closest_zombie(characters, character, cfg.bat_hit_range or 50, by_name, by_model)
	if not zombie then
		return
	end

	local payload = { zombie }
	swing:FireServer()
	for _ = 1, cfg.hits_per_attack do
		hit_targets:FireServer(payload)
	end
end)
