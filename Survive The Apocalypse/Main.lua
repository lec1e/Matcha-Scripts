local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local cfg = {
	bat_hit_on = false,
	bat_hit_range = 50,
	attack_rate = 15,
	hits_per_attack = 2,
}

local cached_tool, cached_swing, cached_hit
local cached_char_addr
local accum = 0
local status = "idle"

local function addr(inst)
	if not inst then
		return nil
	end
	local ok, value = pcall(function()
		return inst.Address
	end)
	if ok then
		return value
	end
	return nil
end

local function get_root(model)
	if not model then
		return nil
	end
	return model:FindFirstChild("HumanoidRootPart")
		or model.PrimaryPart
		or model:FindFirstChild("Torso")
		or model:FindFirstChild("UpperTorso")
		or model:FindFirstChildWhichIsA("BasePart")
end

local function dist2(a, b)
	local dx = a.X - b.X
	local dy = a.Y - b.Y
	local dz = a.Z - b.Z
	return dx * dx + dy * dy + dz * dz
end

local function is_alive(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return true
	end
	local ok, health = pcall(function()
		return humanoid.Health
	end)
	if not ok then
		return true
	end
	return health > 0
end

local function player_name_set()
	local names = {}
	local list = Players:GetPlayers()
	for i = 1, #list do
		names[list[i].Name] = true
	end
	return names
end

local function find_combat_tool(character)
	local char_addr = addr(character)
	if cached_char_addr == char_addr and cached_swing and cached_hit then
		local ok = pcall(function()
			return cached_swing.Parent and cached_hit.Parent
		end)
		if ok and cached_swing.Parent and cached_hit.Parent then
			return cached_tool, cached_swing, cached_hit
		end
	end

	local bat = character:FindFirstChild("Bat")
	if bat then
		local swing = bat:FindFirstChild("Swing")
		local hit_targets = bat:FindFirstChild("HitTargets")
		if hit_targets then
			cached_char_addr, cached_tool, cached_swing, cached_hit = char_addr, bat, swing, hit_targets
			return bat, swing, hit_targets
		end
	end

	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		local swing = tool:FindFirstChild("Swing")
		local hit_targets = tool:FindFirstChild("HitTargets")
		if hit_targets then
			cached_char_addr, cached_tool, cached_swing, cached_hit = char_addr, tool, swing, hit_targets
			return tool, swing, hit_targets
		end
	end

	local children = character:GetChildren()
	for i = 1, #children do
		local child = children[i]
		local hit_targets = child:FindFirstChild("HitTargets")
		if hit_targets then
			local swing = child:FindFirstChild("Swing")
			cached_char_addr, cached_tool, cached_swing, cached_hit = char_addr, child, swing, hit_targets
			return child, swing, hit_targets
		end
	end

	cached_char_addr, cached_tool, cached_swing, cached_hit = char_addr, nil, nil, nil
	return nil
end

local function get_closest_zombie(characters, my_character, max_range, player_names)
	local my_root = get_root(my_character)
	if not my_root then
		status = "no my root"
		return nil
	end

	local my_pos = my_root.Position
	local my_addr = addr(my_character)
	local my_name = LocalPlayer.Name
	local best, best_d2 = nil, max_range * max_range
	local children = characters:GetChildren()

	for i = 1, #children do
		local child = children[i]
		local name = child.Name
		if name ~= my_name and not player_names[name] and addr(child) ~= my_addr and is_alive(child) then
			local root = get_root(child)
			if root then
				local d2 = dist2(my_pos, root.Position)
				if d2 <= best_d2 then
					best_d2 = d2
					best = child
				end
			end
		end
	end

	if best then
		status = string.format("target %s (%.1f)", best.Name, math.sqrt(best_d2))
	else
		status = "no zombie in range"
	end
	return best
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
local sec = tab:Section("Combat", "Left", "fires HitTargets with one closest zombie")

local melee_toggle = sec:Toggle("Enabled", false, function(on)
	cfg.bat_hit_on = on == true
	accum = 0
	status = on and "armed" or "idle"
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

sec:Label(function()
	return "Status: " .. tostring(status)
end)
sec:Info("Press P to open/close. Keybind: B")

local hb = RunService.Heartbeat
if not hb then
	error("[STA] RunService.Heartbeat missing")
end

local ok_conn, err_conn = pcall(function()
	hb:Connect(function(dt)
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

		local characters = Workspace:FindFirstChild("Characters")
		if not characters then
			status = "no Characters folder"
			return
		end

		local character = characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
		if not character then
			status = "no character"
			return
		end
		if not is_alive(character) then
			status = "character dead"
			return
		end

		local tool, swing, hit_targets = find_combat_tool(character)
		if not hit_targets then
			status = "no HitTargets (equip Bat)"
			return
		end

		local range = cfg.bat_hit_range or 50
		local zombie = get_closest_zombie(characters, character, range, player_name_set())
		if not zombie then
			return
		end

		local payload = { zombie }

		if swing then
			pcall(function()
				swing:FireServer()
			end)
		end

		local fired = 0
		for _ = 1, cfg.hits_per_attack do
			local ok = pcall(function()
				hit_targets:FireServer(payload)
			end)
			if ok then
				fired += 1
			end
		end

		if fired == 0 then
			status = "FireServer failed"
		else
			status = string.format("hit %s x%d", zombie.Name, fired)
		end
	end)
end)

if not ok_conn then
	error("[STA] Heartbeat:Connect failed — " .. tostring(err_conn))
end
