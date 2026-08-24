if _G.hc_ragebot_unload then
	pcall(_G.hc_ragebot_unload)
end

local function hc_ragebot_main()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local UserInputService = game:GetService("UserInputService")

	local LP = Players.LocalPlayer
	local connections = {}
	local Lib, win

	local HITBOXES = { "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "Torso" }
	local TP_MODES = { "Sticky", "Strafe", "Random teleport", "Above", "Behind", "In Front", "Orbit" }

	local TP_WRITE_METHODS = { "Primitive", "CFrame", "Position", "Velocity", "Lerp", "WalkTo" }
	local VOID_METHODS = { "Pulse", "Experimental", "Bait", "Sky", "Under Map", "Flicker", "Random" }
	local ON_KILL_RETURNS = { "Position", "Void", "None" }
	local DEFAULT_TRACER_COLOR = Color3.fromRGB(0, 213, 255)
	local OFFSET_URL = "https://offsets.imtheo.lol/offsets.json"
	local OFFSET_CACHE_FILE = "hc_ragebot_offsets.json"
	local OFFSET_REFRESH_SEC = 300

	local OFFSET_FALLBACK = {
		["Roblox Version"] = "version-ddf602d9cfe44005",
		Offsets = {
			BasePart = { Primitive = 392 },
			Primitive = {
				Position = 236,
				Rotation = 200,
				AssemblyLinearVelocity = 248,
				AssemblyAngularVelocity = 260,
				Validate = 6,
				Flags = 438,
				Size = 444,
			},
			Instance = { This = 8, Name = 8, Parent = 104, ClassDescriptor = 24 },
			Player = { LocalPlayer = 304, ModelInstance = 664, UserId = 768 },
			Humanoid = { Health = 400, MaxHealth = 424, Walkspeed = 464, HumanoidRootPart = 1144 },
			FakeDataModel = { Pointer = 146250584, RealDataModel = 472 },
			DataModel = { PlaceId = 392, GameId = 384, Workspace = 344, JobId = 280 },
			Workspace = { World = 1008, CurrentCamera = 1176, FallenPartsDestroyHeight = 520 },
		},
	}

	local GAME_KIND = "hood_customs"
	local MOUSE_ARG = "MousePosUpdate"
	local SCRIPT_NAME = "Hood Ware"
	local GAME_TITLE = "Hood Customs"

	local function detect_game()
		local name = ""
		pcall(function()
			name = tostring(getgamename() or "")
		end)
		local gid = tostring(game.GameId)
		local pid = tostring(game.PlaceId)
		local lower = string.lower(name)

		if gid == "3634139746" or string.find(lower, "hood custom", 1, true) then
			return "hood_customs", "MousePosUpdate", "Hood Customs"
		end
		if gid == "10600465284" or string.find(lower, "des hood", 1, true) then
			return "des_hood", "MousePos", "Des Hood"
		end
		if gid == "9980242798" or pid == "78871371189272" or string.find(lower, "der hood", 1, true) then
			return "der_hood", "skid", "Der Hood"
		end

		local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
		if remotes and remotes:FindFirstChild("MainGameEvent") then
			return "des_hood", "MousePos", name ~= "" and name or "Des Hood"
		end
		if string.find(lower, "der", 1, true) and string.find(lower, "hood", 1, true) then
			return "der_hood", "skid", name
		end

		local ws_players = Workspace:FindFirstChild("Players")
		local has_chars = ws_players and ws_players:FindFirstChild("Characters")
		local has_main = ReplicatedStorage:FindFirstChild("MainEvent")
		if has_main and ws_players and not has_chars and not remotes then
			return "der_hood", "skid", name ~= "" and name or "Der Hood"
		end
		return "hood_customs", "MousePosUpdate", name ~= "" and name or "Hood Copies"
	end

	GAME_KIND, MOUSE_ARG, GAME_TITLE = detect_game()

	local function is_hood_customs()
		return GAME_KIND == "hood_customs"
	end

	local function is_des_hood()
		return GAME_KIND == "des_hood"
	end

	local function is_der_hood()
		return GAME_KIND == "der_hood"
	end

	local function uses_character_parts()
		return not is_hood_customs()
	end

	print("[HC] load", GAME_TITLE, GAME_KIND, getgamename(), LP and LP.Name)

	local function get_main_event()
		local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
		local main_game = remotes and remotes:FindFirstChild("MainGameEvent")
		if main_game then
			return main_game
		end
		return ReplicatedStorage:FindFirstChild("MainEvent")
	end

	local event = get_main_event()
	print("[HC] event", event and event:GetFullName() or "NIL", "mouse", MOUSE_ARG)

	local running = true
	local last_shoot = 0
	local last_reload = 0
	local last_stomp = 0
	local saved_cf = nil
	local return_cf = nil
	local kill_returned = false
	local status = "boot"
	local remote_status = event and "ready" or "no MainEvent"
	local selected_targets = {}
	local lplr_pos = nil
	local last_random_off = nil
	local last_random_t = 0
	local orbit_angle = 0
	local orbit_last_t = 0

	local cfg = {
		on = false,
		tp = true,
		face = true,
		tp_mode = "Sticky",
		tp_write = "CFrame",
		hard_snap = true,
		aggressive = true,
		mem_tp = true,
		mem_dual = true,
		mem_auto_refresh = true,
		radius = 3,
		y = 1,
		strafe_speed = 70,
		shoot = true,
		auto_target = true,
		hitbox = "Head",
		interval = 0,
		burst = 16,
		render_fire = false,
		pred = 0.14,
		pred_ping = 1.45,
		agg_mul = 1.35,
		air_pred = true,
		air_pred_mul = 2.45,
		air_intercept = true,
		ff_check = true,
		stomp = true,
		tp_back = true,
		stomp_h = 2.5,
		on_kill_return = "Position",
		void_hide = false,
		void_method = "Pulse",
		void_interval = 0.1,
		void_time = 0.1,
		void_pulse_spread = 20,
		void_exp_interval = 0.06,
		void_exp_time = 0.14,
		void_exp_spread = 80,
		void_exp_depth = 8e8,
		void_exp_look = true,
		void_exp_vel = true,
		void_bait_time = 0.35,
		void_bait_peek = 0.18,
		void_bait_offset = 12,
		void_bait_spread = 24,
		void_sky_height = 500,
		void_sky_spread = 12,
		void_sky_interval = 0.12,
		void_sky_time = 0.16,
		void_under_depth = 80,
		void_under_spread = 8,
		void_under_interval = 0.12,
		void_under_time = 0.16,
		void_flicker_speed = 0.04,
		void_flicker_time = 0.04,
		void_flicker_spread = 14,
		void_random_interval = 0.08,
		void_random_time = 0.1,
		no_void_kill = true,
		anti_loop = false,
		anti_loop_range = 20,
		anti_loop_jitter = true,
		anti_loop_vel = false,
		chase = true,
		attach_lead = 0.16,
		sticky_speed = 140,
		hit_tracers = true,
		tracer_life = 0.55,
		tracer_color = DEFAULT_TRACER_COLOR,
		tracer_thick = 1.5,
		status_box = true,
	}

	local active_attach_target = nil
	local hit_tracers = {}
	local last_tracer_t = 0

	local shoot_fail_streak = 0
	local last_mouse_pos = nil
	local void_hide_handle = nil
	local rage_handle = nil
	local void_pulse = false
	local void_pulse_until = 0
	local void_bait_peek = false
	local void_random_pick = nil
	local last_void_end = 0
	local void_safe_cf = nil
	local saved_fallen_height = nil
	local target_tracks = {}
	local closest_cache = { plr = nil, d = math.huge, t = 0 }
	local last_anti_jitter = 0
	local last_anti_vel = 0
	local no_void_kill_on = false
	local status_box = nil
	local status_box_lines = nil
	local last_cf_write_t = 0
	local attach_stamp = 0
	local _attach_wrote_frame = -1
	local _db_last_origin = nil
	local _db_last_live = nil
	local lerp_tp_state = { from = nil, to = nil, t0 = 0, dur = 0.08 }
	local Offsets = {
		ready = false,
		version = nil,
		source = nil,
		dumped_at = nil,
		status = "boot",
		base = 0,
		last_fetch = 0,
		last_err = nil,

		BasePart_Primitive = OFFSET_FALLBACK.Offsets.BasePart.Primitive,
		Primitive_Position = OFFSET_FALLBACK.Offsets.Primitive.Position,
		Primitive_Rotation = OFFSET_FALLBACK.Offsets.Primitive.Rotation,
		Primitive_LinVel = OFFSET_FALLBACK.Offsets.Primitive.AssemblyLinearVelocity,
		Primitive_AngVel = OFFSET_FALLBACK.Offsets.Primitive.AssemblyAngularVelocity,
		Primitive_Validate = OFFSET_FALLBACK.Offsets.Primitive.Validate,
		FakeDataModel_Pointer = OFFSET_FALLBACK.Offsets.FakeDataModel.Pointer,
		FakeDataModel_Real = OFFSET_FALLBACK.Offsets.FakeDataModel.RealDataModel,
		DataModel_Workspace = OFFSET_FALLBACK.Offsets.DataModel.Workspace,
		Player_LocalPlayer = OFFSET_FALLBACK.Offsets.Player.LocalPlayer,
		Player_ModelInstance = OFFSET_FALLBACK.Offsets.Player.ModelInstance,
		Humanoid_RootPart = OFFSET_FALLBACK.Offsets.Humanoid.HumanoidRootPart,
	}
	local prim_cache = {}

	local function chars_folder()
		local p = Workspace:FindFirstChild("Players")
		if not p then
			return nil
		end

		return p:FindFirstChild("Characters") or p
	end

	local function player_names()
		local t = {}
		for _, plr in Players:GetPlayers() do
			if plr ~= LP then
				t[#t + 1] = plr.Name
			end
		end
		table.sort(t)
		return t
	end

	local function find_player(name)
		if type(name) ~= "string" or name == "" or name == "(none)" then
			return nil
		end
		name = name:gsub("^%s+", ""):gsub("%s+$", "")
		for _, plr in Players:GetPlayers() do
			if plr.Name == name or plr.DisplayName == name then
				return plr
			end
		end
		local lower = string.lower(name)
		for _, plr in Players:GetPlayers() do
			if string.lower(plr.Name) == lower then
				return plr
			end
		end
	end

	local function hc_model(plr)
		if not plr then
			return nil
		end
		local folder = chars_folder()
		if folder then
			local m = folder:FindFirstChild(plr.Name)
			if m then
				return m
			end
		end
		return plr.Character
	end

	local function find_part(model, name)
		if not model then
			return nil
		end
		local p = model:FindFirstChild(name)
		if p then
			return p
		end
		for _, d in model:GetDescendants() do
			if d.Name == name then
				return d
			end
		end
	end

	local function special(plr)
		local m = hc_model(plr)
		if not m then
			return nil
		end

		if uses_character_parts() then
			return m
		end
		return m:FindFirstChild("SpecialParts") or m
	end

	local function hrp(plr)
		local s = special(plr)
		return find_part(s, "HumanoidRootPart")
			or find_part(hc_model(plr), "HumanoidRootPart")
			or (plr == LP and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"))
	end

	local function aim_part(plr, hitbox)
		hitbox = hitbox or "Head"
		local s = special(plr)
		local part = find_part(s, hitbox)
		if part then
			return part
		end
		part = find_part(s, "Head") or find_part(s, "UpperTorso") or find_part(s, "HumanoidRootPart")
		if part then
			return part
		end
		return hrp(plr)
	end

	local function body_effects(plr)
		local m = hc_model(plr)
		local be = m and m:FindFirstChild("BodyEffects")
		if be then
			return be
		end
		return plr and plr.Character and plr.Character:FindFirstChild("BodyEffects")
	end

	local function find_be_flag(be, names)
		if not be then
			return nil
		end
		for _, name in ipairs(names) do
			local f = be:FindFirstChild(name)
			if f then
				return f
			end
		end
		for _, d in be:GetDescendants() do
			for _, name in ipairs(names) do
				if d.Name == name then
					return d
				end
			end
		end
	end

	local function flag_true(f)
		if not f then
			return false
		end
		local v = f.Value
		return v == true or v == 1
	end

	local function ko_flag(plr)
		local be = body_effects(plr)
		return flag_true(find_be_flag(be, { "K.O", "Knocked", "KO", "Knock" }))
	end

	local function dead_flag(plr)
		local be = body_effects(plr)
		return flag_true(find_be_flag(be, { "Dead", "Death", "SDeath" }))
	end

	local function knocked(plr)
		if not plr or dead_flag(plr) then
			return false
		end
		if ko_flag(plr) then
			return true
		end
		return flag_true(find_be_flag(body_effects(plr), { "Grabbed", "Ragdoll", "Downed" }))
	end

	local function has_forcefield(plr)
		if not plr then
			return false
		end
		local function scan(model)
			if not model then
				return false
			end
			if model:FindFirstChildOfClass("ForceField") then
				return true
			end
			local ff = model:FindFirstChild("ForceField") or model:FindFirstChild("FF")
			if ff then
				return true
			end
			return false
		end
		if scan(hc_model(plr)) then
			return true
		end
		if plr.Character and scan(plr.Character) then
			return true
		end
		local be = body_effects(plr)
		if flag_true(find_be_flag(be, { "ForceField", "Forcefield", "FF", "SpawnProtection" })) then
			return true
		end
		return false
	end

	local function dead(plr)
		if not plr then
			return true
		end
		local m = hc_model(plr)
		if not m then
			return true
		end
		if dead_flag(plr) then
			return true
		end
		if ko_flag(plr) then
			return false
		end
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum then
			if hum.Health ~= nil and hum.Health <= 0 then
				return true
			end
			local ok, state = pcall(function()
				return hum:GetState()
			end)
			if ok and state == Enum.HumanoidStateType.Dead then
				return true
			end
		end
		return false
	end

	local function selected_list()
		local t = {}
		for name, on in pairs(selected_targets) do
			if on then
				t[#t + 1] = name
			end
		end
		table.sort(t)
		return t
	end

	local function selected_text()
		local t = selected_list()
		if #t == 0 then
			return "(none)"
		end
		if #t <= 4 then
			return table.concat(t, ", ")
		end
		return table.concat(t, ", ", 1, 4) .. " +" .. tostring(#t - 4)
	end

	local function selected_alive_count()
		local alive, dead_n = 0, 0
		for name in pairs(selected_targets) do
			local plr = find_player(name)
			if not plr or dead(plr) then
				dead_n = dead_n + 1
			else
				alive = alive + 1
			end
		end
		return alive, dead_n
	end

	local function dist_to(plr)
		local me = hrp(LP)
		local part = hrp(plr) or aim_part(plr, "UpperTorso") or aim_part(plr, "HumanoidRootPart")
		if not me or not part then
			return math.huge
		end
		return (part.Position - me.Position).Magnitude
	end

	local function prune_selected()
		for name in pairs(selected_targets) do
			if not find_player(name) then
				selected_targets[name] = nil
				print("[HC] removed left player:", name)
			end
		end
		for key in pairs(target_tracks) do
			local keep = false
			for _, plr in Players:GetPlayers() do
				if (plr.UserId or plr.Name) == key then
					keep = true
					break
				end
			end
			if not keep then
				target_tracks[key] = nil
			end
		end
	end

	local function set_targets_from_list(list)
		for n in pairs(selected_targets) do
			selected_targets[n] = nil
		end
		if type(list) ~= "table" then
			return
		end
		for _, name in ipairs(list) do
			if type(name) == "string" and name ~= "" and find_player(name) then
				selected_targets[name] = true
			end
		end
	end

	local function pick_closest_combat(prefer_alive, skip_ff)
		local best, best_d = nil, math.huge
		local best_ff, best_ff_d = nil, math.huge
		for _, plr in Players:GetPlayers() do
			if plr ~= LP and not dead(plr) then
				local is_ko = knocked(plr)
				if not (prefer_alive and is_ko) then
					local d = dist_to(plr)
					local ff = cfg.ff_check and has_forcefield(plr)
					if ff then
						if d < best_ff_d then
							best_ff_d = d
							best_ff = plr
						end
					elseif d < best_d then
						best_d = d
						best = plr
					end
				end
			end
		end
		if skip_ff then
			return best
		end
		return best or best_ff
	end

	local function pick_primary(prefer_alive, skip_ff)
		local best, best_d = nil, math.huge
		local best_ff, best_ff_d = nil, math.huge
		local any_sel = false
		for name in pairs(selected_targets) do
			any_sel = true
			local plr = find_player(name)
			if plr and not dead(plr) then
				local is_ko = knocked(plr)
				if not (prefer_alive and is_ko) then
					local d = dist_to(plr)
					local ff = cfg.ff_check and has_forcefield(plr)
					if ff then
						if d < best_ff_d then
							best_ff_d = d
							best_ff = plr
						end
					elseif d < best_d then
						best_d = d
						best = plr
					end
				end
			end
		end
		if not any_sel and cfg.auto_target ~= false then
			return pick_closest_combat(prefer_alive, skip_ff)
		end
		if skip_ff then
			return best
		end
		return best or best_ff
	end

	local function pick_knocked()
		local best, best_d = nil, math.huge
		for name in pairs(selected_targets) do
			local plr = find_player(name)
			if plr and knocked(plr) then
				local d = dist_to(plr)
				if d < best_d then
					best_d = d
					best = plr
				end
			end
		end
		return best
	end

	local function cf_xyz(x, y, z)
		return CFrame.new(x, y, z)
	end

	local function cf_look(pos, look)
		local yaw = math.atan2(-(look.X - pos.X), -(look.Z - pos.Z))
		return cf_xyz(pos.X, pos.Y, pos.Z) * CFrame.Angles(0, yaw, 0)
	end

	local function track_key(plr)
		if not plr then
			return nil
		end
		return plr.UserId or plr.Name
	end

	local function get_part_vel(part)
		local vx, vy, vz = 0, 0, 0
		pcall(function()
			local vel = part.AssemblyLinearVelocity or part.Velocity
			if vel then
				vx, vy, vz = vel.X, vel.Y, vel.Z
			end
		end)
		return vx, vy, vz
	end

	local function humanoid_of(plr)
		if not plr then
			return nil
		end
		local m = hc_model(plr)
		if m then
			local hum = m:FindFirstChildOfClass("Humanoid")
			if hum then
				return hum
			end
		end
		if plr.Character then
			return plr.Character:FindFirstChildOfClass("Humanoid")
		end
		return nil
	end

	local HIST_MAX = 14

	local function clamp_n(n, lo, hi)
		if n < lo then
			return lo
		end
		if n > hi then
			return hi
		end
		return n
	end

	local function detect_airborne(plr, part, vx, vy, vz, speed)
		local abs_vy = math.abs(vy or 0)
		speed = speed or 0
		if abs_vy >= 10 or speed >= 32 then
			return true
		end

		local hum = humanoid_of(plr)
		if hum then
			local air = false
			pcall(function()
				if hum.FloorMaterial == Enum.Material.Air then
					air = true
				end
			end)
			if air then
				return true
			end
			pcall(function()
				local st = hum:GetState()
				if
					st == Enum.HumanoidStateType.Freefall
					or st == Enum.HumanoidStateType.Flying
					or st == Enum.HumanoidStateType.Jumping
					or st == Enum.HumanoidStateType.FallingDown
				then
					air = true
				end
			end)
			if air then
				return true
			end
		end

		if part and abs_vy >= 6 and speed >= 18 then
			return true
		end
		return false
	end

	local function push_hist(tr, x, y, z, t)
		local h = tr.hist
		if not h then
			h = {}
			tr.hist = h
		end
		h[#h + 1] = { x = x, y = y, z = z, t = t }
		while #h > HIST_MAX do
			table.remove(h, 1)
		end
	end

	local function hist_velocity(tr)
		local h = tr.hist
		if not h or #h < 3 then
			return nil
		end
		local newest = h[#h]
		local oldest = h[1]
		for i = #h - 1, 1, -1 do
			if newest.t - h[i].t >= 0.12 then
				oldest = h[i]
				break
			end
		end
		local dt = newest.t - oldest.t
		if dt < 0.03 then
			return nil
		end
		local dx = newest.x - oldest.x
		local dy = newest.y - oldest.y
		local dz = newest.z - oldest.z
		local mag = math.sqrt(dx * dx + dy * dy + dz * dz)
		if mag > 700 then
			return nil
		end
		return dx / dt, dy / dt, dz / dt, mag / dt
	end

	local function update_target_track(plr, part, now)
		if not plr or not part then
			return nil
		end
		local key = track_key(plr)
		local pos = part.Position
		local tr = target_tracks[key]
		if not tr then
			tr = {
				px = pos.X,
				py = pos.Y,
				pz = pos.Z,
				sx = pos.X,
				sy = pos.Y,
				sz = pos.Z,
				vx = 0,
				vy = 0,
				vz = 0,
				ax = 0,
				ay = 0,
				az = 0,
				speed = 0,
				h_speed = 0,
				air = false,
				air_streak = 0,
				fast_air = false,
				t = now,
				spike = false,
				hist = {},
			}
			push_hist(tr, pos.X, pos.Y, pos.Z, now)
			target_tracks[key] = tr
			return tr
		end

		local dt = now - tr.t
		if dt <= 0.001 then
			return tr
		end
		if dt > 0.55 then
			tr.px, tr.py, tr.pz = pos.X, pos.Y, pos.Z
			tr.t = now
			tr.spike = false
			tr.hist = {}
			push_hist(tr, pos.X, pos.Y, pos.Z, now)
			return tr
		end

		local dx = pos.X - tr.px
		local dy = pos.Y - tr.py
		local dz = pos.Z - tr.pz
		local mag = math.sqrt(dx * dx + dy * dy + dz * dz)
		tr.t = now
		tr.px, tr.py, tr.pz = pos.X, pos.Y, pos.Z
		push_hist(tr, pos.X, pos.Y, pos.Z, now)

		if mag >= 650 or (typeof(pos.Y) == "number" and pos.Y < -50000) then
			tr.spike = true
			tr.hist = {}
			push_hist(tr, pos.X, pos.Y, pos.Z, now)
			return tr
		end

		local ivx, ivy, ivz = dx / dt, dy / dt, dz / dt
		local sample_speed = math.sqrt(ivx * ivx + ivy * ivy + ivz * ivz)

		local spike_cut = math.max(120, (tr.speed or 0) * 0.85 + 80)
		if tr.air or sample_speed > 55 then
			spike_cut = math.max(spike_cut, 280)
		end
		if mag >= spike_cut and sample_speed > 450 then
			tr.spike = true
			return tr
		end
		tr.spike = false
		local hvx, hvy, hvz, hspeed = hist_velocity(tr)
		if hvx then
			ivx = hvx * 0.72 + ivx * 0.28
			ivy = hvy * 0.72 + ivy * 0.28
			ivz = hvz * 0.72 + ivz * 0.28
			sample_speed = hspeed or sample_speed
		end

		local avx, avy, avz = get_part_vel(part)
		local av_speed = math.sqrt(avx * avx + avy * avy + avz * avz)
		if av_speed > 2 and av_speed < 400 then
			local trust_asm = 0.12
			if not detect_airborne(plr, part, ivx, ivy, ivz, sample_speed) and sample_speed < 40 then
				trust_asm = 0.4
			end
			local trust_delta = 1 - trust_asm
			ivx = ivx * trust_delta + avx * trust_asm
			ivy = ivy * trust_delta + avy * trust_asm
			ivz = ivz * trust_delta + avz * trust_asm
		end

		local prev_vx, prev_vy, prev_vz = tr.vx, tr.vy, tr.vz
		local air_guess = detect_airborne(plr, part, ivx, ivy, ivz, sample_speed) or tr.air or sample_speed > 38
		local blend = air_guess and 0.88 or 0.5
		local keep = 1 - blend
		tr.vx = prev_vx * keep + ivx * blend
		tr.vy = prev_vy * keep + ivy * blend
		tr.vz = prev_vz * keep + ivz * blend

		local inv_dt = 1 / math.max(dt, 0.008)
		local raw_ax = (tr.vx - prev_vx) * inv_dt
		local raw_ay = (tr.vy - prev_vy) * inv_dt
		local raw_az = (tr.vz - prev_vz) * inv_dt
		local a_blend = air_guess and 0.62 or 0.32
		tr.ax = tr.ax * (1 - a_blend) + raw_ax * a_blend
		tr.ay = tr.ay * (1 - a_blend) + raw_ay * a_blend
		tr.az = tr.az * (1 - a_blend) + raw_az * a_blend

		local a_cap = air_guess and 520 or 280
		tr.ax = clamp_n(tr.ax, -a_cap, a_cap)
		tr.ay = clamp_n(tr.ay, -a_cap, a_cap)
		tr.az = clamp_n(tr.az, -a_cap, a_cap)

		tr.h_speed = math.sqrt(tr.vx * tr.vx + tr.vz * tr.vz)
		tr.speed = math.sqrt(tr.vx * tr.vx + tr.vy * tr.vy + tr.vz * tr.vz)
		tr.air = detect_airborne(plr, part, tr.vx, tr.vy, tr.vz, tr.speed) or tr.speed >= 36
		if tr.air then
			tr.air_streak = math.min((tr.air_streak or 0) + 1, 180)
		else
			tr.air_streak = math.max((tr.air_streak or 0) - 3, 0)
			if tr.air_streak > 0 then
				tr.air = true
			end
		end
		tr.fast_air = tr.air and tr.speed >= 28
		tr.sx, tr.sy, tr.sz = pos.X, pos.Y, pos.Z
		return tr
	end

	local function extrapolate_pos(x, y, z, tr, lead)
		if not tr or lead <= 0 then
			return x, y, z
		end
		local half = 0.5 * lead * lead
		local use_accel = cfg.air_pred and (tr.air or tr.speed > 30)
		local ax = use_accel and (tr.ax or 0) or 0
		local ay = use_accel and (tr.ay or 0) or 0
		local az = use_accel and (tr.az or 0) or 0
		return x + (tr.vx or 0) * lead + ax * half,
			y + (tr.vy or 0) * lead + ay * half,
			z + (tr.vz or 0) * lead + az * half
	end

	local function air_intercept_time(tr, base_lead)
		base_lead = base_lead or cfg.attach_lead or 0.16
		if not tr or not cfg.air_pred then
			return base_lead
		end
		local speed = tr.speed or 0
		local mul = cfg.air_pred_mul or 2.25
		if not (tr.air or tr.fast_air or speed > 34) then
			return base_lead * (speed > 28 and 1.2 or 1)
		end

		local t = base_lead * mul
		t = t + speed / 220
		if math.abs(tr.vy or 0) > 20 then
			t = t + math.min(0.18, math.abs(tr.vy) / 400)
		end
		if cfg.air_intercept ~= false then
			t = math.max(t, 0.18 + speed / 280)
		end
		return clamp_n(t, 0.1, 0.85)
	end

	local function resolved_target_pos(plr, part, now, lead)
		local tr = update_target_track(plr, part, now)
		local px, py, pz = part.Position.X, part.Position.Y, part.Position.Z
		if not tr then
			return px, py, pz, 0
		end

		if cfg.chase then
			if typeof(py) == "number" and py < -50000 then
				px, py, pz = tr.sx, tr.sy, tr.sz
			end
			local t = lead or 0
			if t > 0 and (tr.air or tr.fast_air or (tr.speed or 0) > 30) then
				t = air_intercept_time(tr, t)
			elseif t > 0 and cfg.air_pred then
				t = t * (1 + math.min(1.2, (tr.speed or 0) / 70))
			end
			if t > 0 then
				px, py, pz = extrapolate_pos(px, py, pz, tr, t)
			end
		end
		return px, py, pz, tr.speed or 0, tr
	end

	local function mem_available()
		return typeof(memory_read) == "function" and typeof(memory_write) == "function"
	end

	local function get_inst_addr(inst)
		if not inst then
			return nil
		end
		local ok, addr = pcall(function()
			return inst.Address
		end)
		if ok and type(addr) == "number" and addr > 0x10000 then
			return addr
		end
		return nil
	end

	local function off_get(tbl, ns, name, fb)
		local bag = tbl and tbl[ns]
		local v = bag and bag[name]
		if type(v) == "number" then
			return v
		end
		return fb
	end

	local function apply_offset_table(data, source)
		if type(data) ~= "table" then
			return false
		end
		local offs = data.Offsets or data.offsets or data
		if type(offs) ~= "table" or not offs.BasePart or not offs.Primitive then
			return false
		end
		Offsets.version = data["Roblox Version"] or data.RobloxVersion or data.version or Offsets.version
		Offsets.source = source or data.Source or OFFSET_URL
		Offsets.dumped_at = data["Dumped At"] or data.DumpedAt
		Offsets.BasePart_Primitive = off_get(offs, "BasePart", "Primitive", Offsets.BasePart_Primitive)
		Offsets.Primitive_Position = off_get(offs, "Primitive", "Position", Offsets.Primitive_Position)
		Offsets.Primitive_Rotation = off_get(offs, "Primitive", "Rotation", Offsets.Primitive_Rotation)
		Offsets.Primitive_LinVel = off_get(offs, "Primitive", "AssemblyLinearVelocity", Offsets.Primitive_LinVel)
		Offsets.Primitive_AngVel = off_get(offs, "Primitive", "AssemblyAngularVelocity", Offsets.Primitive_AngVel)
		Offsets.Primitive_Validate = off_get(offs, "Primitive", "Validate", Offsets.Primitive_Validate)
		Offsets.FakeDataModel_Pointer = off_get(offs, "FakeDataModel", "Pointer", Offsets.FakeDataModel_Pointer)
		Offsets.FakeDataModel_Real = off_get(offs, "FakeDataModel", "RealDataModel", Offsets.FakeDataModel_Real)
		Offsets.DataModel_Workspace = off_get(offs, "DataModel", "Workspace", Offsets.DataModel_Workspace)
		Offsets.Player_LocalPlayer = off_get(offs, "Player", "LocalPlayer", Offsets.Player_LocalPlayer)
		Offsets.Player_ModelInstance = off_get(offs, "Player", "ModelInstance", Offsets.Player_ModelInstance)
		Offsets.Humanoid_RootPart = off_get(offs, "Humanoid", "HumanoidRootPart", Offsets.Humanoid_RootPart)
		Offsets.ready = true
		Offsets.last_err = nil
		prim_cache = {}
		return true
	end

	local function save_offset_cache(raw)
		if type(raw) ~= "string" or raw == "" then
			return
		end
		pcall(function()
			if typeof(writefile) == "function" then
				writefile(OFFSET_CACHE_FILE, raw)
			end
		end)
	end

	local function load_offset_cache()
		local raw
		pcall(function()
			if typeof(isfile) == "function" and isfile(OFFSET_CACHE_FILE) and typeof(readfile) == "function" then
				raw = readfile(OFFSET_CACHE_FILE)
			end
		end)
		if type(raw) ~= "string" or raw == "" then
			return false
		end
		local ok, data = pcall(function()
			return JSONDecode(raw)
		end)
		if ok and apply_offset_table(data, "cache:" .. OFFSET_CACHE_FILE) then
			Offsets.status = "cache " .. tostring(Offsets.version or "?")
			return true
		end
		return false
	end

	local function fetch_offsets_http()
		local raw
		local err
		local ok = pcall(function()
			if typeof(httpget) == "function" then
				raw = httpget(OFFSET_URL)
			elseif game and game.HttpGet then
				raw = game:HttpGet(OFFSET_URL)
			else
				error("no HttpGet")
			end
		end)
		if not ok or type(raw) ~= "string" or #raw < 20 then
			err = "HttpGet failed"
			return nil, err
		end
		local dec_ok, data = pcall(function()
			return JSONDecode(raw)
		end)
		if not dec_ok or type(data) ~= "table" then
			return nil, "JSONDecode failed"
		end
		save_offset_cache(raw)
		return data, nil
	end

	local function refresh_module_base()
		local b = 0
		pcall(function()
			if typeof(getbase) == "function" then
				b = tonumber(getbase()) or 0
			end
		end)
		Offsets.base = b
		return b
	end

	local function resolve_datamodel_addr()
		local base = Offsets.base
		if base <= 0 then
			base = refresh_module_base()
		end
		if base <= 0 or not mem_available() then
			return nil
		end
		local fake_ptr = Offsets.FakeDataModel_Pointer or 0
		if fake_ptr <= 0 then
			return nil
		end
		local ok, fake = pcall(function()
			return memory_read("uintptr_t", base + fake_ptr)
		end)
		if not ok or type(fake) ~= "number" or fake < 0x10000 then
			return nil
		end
		local ok2, real = pcall(function()
			return memory_read("uintptr_t", fake + (Offsets.FakeDataModel_Real or 472))
		end)
		if ok2 and type(real) == "number" and real > 0x10000 then
			return real
		end
		return nil
	end

	local function refresh_offsets(force, reason)
		reason = reason or "manual"
		local now = tick()
		if not force and Offsets.ready and (now - (Offsets.last_fetch or 0)) < 5 then
			return true
		end
		refresh_module_base()
		local data, err = fetch_offsets_http()
		if data and apply_offset_table(data, OFFSET_URL) then
			Offsets.last_fetch = now
			Offsets.status = "live " .. tostring(Offsets.version or "?")
			local rbx = nil
			pcall(function()
				if typeof(getrbxversion) == "function" then
					rbx = tostring(getrbxversion())
				end
			end)
			if rbx and Offsets.version and not string.find(tostring(rbx), tostring(Offsets.version), 1, true) then
				Offsets.status = Offsets.status .. " (client≠dump?)"
			end
			local dm = resolve_datamodel_addr()
			if dm then
				Offsets.status = Offsets.status .. " · DM ok"
			end
			print(
				"[HC] offsets",
				Offsets.status,
				"Primitive",
				Offsets.BasePart_Primitive,
				"Pos",
				Offsets.Primitive_Position,
				reason
			)
			return true
		end
		Offsets.last_err = err or "fetch fail"
		if not Offsets.ready then
			if load_offset_cache() then
				Offsets.last_fetch = now
				print("[HC] offsets from cache", Offsets.version)
				return true
			end
			apply_offset_table(OFFSET_FALLBACK, "fallback")
			Offsets.status = "fallback " .. tostring(Offsets.version)
			Offsets.last_fetch = now
			print("[HC] offsets fallback", Offsets.last_err)
			return true
		end
		Offsets.status = "stale " .. tostring(Offsets.version) .. " (" .. tostring(Offsets.last_err) .. ")"
		return false
	end

	refresh_offsets(true, "boot")

	local function mem_read_u64(addr)
		if not mem_available() or type(addr) ~= "number" or addr < 0x10000 then
			return nil
		end
		local ok, v = pcall(function()
			return memory_read("uintptr_t", addr)
		end)
		if ok and type(v) == "number" and v > 0x10000 then
			return v
		end
		return nil
	end

	local function mem_write_f32(addr, value)
		if not mem_available() or type(addr) ~= "number" then
			return false
		end
		local ok = pcall(function()
			memory_write("float", addr, value)
		end)
		return ok
	end

	local function mem_write_vec3(addr, x, y, z)
		if not addr then
			return false
		end
		local a = mem_write_f32(addr, x)
		local b = mem_write_f32(addr + 4, y)
		local c = mem_write_f32(addr + 8, z)
		return a and b and c
	end

	local function mem_read_vec3(addr)
		if not mem_available() or not addr then
			return nil
		end
		local okx, x = pcall(function()
			return memory_read("float", addr)
		end)
		local oky, y = pcall(function()
			return memory_read("float", addr + 4)
		end)
		local okz, z = pcall(function()
			return memory_read("float", addr + 8)
		end)
		if okx and oky and okz then
			return x, y, z
		end
		return nil
	end

	local function get_primitive(part)
		local addr = get_inst_addr(part)
		if not addr then
			return nil, nil
		end
		local now = tick()
		local cached = prim_cache[addr]
		if cached and (now - cached.t) < 1.5 and cached.prim then
			return cached.prim, addr
		end
		local prim = mem_read_u64(addr + (Offsets.BasePart_Primitive or 392))
		if prim then
			prim_cache[addr] = { prim = prim, t = now }
		end
		return prim, addr
	end

	local function write_primitive_cf(part, cf, carry_vel)
		if not part or not cf or not cfg.mem_tp then
			return false
		end
		if not Offsets.ready then
			refresh_offsets(false, "lazy")
		end
		local prim = get_primitive(part)
		if not prim then
			return false
		end
		local px, py, pz = cf.X, cf.Y, cf.Z
		pcall(function()
			local p = cf.Position
			px, py, pz = p.X, p.Y, p.Z
		end)

		local rot = Offsets.Primitive_Rotation or 200
		local pos = Offsets.Primitive_Position or 236
		local wrote_rot = false
		pcall(function()
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
			px, py, pz = x, y, z
			local m = { r00, r01, r02, r10, r11, r12, r20, r21, r22 }
			for i = 1, 9 do
				mem_write_f32(prim + rot + (i - 1) * 4, m[i])
			end
			wrote_rot = true
		end)
		local ok_pos = mem_write_vec3(prim + pos, px, py, pz)
		local vx, vy, vz = 0, 0, 0
		if carry_vel then
			vx = carry_vel.X or carry_vel[1] or 0
			vy = carry_vel.Y or carry_vel[2] or 0
			vz = carry_vel.Z or carry_vel[3] or 0
		end
		mem_write_vec3(prim + (Offsets.Primitive_LinVel or 248), vx, vy, vz)
		mem_write_vec3(prim + (Offsets.Primitive_AngVel or 260), 0, 0, 0)

		pcall(function()
			local voff = Offsets.Primitive_Validate or 6
			if voff > 0 then
				memory_write("byte", prim + voff, 0)
			end
		end)
		return ok_pos or wrote_rot
	end

	local function read_primitive_pos(part)
		local prim = get_primitive(part)
		if not prim then
			return nil
		end
		local x, y, z = mem_read_vec3(prim + (Offsets.Primitive_Position or 236))
		if x then
			return Vector3.new(x, y, z)
		end
		return nil
	end

	local function offsets_hud_line()
		local mem = mem_available() and "mem ok" or "mem OFF"
		local ver = tostring(Offsets.status or "?")
		return ver .. " | " .. mem
	end

	local function get_ping_sec()
		local ms = 60
		pcall(function()
			if typeof(GetPingValue) == "function" then
				ms = tonumber(GetPingValue()) or ms
			end
		end)
		if ms > 20 then
			if ms > 5 then
				return clamp_n(ms / 1000, 0.02, 0.35)
			end
		end
		return clamp_n(ms, 0.02, 0.35)
	end

	local function char_root()
		if LP.Character then
			local hum = LP.Character:FindFirstChildOfClass("Humanoid")
			local root = hum and hum.RootPart
			if root then
				return root, hum
			end
			local h = LP.Character:FindFirstChild("HumanoidRootPart")
			if h then
				return h, hum
			end
		end
		return hrp(LP), nil
	end

	local function is_flyable_pos(pos)
		if typeof(pos) ~= "Vector3" then
			return false
		end
		if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then
			return false
		end
		if math.abs(pos.X) > 22000 or math.abs(pos.Z) > 22000 then
			return false
		end
		if pos.Y < -80 or pos.Y > 25000 then
			return false
		end
		return true
	end

	local function is_hide_pos(pos)
		if typeof(pos) ~= "Vector3" then
			return false
		end
		if math.abs(pos.X) > 22000 or math.abs(pos.Z) > 22000 then
			return true
		end
		if pos.Y < -80 or pos.Y > 25000 or pos.Y < -50000 then
			return true
		end
		return false
	end

	local function collect_self_roots()
		local out = {}
		local seen = {}
		local function add(p)
			if not p then
				return
			end
			local key = get_inst_addr(p)
			if not key then
				local ok, n = pcall(function()
					return p:GetFullName()
				end)
				key = (ok and n) or tostring(p)
			end
			if seen[key] then
				return
			end
			seen[key] = true
			out[#out + 1] = p
		end
		local char = LP.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			add(hum and hum.RootPart)
			add(char:FindFirstChild("HumanoidRootPart"))
		end
		local m = hc_model(LP)
		if m then
			local hum2 = m:FindFirstChildOfClass("Humanoid")
			add(hum2 and hum2.RootPart)
			add(m:FindFirstChild("HumanoidRootPart"))
			local sp = m:FindFirstChild("SpecialParts")
			if sp then
				add(sp:FindFirstChild("HumanoidRootPart"))
				local sh = sp:FindFirstChildOfClass("Humanoid")
				add(sh and sh.RootPart)
			end
		end
		add(hrp(LP))
		return out
	end

	local function apply_cf(cf, carry_vel, force)
		if not cf then
			return false
		end
		local now = tick()

		if not force and cfg.aggressive ~= true and (now - last_cf_write_t) < 0.012 then
			return false
		end
		last_cf_write_t = now

		if cfg.mem_auto_refresh and Offsets.ready and (now - (Offsets.last_fetch or 0)) > OFFSET_REFRESH_SEC then
			task.spawn(function()
				refresh_offsets(true, "auto")
			end)
			Offsets.last_fetch = now
		end

		local ok = false
		local px, py, pz = cf.X, cf.Y, cf.Z
		pcall(function()
			local p = cf.Position
			px, py, pz = p.X, p.Y, p.Z
		end)
		local dest = Vector3.new(px, py, pz)
		local vx, vy, vz = 0, 0, 0
		if carry_vel then
			vx = carry_vel.X or carry_vel[1] or 0
			vy = carry_vel.Y or carry_vel[2] or 0
			vz = carry_vel.Z or carry_vel[3] or 0
		end
		local vel = Vector3.new(vx, vy, vz)
		local zero = Vector3.new()
		local method = cfg.tp_write or "CFrame"
		local want_mem = cfg.mem_tp == true and (cfg.tp_write == "Primitive" or cfg.mem_dual == true)

		if method == "Primitive" then
			method = "CFrame"
		end
		local root, hum = char_root()
		local me = hrp(LP)

		local function write_cf(part, use_cf)
			if not part then
				return
			end
			local use = use_cf or cf

			pcall(function()
				part.CFrame = use
			end)
			pcall(function()
				part.Position = dest
			end)
			pcall(function()
				part.AssemblyLinearVelocity = vel
				part.AssemblyAngularVelocity = zero
			end)
			pcall(function()
				part.Velocity = vel
				part.RotVelocity = zero
			end)
			ok = true
			if want_mem then
				write_primitive_cf(part, use, carry_vel)
			end
		end

		local function write_pos(part)
			if not part then
				return
			end
			if cfg.mem_tp then
				local cur = part.CFrame
				local use = CFrame.new(dest) * (cur - cur.Position)
				if write_primitive_cf(part, use, carry_vel) then
					ok = true
				end
			end
			pcall(function()
				local cur = part.CFrame
				part.CFrame = CFrame.new(dest) * (cur - cur.Position)
			end)
			pcall(function()
				part.Position = dest
			end)
			pcall(function()
				part.AssemblyLinearVelocity = vel
			end)
			ok = true
		end

		if method == "WalkTo" then
			if hum then
				pcall(function()
					hum.WalkToPoint = dest
				end)
				ok = true
			end
			for _, p in ipairs(collect_self_roots()) do
				write_cf(p, cf)
			end
			return ok
		end

		if method == "Velocity" and root then
			local cur = root.Position
			local delta = dest - cur
			local dist = delta.Magnitude
			if dist > 0.05 then
				local spd = math.max(80, (cfg.sticky_speed or 140) * 2.2)
				local dir = delta.Unit * math.min(spd, dist * 45)
				pcall(function()
					root.AssemblyLinearVelocity = dir
					root.Velocity = dir
				end)
				if cfg.mem_tp then
					local prim = get_primitive(root)
					if prim then
						mem_write_vec3(prim + (Offsets.Primitive_LinVel or 248), dir.X, dir.Y, dir.Z)
					end
				end
				if dist > 6 or force or cfg.hard_snap or cfg.aggressive then
					for _, p in ipairs(collect_self_roots()) do
						write_cf(p, cf)
					end
				end
				ok = true
				return ok
			end
		end

		if method == "Lerp" and root then
			local cur = root.CFrame
			local alpha = (force or cfg.hard_snap or cfg.aggressive) and 1 or 0.55
			local blended = cur
			pcall(function()
				blended = cur:Lerp(cf, alpha)
			end)
			for _, p in ipairs(collect_self_roots()) do
				write_cf(p, blended)
			end
			return ok
		end

		if method == "Position" then
			for _, p in ipairs(collect_self_roots()) do
				write_pos(p)
			end
			return ok
		end

		for _, p in ipairs(collect_self_roots()) do
			write_cf(p, cf)
		end
		return ok
	end

	local function mul_offset(tcf, ox, oy, oz)
		local ok, out = pcall(function()
			return tcf * CFrame.new(ox, oy, oz)
		end)
		if ok and out then
			return out
		end
		local p = tcf.Position
		local r, u, l = tcf.RightVector, tcf.UpVector, tcf.LookVector
		return cf_xyz(
			p.X + r.X * ox + u.X * oy - l.X * oz,
			p.Y + r.Y * ox + u.Y * oy - l.Y * oz,
			p.Z + r.Z * ox + u.Z * oy - l.Z * oz
		)
	end

	local function get_stick_part(plr)
		local sp = find_part(special(plr), "HumanoidRootPart")
		if sp and is_flyable_pos(sp.Position) then
			return sp
		end
		local model_root = find_part(hc_model(plr), "HumanoidRootPart")
		if model_root and is_flyable_pos(model_root.Position) then
			return model_root
		end
		if plr and plr.Character then
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			local rp = hum and hum.RootPart
			if rp and is_flyable_pos(rp.Position) then
				return rp
			end
			local ch = plr.Character:FindFirstChild("HumanoidRootPart")
			if ch and is_flyable_pos(ch.Position) then
				return ch
			end
			if rp then
				return rp
			end
			if ch then
				return ch
			end
		end
		return sp or model_root or hrp(plr)
	end

	local function row_toggle_on(handle, fallback)
		if handle then
			local ok, v = pcall(function()
				if handle.Get then
					return handle:Get()
				end
				return handle.Value
			end)
			if ok and v ~= nil then
				return v == true
			end
		end
		return fallback == true
	end

	local function rage_active()
		local on = row_toggle_on(rage_handle, cfg.on)
		cfg.on = on
		return on
	end

	local function void_hide_active()
		return row_toggle_on(void_hide_handle, cfg.void_hide)
	end

	local chat_typing_guess = false
	local typing_cache = false
	local typing_cache_at = 0

	local function rbx_window_active()
		if typeof(isrbxactive) == "function" then
			local ok, on = pcall(isrbxactive)
			if ok then
				return on == true
			end
		end
		return false
	end

	local function textchat_focused()
		local ok, focused = pcall(function()
			local tcs = game:GetService("TextChatService")
			if not tcs then
				return false
			end
			local conf = tcs.ChatInputBarConfiguration or tcs:FindFirstChild("ChatInputBarConfiguration")
			if not conf then
				return false
			end
			return conf.IsFocused == true
		end)
		return ok and focused == true
	end

	local function focused_textbox()
		local ok, box = pcall(function()
			return UserInputService:GetFocusedTextBox()
		end)
		return ok and box ~= nil
	end

	local function is_typing_in_game()
		local now = tick()
		if now - typing_cache_at < 0.12 then
			return typing_cache
		end
		typing_cache_at = now
		if not rbx_window_active() then
			chat_typing_guess = false
			typing_cache = false
			return false
		end
		typing_cache = focused_textbox() or textchat_focused() or chat_typing_guess
		return typing_cache
	end

	local function keybinds_allowed()
		if not rbx_window_active() then
			return false
		end
		if is_typing_in_game() then
			return false
		end
		return true
	end

	local function sync_bind_active(handle, on)
		if handle and handle.Bind then
			handle.Bind.Active = on == true
		end
	end

	local function on_gated_keybind(handle, active)
		if not handle then
			return
		end
		if not keybinds_allowed() then
			sync_bind_active(handle, handle.Value == true)
			return
		end
		active = active == true
		if handle.Value ~= active then
			handle.Value = active
			pcall(function()
				handle.Callback(active)
			end)
		else
			sync_bind_active(handle, active)
		end
	end

	local function keycode_of(input)
		if type(input) == "table" then
			return input.KeyCode
		end
		if input then
			return input.KeyCode
		end
		return nil
	end

	local function is_slash_key(code)
		if code == nil then
			return false
		end
		if code == 0xBF then
			return true
		end
		local ok, slash = pcall(function()
			return Enum.KeyCode.Slash
		end)
		return ok and code == slash
	end

	local function is_chat_end_key(code)
		if code == nil then
			return false
		end
		if code == 0x0D or code == 0x1B then
			return true
		end
		local ok, ret, esc = pcall(function()
			return Enum.KeyCode.Return, Enum.KeyCode.Escape
		end)
		return ok and (code == ret or code == esc)
	end

	local function set_no_void_kill(on)
		on = on == true
		if on == no_void_kill_on and (on or saved_fallen_height == nil) then
			return
		end
		no_void_kill_on = on
		pcall(function()
			if on then
				if saved_fallen_height == nil then
					saved_fallen_height = Workspace.FallenPartsDestroyHeight
				end
				Workspace.FallenPartsDestroyHeight = -9e9
			elseif saved_fallen_height ~= nil then
				Workspace.FallenPartsDestroyHeight = saved_fallen_height
				saved_fallen_height = nil
			else
				Workspace.FallenPartsDestroyHeight = -500
			end
		end)
	end

	local function is_void_y(y)
		return typeof(y) == "number" and y < -50000
	end

	local function remember_return_cf(me)
		if return_cf or not me then
			return
		end
		if is_void_y(me.Position.Y) then
			if void_safe_cf then
				return_cf = void_safe_cf
			end
			return
		end
		return_cf = me.CFrame
	end

	local function apply_kill_return(me, hold_void)
		local mode = cfg.on_kill_return or "Position"
		if mode == "None" then
			return false, mode
		end

		if mode == "Void" then
			if cfg.no_void_kill then
				set_no_void_kill(true)
			end
			local base = return_cf or void_safe_cf or saved_cf
			if not base and me and not is_void_y(me.Position.Y) then
				base = me.CFrame
			end
			if not base then
				return false, mode
			end
			local bx, by, bz = base.X, base.Y, base.Z
			lplr_pos = cf_xyz(bx + math.random(-15, 15), by - (9e9 - 1000), bz + math.random(-15, 15))
			apply_cf(lplr_pos, nil, true)
			if not hold_void then
				return_cf = nil
				saved_cf = nil
			end
			return true, mode
		end

		local cf = return_cf or saved_cf or void_safe_cf
		if not cf then
			return false, mode
		end
		lplr_pos = cf
		apply_cf(lplr_pos, nil, true)
		return_cf = nil
		saved_cf = nil
		return true, mode
	end

	local function safe_self_pos(me)
		if void_safe_cf and not is_void_y(void_safe_cf.Y) then
			return Vector3.new(void_safe_cf.X, void_safe_cf.Y, void_safe_cf.Z)
		end
		if me and not is_void_y(me.Position.Y) then
			return me.Position
		end
		if void_safe_cf then
			return Vector3.new(void_safe_cf.X, void_safe_cf.Y, void_safe_cf.Z)
		end
		if me then
			return me.Position
		end
		return nil
	end

	local function closest_player(me)
		local origin = safe_self_pos(me)
		if not origin then
			return nil, math.huge
		end
		local best, best_d = nil, math.huge
		for _, plr in Players:GetPlayers() do
			if plr ~= LP then
				local part = hrp(plr)
				if part then
					local p = part.Position
					if not is_void_y(p.Y) then
						local dx = p.X - origin.X
						local dz = p.Z - origin.Z
						local dy = p.Y - origin.Y
						local d = math.sqrt(dx * dx + dz * dz + (dy * dy) * 0.35)
						if d < best_d then
							best_d = d
							best = plr
						end
					end
				end
			end
		end
		return best, best_d
	end

	local function closest_player_cached(me, now)
		now = now or tick()
		if (now - closest_cache.t) < 0.1 then
			return closest_cache.plr, closest_cache.d
		end
		local plr, d = closest_player(me)
		closest_cache.plr = plr
		closest_cache.d = d
		closest_cache.t = now
		return plr, d
	end

	local function anti_loop_pressure(me, now, ignore_plr)
		if not cfg.anti_loop or not me then
			return false, nil, math.huge
		end
		local plr, d = closest_player_cached(me, now)
		if plr and ignore_plr and plr == ignore_plr then
			local origin = safe_self_pos(me)
			local best, best_d = nil, math.huge
			if origin then
				for _, other in Players:GetPlayers() do
					if other ~= LP and other ~= ignore_plr then
						local part = hrp(other)
						if part and not is_void_y(part.Position.Y) then
							local p = part.Position
							local dx = p.X - origin.X
							local dz = p.Z - origin.Z
							local dy = p.Y - origin.Y
							local od = math.sqrt(dx * dx + dz * dz + (dy * dy) * 0.35)
							if od < best_d then
								best_d = od
								best = other
							end
						end
					end
				end
			end
			plr, d = best, best_d
		end
		if not plr then
			return false, nil, math.huge
		end
		local range = cfg.anti_loop_range or 20
		if d <= range then
			return true, plr, d
		end
		return false, plr, d
	end

	local function apply_anti_vel(me, now)
		if not me or not cfg.anti_loop_vel then
			return
		end
		if (now - last_anti_vel) < 0.12 then
			return
		end
		last_anti_vel = now
		pcall(function()
			me.AssemblyLinearVelocity = Vector3.new()
			me.Velocity = Vector3.new()
		end)
	end

	local function apply_anti_jitter(base_cf, now)
		if not base_cf or not cfg.anti_loop_jitter then
			return false
		end
		if (now - last_anti_jitter) < 0.1 then
			return false
		end
		last_anti_jitter = now
		local bx, by, bz = base_cf.X, base_cf.Y, base_cf.Z
		local j = 1.5 + math.random() * 2
		local ang = math.random() * math.pi * 2
		apply_cf(cf_xyz(bx + math.cos(ang) * j, by, bz + math.sin(ang) * j), nil, true)
		return true
	end

	local function void_xyz(cf)
		local x, y, z = 0, 0, 0
		pcall(function()
			local p = cf.Position or cf
			x, y, z = p.X, p.Y, p.Z
		end)
		return x, y, z
	end

	local function void_cf_for(mode, base_cf)
		local bx, by, bz = void_xyz(base_cf)
		if type(by) ~= "number" then
			return nil
		end
		mode = mode or cfg.void_method or "Pulse"
		if mode == "Random" then
			local pool = { "Pulse", "Experimental", "Sky", "Under Map", "Flicker" }
			mode = pool[math.random(1, #pool)]
			void_random_pick = mode
		end
		if mode == "Sky" then
			local h = cfg.void_sky_height or 500
			local s = cfg.void_sky_spread or 12
			return cf_xyz(bx + math.random(-s, s), by + math.max(h, 50), bz + math.random(-s, s)), "sky"
		end
		if mode == "Under Map" then
			local d = cfg.void_under_depth or 80
			local s = cfg.void_under_spread or 8
			return cf_xyz(bx + math.random(-s, s), by - math.max(d, 10), bz + math.random(-s, s)), "under"
		end
		if mode == "Experimental" then
			local spread = cfg.void_exp_spread or 80
			local depth = cfg.void_exp_depth or 8e8
			local y = by - math.max(depth, 1000) + math.random(-40000, 40000)
			local out = cf_xyz(bx + math.random(-spread, spread), y, bz + math.random(-spread, spread))
			if cfg.void_exp_look then
				out = out
					* CFrame.Angles(
						math.rad(math.random(-180, 180)),
						math.rad(math.random(-180, 180)),
						math.rad(math.random(-40, 40))
					)
			end
			return out, "experimental"
		end
		if mode == "Bait" then
			local spread = cfg.void_bait_spread or 24
			return cf_xyz(bx + math.random(-spread, spread), by - (9e9 - 1000), bz + math.random(-spread, spread)),
				"bait"
		end
		if mode == "Flicker" then
			local spread = cfg.void_flicker_spread or 14
			return cf_xyz(bx + math.random(-spread, spread), by - (9e9 - 1000), bz + math.random(-spread, spread)),
				"flicker"
		end
		local spread = cfg.void_pulse_spread or 20
		return cf_xyz(bx + math.random(-spread, spread), by - (9e9 - 1000), bz + math.random(-spread, spread)), "void"
	end

	local function void_timing(mode, force_anti, manual)
		mode = mode or cfg.void_method or "Pulse"
		local interval, dur
		if mode == "Experimental" then
			interval, dur = cfg.void_exp_interval or 0.06, cfg.void_exp_time or 0.14
		elseif mode == "Bait" then
			interval, dur = cfg.void_bait_peek or 0.18, cfg.void_bait_time or 0.35
		elseif mode == "Sky" then
			interval, dur = cfg.void_sky_interval or 0.12, cfg.void_sky_time or 0.16
		elseif mode == "Under Map" then
			interval, dur = cfg.void_under_interval or 0.12, cfg.void_under_time or 0.16
		elseif mode == "Flicker" then
			interval, dur = cfg.void_flicker_speed or 0.04, cfg.void_flicker_time or 0.04
		elseif mode == "Random" then
			interval, dur = cfg.void_random_interval or 0.08, cfg.void_random_time or 0.1
		else
			interval, dur = cfg.void_interval or 0.1, cfg.void_time or 0.1
		end
		interval = type(interval) == "number" and interval or 0.1
		dur = type(dur) == "number" and dur or 0.1
		if force_anti and not manual then
			interval, dur = math.max(interval, 0.1), math.min(dur, 0.08)
		end
		return interval, dur
	end

	local function apply_void_hide(base_cf, now, force_anti)
		local manual = void_hide_active()
		if not manual and not force_anti then
			if void_pulse and void_safe_cf then
				apply_cf(void_safe_cf, nil, true)
			end
			void_pulse = false
			void_bait_peek = false
			return false, nil
		end

		if cfg.no_void_kill and not no_void_kill_on then
			set_no_void_kill(true)
		end

		if not base_cf then
			local me = hrp(LP)
			if not me then
				return false, nil
			end
			base_cf = me.CFrame
		end

		if not is_void_y(base_cf.Y) then
			void_safe_cf = base_cf
		elseif void_safe_cf then
			base_cf = void_safe_cf
		end

		local mode = cfg.void_method or "Pulse"
		local interval, dur = void_timing(mode, force_anti, manual)
		local last_end = last_void_end or 0

		if mode == "Bait" then
			if void_pulse then
				if now >= (void_pulse_until or 0) then
					void_pulse, last_void_end = false, now
					void_bait_peek = true
					local off = cfg.void_bait_offset or 12
					local ang = math.random() * math.pi * 2
					local bx, by, bz = void_xyz(void_safe_cf or base_cf)
					apply_cf(cf_xyz(bx + math.cos(ang) * off, by, bz + math.sin(ang) * off), nil, true)
					return false, "bait peek"
				end
			elseif void_bait_peek then
				if (now - last_end) < interval then
					local off = cfg.void_bait_offset or 12
					local bx, by, bz = void_xyz(void_safe_cf or base_cf)
					local ang = now * 2.2
					apply_cf(cf_xyz(bx + math.cos(ang) * off, by, bz + math.sin(ang) * off), nil, true)
					return false, "bait peek"
				end
				void_bait_peek = false
				void_pulse, void_pulse_until = true, now + dur
			elseif (now - last_end) >= interval then
				void_pulse, void_pulse_until = true, now + dur
			else
				return false, nil
			end
		elseif void_pulse then
			if now >= (void_pulse_until or 0) then
				void_pulse, last_void_end = false, now
				apply_cf(void_safe_cf or base_cf, nil, true)
				return false, "restore"
			end
		elseif (now - last_end) >= interval then
			void_pulse, void_pulse_until = true, now + dur
		else
			if force_anti and apply_anti_jitter(base_cf, now) then
				return false, "jitter"
			end
			return false, nil
		end

		if not void_pulse then
			return false, nil
		end

		if mode == "Experimental" and cfg.void_exp_vel then
			local me = hrp(LP)
			if me then
				pcall(function()
					me.AssemblyLinearVelocity = Vector3.new()
					me.AssemblyAngularVelocity = Vector3.new()
				end)
			end
		end

		local cf, tag = void_cf_for(mode, base_cf)
		if not cf then
			return false, nil
		end
		apply_cf(cf, nil, true)
		local label = tag or (force_anti and "anti-loop" or "void")
		if mode == "Random" and void_random_pick then
			label = "random/" .. tostring(void_random_pick)
		end
		return true, label
	end

	local function ray_filter(extra)
		local list = {}
		if LP.Character then
			list[#list + 1] = LP.Character
		end
		local m = hc_model(LP)
		if m and m ~= LP.Character then
			list[#list + 1] = m
		end
		local ignored = Workspace:FindFirstChild("Ignored")
		if ignored then
			list[#list + 1] = ignored
		end
		local cam = Workspace.CurrentCamera
		if cam then
			list[#list + 1] = cam
		end
		if extra then
			if typeof(extra) == "Instance" then
				list[#list + 1] = extra
			elseif type(extra) == "table" then
				for i = 1, #extra do
					if extra[i] then
						list[#list + 1] = extra[i]
					end
				end
			end
		end
		return list
	end

	local function has_los(from, to, target_model)
		if not from or not to then
			return false
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		params.FilterDescendantsInstances = ray_filter()
		local delta = to - from
		if delta.Magnitude < 0.05 then
			return true
		end
		local hit = Workspace:Raycast(from, delta, params)
		if not hit then
			return true
		end
		if (hit.Position - to).Magnitude <= 4 then
			return true
		end
		if target_model and hit.Instance and hit.Instance:IsDescendantOf(target_model) then
			return true
		end
		return false
	end

	local function mode_attach_cf(th, target, mode, h, v, anchor_pos)
		local tcf = th.CFrame
		local tpos = anchor_pos or th.Position
		local r, u, l = tcf.RightVector, tcf.UpVector, tcf.LookVector
		local ox, oy, oz = 0, v, h
		local now = tick()
		local moving = (mode == "Orbit" or mode == "Strafe")

		if mode == "In Front" then
			oz = -h
		elseif mode == "Above" then
			ox, oy, oz = 0, h + v, 0
		elseif moving then
			local frame = math.floor(now * 240)
			if attach_stamp ~= frame then
				if orbit_last_t <= 0 then
					orbit_last_t = now
				end
				local dt = now - orbit_last_t
				if dt < 0 then
					dt = 0
				elseif dt > 0.05 then
					dt = 0.05
				end
				orbit_last_t = now
				local speed = cfg.strafe_speed or 70
				orbit_angle = (orbit_angle or 0) + (speed / math.max(h, 1)) * dt
				attach_stamp = frame
			end
			local pos = Vector3.new(tpos.X + math.cos(orbit_angle) * h, tpos.Y + v, tpos.Z + math.sin(orbit_angle) * h)
			if cfg.face then
				return cf_look(pos, tpos)
			end
			return cf_xyz(pos.X, pos.Y, pos.Z)
		elseif mode == "Random teleport" or mode == "Random" then
			if (not last_random_off) or (now - last_random_t) >= 0.08 then
				last_random_off = {
					x = (math.random() * 2 - 1) * h,
					y = (math.random() * 2 - 1) * math.min(math.abs(v), 3),
					z = (math.random() * 2 - 1) * h,
				}
				last_random_t = now
			end
			ox, oy, oz = last_random_off.x, v + last_random_off.y, last_random_off.z
		else
			oz = h
			oy = v
		end

		local wx = tpos.X + r.X * ox + u.X * oy - l.X * oz
		local wy = tpos.Y + r.Y * ox + u.Y * oy - l.Y * oz
		local wz = tpos.Z + r.Z * ox + u.Z * oy - l.Z * oz
		local pos = Vector3.new(wx, wy, wz)
		if cfg.face then
			return cf_look(pos, tpos)
		end
		return cf_xyz(wx, wy, wz)
	end

	local function pick_open_cf(th, target, mode, h, v)
		local tpos = th.Position
		local model = hc_model(target) or (target and target.Character)
		local aim = tpos + Vector3.new(0, 1.4, 0)
		local function try_pos(pos)
			local eye = pos + Vector3.new(0, 1.35, 0)
			if not has_los(eye, aim, model) then
				return nil
			end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.IgnoreWater = true
			params.FilterDescendantsInstances = ray_filter({ model })
			local to_cand = pos - tpos
			local td = to_cand.Magnitude
			if td > 0.5 then
				local block = Workspace:Raycast(aim, to_cand.Unit * math.min(td, h + 2), params)
				if block and (block.Position - pos).Magnitude > 3 then
					return nil
				end
			end
			local cf = CFrame.new(pos)
			if cfg.face then
				cf = cf_look(pos, tpos)
			end
			return cf
		end

		if mode ~= "Random teleport" and mode ~= "Random" then
			local cf = mode_attach_cf(th, target, mode, h, v)
			local eye = cf.Position + Vector3.new(0, 1.35, 0)
			if has_los(eye, aim, model) then
				return cf
			end
		end

		if mode == "Random teleport" or mode == "Random" then
			local radii = { math.max(2, h * 0.35), math.max(3, h * 0.6), h, h }
			for ri = 1, #radii do
				local rad = radii[ri]
				for _ = 1, 8 do
					local ang = math.random() * math.pi * 2
					local oy = 1.5 + math.random() * math.max(0.5, math.abs(v))
					local pos = tpos + Vector3.new(math.cos(ang) * rad, oy, math.sin(ang) * rad)
					local cf = try_pos(pos)
					if cf then
						return cf
					end
				end
			end
			local fallback = tpos + Vector3.new(0, math.max(2.5, math.abs(v)), 3)
			return try_pos(fallback) or cf_look(fallback, tpos)
		end

		local now = tick()
		if orbit_last_t <= 0 then
			orbit_last_t = now
		end
		local dt = now - orbit_last_t
		if dt < 0 then
			dt = 0
		elseif dt > 0.05 then
			dt = 0.05
		end
		orbit_last_t = now
		local speed = cfg.strafe_speed or 50
		orbit_angle = (orbit_angle or 0) + clamp_n(speed * 15 * dt, 0, 360)
		if orbit_angle > 360 then
			orbit_angle = orbit_angle - 360
		end
		for step = 0, 11 do
			local ang = orbit_angle + step * 30
			local base = tpos + Vector3.new(0, v, 0)
			local ring = CFrame.Angles(0, math.rad(ang), 0) * CFrame.new(0, 0, h)
			local rp = ring.Position
			local pos = Vector3.new(base.X + rp.X, base.Y + rp.Y, base.Z + rp.Z)
			local cf = try_pos(pos)
			if cf then
				orbit_angle = ang % 360
				return cf
			end
		end
		local fallback = tpos + Vector3.new(0, math.max(2.5, math.abs(v)), 0)
		return try_pos(fallback) or cf_look(fallback, tpos)
	end

	local function lerp_cf(a, b, t)
		if not b then
			return a
		end
		if not a or t >= 1 then
			return b
		end
		if t <= 0 then
			return a
		end
		local ok, out = pcall(function()
			return a:Lerp(b, t)
		end)
		return (ok and out) or b
	end

	local function snap_attach(target, dt, hard)
		if not target or not cfg.tp or dead(target) or knocked(target) then
			return false
		end
		local th = get_stick_part(target) or hrp(target)
		if not th then
			return false
		end
		local live0 = th.Position
		if is_hide_pos(live0) or not is_flyable_pos(live0) then
			return false
		end
		local me = hrp(LP) or select(1, char_root())
		remember_return_cf(me)
		local now = tick()
		local frame = math.floor(now * 240)
		if not hard and _attach_wrote_frame == frame then
			active_attach_target = target
			return true
		end
		local tr = update_target_track(target, th, now)
		local h = cfg.radius or 8
		h = clamp_n(h, 2, 18)
		local v = cfg.y or 2
		local mode = cfg.tp_mode or "Strafe"
		local spd = (tr and tr.speed) or 0
		local flying = tr and (tr.air or tr.fast_air or spd >= 28)

		local live_pos = live0
		if cfg.chase and flying then
			local lead = cfg.attach_lead or 0.16
			local px, py, pz = resolved_target_pos(target, th, now, lead)
			if is_flyable_pos(Vector3.new(px, py, pz)) then
				live_pos = Vector3.new(px, py, pz)
			end
		end
		local goal = mode_attach_cf(th, target, mode, h, v, live_pos)
		if not goal then
			return false
		end

		local want_hard = hard == true or cfg.hard_snap == true or cfg.aggressive == true
		local carry = nil
		if tr then
			carry = Vector3.new(tr.vx or 0, tr.vy or 0, tr.vz or 0)
		end
		apply_cf(goal, carry, want_hard or flying)
		_attach_wrote_frame = frame
		lplr_pos = goal
		active_attach_target = target
		return true
	end

	local function hc_ragebot_rest()
		local function server_time()
			local t = os.time()
			pcall(function()
				t = Workspace:GetServerTimeNow()
			end)
			return t
		end

		local function shoot_origin()
			local me = hrp(LP)
			return me and me.Position, me
		end

		local function tool_is_gun(tool)
			if not tool then
				return false
			end
			local is_tool = false
			pcall(function()
				is_tool = tool.ClassName == "Tool"
			end)
			if not is_tool then
				return false
			end
			local n = string.lower(tool.Name)
			if string.find(n, "knife", 1, true) or string.find(n, "tip jar", 1, true) then
				return false
			end
			return string.find(n, "revolver", 1, true) ~= nil
				or string.find(n, "smg", 1, true) ~= nil
				or string.find(n, "uzi", 1, true) ~= nil
				or string.find(n, "doublebarrel", 1, true) ~= nil
				or string.find(n, "double-barrel", 1, true) ~= nil
				or string.find(n, "double barrel", 1, true) ~= nil
				or tool:FindFirstChild("Handle") ~= nil
				or tool:FindFirstChild("GunData") ~= nil
				or tool:FindFirstChild("GunClientShotgun") ~= nil
		end

		local function is_revolver(tool)
			if not tool then
				return false
			end
			local n = string.lower(tool.Name)
			return string.find(n, "revolver", 1, true) ~= nil
		end

		local function is_uzi(tool)
			if not tool then
				return false
			end

			local n = string.lower(tool.Name)
			return string.find(n, "smg", 1, true) ~= nil or string.find(n, "uzi", 1, true) ~= nil
		end

		local function is_double_barrel(tool)
			if not tool then
				return false
			end
			local n = string.lower(tool.Name)
			return string.find(n, "doublebarrel", 1, true) ~= nil
				or string.find(n, "double-barrel", 1, true) ~= nil
				or string.find(n, "double barrel", 1, true) ~= nil
		end

		local function rage_gun_ok(tool)
			if not tool or is_double_barrel(tool) then
				return false
			end
			return is_revolver(tool) or is_uzi(tool)
		end

		local function same_inst(a, b)
			if not a or not b then
				return false
			end
			local ok, same = pcall(function()
				return a:GetFullName() == b:GetFullName()
			end)
			return ok and same == true
		end

		local function char_held_tool()
			local char = LP.Character
			if not char then
				return nil
			end
			for _, c in char:GetChildren() do
				if c.ClassName == "Tool" then
					return c
				end
			end
			local via = char:FindFirstChildOfClass("Tool")
			if via and via.ClassName == "Tool" then
				return via
			end
			return nil
		end

		local function equipped_gun()
			local tool = char_held_tool()
			if tool and tool_is_gun(tool) and rage_gun_ok(tool) then
				return tool
			end
		end

		local function equipped_any_gun()
			local tool = char_held_tool()
			if tool and tool_is_gun(tool) then
				return tool
			end
		end

		local function blocked_gun_status(tool)
			if not tool then
				return "manually equip [Revolver] or [SMG]"
			end
			if is_double_barrel(tool) then
				return "blocked — [DoubleBarrel] trips HC gun AC"
			end
			return "blocked — [Revolver]/[SMG] only (not " .. tostring(tool.Name) .. ")"
		end

		local function is_shotgun(tool)
			if not tool then
				return false
			end
			if is_double_barrel(tool) then
				return true
			end
			if tool:FindFirstChild("GunClientShotgun") then
				return true
			end
			local n = string.lower(tool.Name)
			return n == "[shotgun]"
				or n == "[tacticalshotgun]"
				or string.find(n, "tacticalshotgun", 1, true) ~= nil
				or (string.find(n, "shotgun", 1, true) ~= nil and not string.find(n, "double", 1, true))
		end

		local function shotgun_pellets(tool)
			local p = tool
				and (
					tool:FindFirstChild("Pellets")
					or tool:FindFirstChild("PelletCount")
					or tool:FindFirstChild("Bullets")
				)
			if p and type(p.Value) == "number" then
				local n = math.floor(p.Value + 0.5)
				if n < 2 then
					n = 2
				elseif n > 12 then
					n = 12
				end
				return n
			end
			return 8
		end

		local function tool_value(tool, name)
			if not tool then
				return nil
			end
			local ov = tool:FindFirstChild(name)
			if ov then
				return ov
			end
			local scr = tool:FindFirstChild("Script")
			return scr and scr:FindFirstChild(name)
		end

		local function mark_can_hit(tool, part, target)
			if not tool then
				return
			end
			local model = hc_model(target) or (target and target.Character)
			local val = part or model
			if not val then
				return
			end

			pcall(function()
				local ov = tool_value(tool, "CanHitPlayer")
				if ov then
					ov.Value = val
				end
			end)
			pcall(function()
				local ov = tool_value(tool, "CanHitPlayer2")
				if ov then
					ov.Value = val
				end
			end)
		end

		local function gun_cooldown(tool)
			if is_double_barrel(tool) or is_shotgun(tool) then
				return 0.4
			end
			return 0
		end

		local function clear_shoot_locks(tool)
			local now = tick()
			pcall(function()
				local scr = tool and tool:FindFirstChild("Script")
				local can = scr and scr:FindFirstChild("CAN_RELOAD")
				if can then
					can.Value = true
				end
			end)
			local char = LP.Character
			local be = char and char:FindFirstChild("BodyEffects")
			if not be then
				return
			end

			pcall(function()
				local att = be:FindFirstChild("Attacking_CLIENT")
				if att then
					att.Value = false
				end
				local att2 = be:FindFirstChild("Attacking")
				if att2 then
					att2.Value = false
				end
				local rel = be:FindFirstChild("Reloading_CLIENT")
				if rel and rel.Value == true and (last_shoot <= 0 or (now - last_shoot) > 1.2) then
					rel.Value = false
				end
			end)
		end

		local function gun_muzzle_origin(tool, handle)
			if not tool or not handle then
				return nil
			end
			local def = tool:FindFirstChild("Default")
			local mesh = def and def:FindFirstChild("Mesh")
			local muzzle = mesh and mesh:FindFirstChild("Muzzle")
			if muzzle then
				local ok, wp = pcall(function()
					return muzzle.WorldPosition
				end)
				if ok and wp then
					return wp
				end
			end
			local att = handle:FindFirstChild("Muzzle")
			if att then
				local ok, wp = pcall(function()
					return att.WorldPosition
				end)
				if ok and wp then
					return wp
				end
			end
			return handle.Position
		end

		local function get_gun_origin()
			local char = LP.Character
			if char then
				local tool = char_held_tool()
				if tool then
					local handle = tool:FindFirstChild("Handle")
					local from_muzzle = gun_muzzle_origin(tool, handle)
					if from_muzzle and handle and from_muzzle ~= handle.Position then
						return from_muzzle
					end
					local muzzle = nil
					for _, d in tool:GetDescendants() do
						if d.ClassName == "Attachment" then
							local n = string.lower(d.Name)
							if
								string.find(n, "muzzle", 1, true)
								or string.find(n, "tip", 1, true)
								or string.find(n, "barrel", 1, true)
								or string.find(n, "fire", 1, true)
								or string.find(n, "gun", 1, true)
							then
								muzzle = d
								break
							end
						end
					end
					if muzzle then
						local ok, wp = pcall(function()
							return muzzle.WorldPosition
						end)
						if ok and wp then
							return wp
						end
					end
					if handle then
						local lv = handle.CFrame.LookVector
						return Vector3.new(
							handle.Position.X + lv.X * 1.8,
							handle.Position.Y + lv.Y * 1.8,
							handle.Position.Z + lv.Z * 1.8
						)
					end
				end
			end
			local me = hrp(LP)
			if me then
				local lv = me.CFrame.LookVector
				return Vector3.new(
					me.Position.X + lv.X * 2.2,
					me.Position.Y + 1.35 + lv.Y * 2.2,
					me.Position.Z + lv.Z * 2.2
				)
			end
			return nil
		end

		local function ensure_ammo(tool)
			if is_hood_customs() then
				return true
			end
			tool = tool or equipped_gun()
			if not tool then
				return false
			end
			local ammo = tool:FindFirstChild("Ammo")
			local max = tool:FindFirstChild("MaxAmmo")
			if not ammo then
				return true
			end
			if ammo.Value > 0 then
				return true
			end
			event = event or get_main_event()
			if not event then
				remote_status = "no shoot remote"
				return false
			end
			local now = tick()
			if (now - last_reload) < 0.4 then
				remote_status = "reloading..."
				return false
			end
			last_reload = now
			local ok = pcall(function()
				event:FireServer("Reload", true)
			end)
			if not ok then
				pcall(function()
					event:FireServer("Reload", tool)
				end)
			end
			remote_status = "reload 0/" .. tostring(max and max.Value or "?")
			return false
		end

		local function drawing_remove(obj)
			if not obj then
				return
			end
			pcall(function()
				obj:Remove()
			end)
			pcall(function()
				obj:Destroy()
			end)
		end

		local function clear_hit_tracers()
			for i = #hit_tracers, 1, -1 do
				local tr = hit_tracers[i]
				if tr then
					drawing_remove(tr.line)
					drawing_remove(tr.outline)
				end
				hit_tracers[i] = nil
			end
		end

		local function drawing_available()
			local ok, fn = pcall(function()
				return Drawing and Drawing.new
			end)
			return ok and typeof(fn) == "function"
		end

		local function world_to_screen(pos)
			if not pos then
				return nil, false
			end
			local screen, on_screen
			local ok = pcall(function()
				screen, on_screen = WorldToScreen(pos)
			end)
			if not ok or not screen then
				return nil, false
			end
			return screen, on_screen == true
		end

		local function add_hit_tracer(from3, to3)
			if not cfg.hit_tracers or not from3 or not to3 then
				return
			end
			if not drawing_available() then
				return
			end

			while #hit_tracers >= 24 do
				local old = table.remove(hit_tracers, 1)
				if old then
					drawing_remove(old.line)
					drawing_remove(old.outline)
				end
			end

			local now = tick()
			last_tracer_t = now

			local col = typeof(cfg.tracer_color) == "Color3" and cfg.tracer_color or DEFAULT_TRACER_COLOR
			local thick = cfg.tracer_thick or 1.5
			local line, outline
			local ok = pcall(function()
				outline = Drawing.new("Line")
				outline.Thickness = thick + 1.5
				outline.Color = Color3.new(0, 0, 0)
				outline.Transparency = 1
				outline.ZIndex = 1
				outline.Visible = false

				line = Drawing.new("Line")
				line.Thickness = thick
				line.Color = col
				line.Transparency = 1
				line.ZIndex = 2
				line.Visible = false
			end)
			if not ok or not line then
				drawing_remove(line)
				drawing_remove(outline)
				return
			end

			hit_tracers[#hit_tracers + 1] = {
				from = from3,
				to = to3,
				line = line,
				outline = outline,
				t0 = now,
				life = cfg.tracer_life or 0.55,
				col = col,
			}
		end

		local function update_hit_tracers()
			if #hit_tracers == 0 then
				return
			end
			local now = tick()
			for i = #hit_tracers, 1, -1 do
				local tr = hit_tracers[i]
				local age = now - tr.t0
				if age >= tr.life then
					drawing_remove(tr.line)
					drawing_remove(tr.outline)
					table.remove(hit_tracers, i)
				else
					local alpha = 1 - (age / tr.life)
					local a, on1 = world_to_screen(tr.from)
					local b, on2 = world_to_screen(tr.to)
					if on1 and on2 and a and b then
						pcall(function()
							tr.outline.From = a
							tr.outline.To = b
							tr.outline.Transparency = alpha * 0.85
							tr.outline.Visible = true
							tr.line.From = a
							tr.line.To = b
							tr.line.Color = tr.col
							tr.line.Transparency = alpha
							tr.line.Visible = true
						end)
					else
						pcall(function()
							tr.line.Visible = false
							tr.outline.Visible = false
						end)
					end
				end
			end
		end

		local function fire_mouse_pos(pos, part)
			if not pos then
				return
			end
			last_mouse_pos = pos
			pcall(function()
				_G.MOUSE_POSITION = pos
			end)
			local be = LP.Character and LP.Character:FindFirstChild("BodyEffects")
			local mp = be and be:FindFirstChild("MousePos")
			if mp then
				pcall(function()
					mp.Value = pos
				end)
			end
			event = event or get_main_event()
			if not event then
				return
			end

			if is_des_hood() and event.Name == "MainGameEvent" then
				return
			end
			if is_der_hood() then
				pcall(function()
					event:FireServer(MOUSE_ARG, pos)
				end)
				pcall(function()
					event:FireServer("UpdateMousePos", pos)
				end)
				return
			end

			local vel = Vector3.new()
			local tbl = {}
			if part then
				pcall(function()
					local root = part.AssemblyRootPart
					if root then
						vel = root.AssemblyLinearVelocity
					end
				end)
				tbl.thePart = part
				pcall(function()
					tbl.theOffset = part.CFrame:PointToObjectSpace(pos)
				end)
			end
			pcall(function()
				event:FireServer("MousePosUpdate", tbl, pos, vel)
			end)

			pcall(function()
				event:FireServer("UpdateMousePos", pos)
			end)
		end

		local function part_velocity(part)
			local vel = Vector3.new()
			pcall(function()
				local root = part.AssemblyRootPart
				if root then
					vel = root.AssemblyLinearVelocity or root.Velocity or Vector3.new()
				else
					vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new()
				end
			end)
			return vel
		end

		local function predicted_hit_pos(part, target)
			if not part then
				return nil
			end
			local pos = part.Position
			local now = tick()
			local tr = target and update_target_track(target, part, now) or nil
			local ping = get_ping_sec()
			local userPred = cfg.pred or 0.14
			local t = userPred + ping * (cfg.pred_ping or 1.45)
			if cfg.aggressive then
				t = t * (cfg.agg_mul or 1.35)
			end
			local vx, vy, vz = 0, 0, 0
			if tr then
				vx, vy, vz = tr.vx or 0, tr.vy or 0, tr.vz or 0
			else
				local vel = part_velocity(part)
				vx, vy, vz = vel.X, vel.Y, vel.Z
			end
			local spd = math.sqrt(vx * vx + vy * vy + vz * vz)
			local flying = (tr and (tr.air or tr.fast_air)) or spd >= 24
			if flying and cfg.air_pred ~= false then
				local mul = cfg.air_pred_mul or 2.45
				t = (userPred + ping * 1.65) * math.min(mul, 2.8)
				t = t + math.min(spd, 320) / 2200
				if cfg.aggressive then
					t = t * 1.12
				end
			end
			if spd < 2.5 and not flying then
				return pos
			end
			t = clamp_n(t, 0.04, flying and 0.38 or 0.24)
			local ax = (tr and tr.ax) or 0
			local ay = (tr and tr.ay) or 0
			local az = (tr and tr.az) or 0
			if spd >= 90 then
				ax, ay, az = 0, 0, 0
			end
			local half = 0.5 * t * t
			return Vector3.new(pos.X + vx * t + ax * half, pos.Y + vy * t + ay * half, pos.Z + vz * t + az * half)
		end

		local function part_aim_pos(part)
			if not part then
				return nil
			end
			local pos = part.Position
			pcall(function()
				pos = part.CFrame.Position
			end)
			return pos
		end

		local function gun_range(tool)
			local r = tool and tool:FindFirstChild("Range")
			if r and type(r.Value) == "number" and r.Value > 0 then
				return r.Value
			end
			return 200
		end

		local function true_muzzle(tool)
			tool = tool or equipped_gun()
			local handle = tool and tool:FindFirstChild("Handle")
			local char = LP.Character
			if not tool or not handle or not char then
				return nil
			end

			local parent_ok = false
			pcall(function()
				parent_ok = same_inst(tool.Parent, char)
					or same_inst(tool.Parent, hc_model(LP))
					or (tool.Parent and char and tool.Parent.Name == char.Name and tool.Parent.ClassName ~= "Backpack")
			end)
			if not parent_ok then
				return nil
			end
			local muzzle = gun_muzzle_origin(tool, handle) or handle.Position
			if typeof(muzzle) ~= "Vector3" then
				return nil
			end
			if is_hide_pos(muzzle) or not is_flyable_pos(muzzle) then
				return nil
			end
			return muzzle
		end

		local function shoot_origin_pos(tool)
			local m = true_muzzle(tool)
			if m then
				return m
			end
			local g = get_gun_origin()
			if typeof(g) == "Vector3" and is_flyable_pos(g) and not is_hide_pos(g) then
				return g
			end
			local root = hrp(LP) or select(1, char_root())
			if root and is_flyable_pos(root.Position) then
				return root.Position + Vector3.new(0, 1.35, 0)
			end
			return nil
		end

		local function shotgun_aim_part(part)
			if not part then
				return nil
			end
			local p = part.Parent
			local torso = p and (p:FindFirstChild("UpperTorso") or p:FindFirstChild("HumanoidRootPart"))
			if torso and is_flyable_pos(torso.Position) and not is_hide_pos(torso.Position) then
				return torso
			end
			return part
		end

		local function shotgun_spread_dirs(origin, mouse, t)
			local rng
			pcall(function()
				rng = Random.new(t)
			end)
			if not rng then
				local look = (mouse - origin)
				local unit = look.Magnitude > 0.001 and look.Unit or Vector3.new(0, 0, -1)
				return { unit, unit, unit, unit, unit }, 0
			end
			local roll_cf = CFrame.Angles(0, 0, math.rad(rng:NextNumber(-90, 90)))
			local mag = rng:NextNumber(0, 5.75) * (rng:NextInteger(0, 1) == 1 and 1 or -1)
			local pitch = (mag > -0.35 and mag < 0.35) and 0.35 or mag
			local spread = { -1.35, -0.9, 0.25, 0.55, 1 }
			local look = CFrame.new(origin, mouse)
			local dirs = {}
			for i = 1, 5 do
				dirs[i] = (look * roll_cf * CFrame.Angles(math.rad(spread[i] * pitch), 0, 0)).LookVector
			end
			return dirs, pitch
		end

		local function db_shot_range(origin, live)
			if typeof(origin) ~= "Vector3" or typeof(live) ~= "Vector3" then
				return false, "not close"
			end
			local d = (origin - live).Magnitude
			if d < 2.5 then
				return false, "origin inside"
			end
			if d > 28 then
				return false, "db too far"
			end
			return true
		end

		local function db_can_fire(tool, origin, live)
			if not (is_shotgun(tool) or is_double_barrel(tool)) then
				return true
			end
			local now = tick()
			local cd = gun_cooldown(tool) or 0.4
			if last_shoot > 0 and (now - last_shoot) < cd then
				return false, "db cooldown"
			end
			local range_ok, range_why = db_shot_range(origin, live)
			if not range_ok then
				return false, range_why
			end

			if typeof(origin) == "Vector3" and typeof(live) == "Vector3" then
				if typeof(_db_last_origin) == "Vector3" and typeof(_db_last_live) == "Vector3" then
					local was_on = (_db_last_origin - _db_last_live).Magnitude <= 28
					local now_on = (origin - live).Magnitude <= 28
					local jumped = (origin - _db_last_origin).Magnitude
					if now_on and not was_on and jumped >= 22 then
						_db_last_origin, _db_last_live = origin, live
						return false, "db origin settle"
					end
				end
				_db_last_origin, _db_last_live = origin, live
			end
			return true
		end

		local function hc_ray(origin, dir, ignore)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = ignore or {}
			params.IgnoreWater = true
			local hit = Workspace:Raycast(origin, dir, params)
			if hit then
				return hit.Instance, hit.Position, hit.Normal
			end
			local mag = dir.Magnitude
			if mag < 0.001 then
				return nil, origin, Vector3.new()
			end
			return nil, origin + dir, Vector3.new()
		end

		local function is_target_hit(inst, target, part, tgt_model)
			if not inst then
				return false
			end
			if part then
				local ok, same = pcall(function()
					return inst == part
				end)
				if ok and same then
					return true
				end
				local okn, n1, n2 = pcall(function()
					return inst.Name, part.Name
				end)
				if okn and n1 == n2 then
					local p1 = inst.Parent
					local p2 = part.Parent
					if p1 and p2 then
						local okp, samep = pcall(function()
							return p1 == p2
						end)
						if okp and samep then
							return true
						end
					end
				end
			end
			if tgt_model then
				local ok, yes = pcall(function()
					return inst:IsDescendantOf(tgt_model)
				end)
				if ok and yes then
					return true
				end
			end
			return false
		end

		local function resolve_gun_origin(hit_pos)
			local tool = equipped_gun()
			local muzzle = true_muzzle(tool)
			if muzzle then
				return muzzle, select(1, char_root())
			end
			local origin = get_gun_origin()
			local me = select(1, char_root()) or hrp(LP)
			if not origin and me then
				local lv = me.CFrame.LookVector
				origin = Vector3.new(me.Position.X + lv.X * 2, me.Position.Y + 1.4, me.Position.Z + lv.Z * 2)
			end
			return origin, me
		end

		local function build_shoot_payload(part, target)
			if not part then
				return nil
			end
			local tool = equipped_gun()
			local shotgun = is_shotgun(tool) or is_double_barrel(tool)
			local aim_part = part
			if shotgun then
				aim_part = shotgun_aim_part(part) or part
			end
			local hit_pos = part_aim_pos(aim_part) or aim_part.Position
			if typeof(hit_pos) ~= "Vector3" then
				return nil
			end
			if is_hide_pos(hit_pos) then
				remote_status = "void/tp - skip"
				return nil
			end
			local origin = shoot_origin_pos(tool)
			if not origin then
				remote_status = "no origin"
				return nil
			end

			local dist0 = (hit_pos - origin).Magnitude
			if (not shotgun) and dist0 > 22 then
				hit_pos = predicted_hit_pos(aim_part, target) or hit_pos
			end
			if shotgun then
				local ok_r, why = db_shot_range(origin, hit_pos)
				if not ok_r then
					remote_status = why or "db too far"
					return nil
				end
			elseif dist0 < 0.25 then
				local d = hit_pos - origin
				if d.Magnitude < 1e-4 then
					d = Vector3.new(0, 0, -1)
				end
				origin = hit_pos - d.Unit * 4
				dist0 = 4
			end
			local count = shotgun and 5 or 1
			local range = gun_range(tool)
			local t = server_time()
			pcall(function()
				t = Workspace:GetServerTimeNow()
			end)
			if type(t) ~= "number" then
				t = tick()
			end

			local ignore = ray_filter()
			local mouse = hit_pos
			local dirs
			if shotgun then
				dirs = select(1, shotgun_spread_dirs(origin, mouse, t))
				if not dirs or #dirs ~= 5 then
					remote_status = "spread mismatch"
					return nil
				end
			end
			local rays, hits = {}, {}
			local tgt_model = target and (hc_model(target) or target.Character)
			local on_tgt = 0
			for i = 1, count do
				local unit
				if shotgun then
					unit = dirs[i]
				else
					local d = mouse - origin
					unit = d.Magnitude > 0.001 and d.Unit or Vector3.new(0, 0, -1)
				end
				local inst, pos, nrm = hc_ray(origin, unit * range, ignore)
				local hit_ok = is_target_hit(inst, target, aim_part, tgt_model)
					or is_target_hit(inst, target, part, tgt_model)
				if hit_ok then
					on_tgt = on_tgt + 1
				elseif (not shotgun) and dist0 <= 28 then
					inst = aim_part
					pos = mouse
					nrm = -unit
					on_tgt = on_tgt + 1
					hit_ok = true
				end
				rays[i] = { Instance = inst or nil, Position = pos, Normal = nrm or Vector3.new() }

				local rec = {}
				if inst then
					rec.thePart = inst
					pcall(function()
						rec.theOffset = inst.CFrame:PointToObjectSpace(pos)
					end)
				end
				hits[i] = rec
			end
			if (not shotgun) and on_tgt < 1 then
				remote_status = "ray miss"
				return nil
			end
			return { rays, hits, origin, mouse, t }, mouse, origin, on_tgt
		end

		local function hit_pos_of(part)
			local hit_pos = part.Position
			pcall(function()
				hit_pos = part.CFrame:PointToWorldSpace(Vector3.new(-0.57, 0.01, -0.30))
			end)
			return hit_pos
		end

		local function fire_shoot_des(part, times)
			local tool = equipped_gun()
			local handle = tool and tool:FindFirstChild("Handle")
			if not handle then
				remote_status = "no gun Handle"
				return false
			end
			if not ensure_ammo(tool) then
				return false
			end
			local range = (tool:FindFirstChild("Range") and tool.Range.Value) or 200
			local damage = (tool:FindFirstChild("Damage") and tool.Damage.Value) or 0
			local sg = is_shotgun(tool) or tool:FindFirstChild("GunClientShotgun") ~= nil
			local ok_any, err, fired, form = false, nil, 0, "?"
			local last_hit, last_origin
			for _ = 1, times do
				if not ensure_ammo(tool) then
					break
				end
				local hit_pos = hit_pos_of(part)
				local origin = gun_muzzle_origin(tool, handle) or get_gun_origin() or handle.Position
				local dir = hit_pos - origin
				local mag = dir.Magnitude
				local normal = mag > 0.001 and -dir.Unit or Vector3.new(0, 1, 0)
				fire_mouse_pos(hit_pos, part)
				last_hit, last_origin = hit_pos, origin
				local ok, e
				if sg then
					local pellets = {}
					local n = shotgun_pellets(tool)
					for i = 1, n do
						pellets[i] = {
							AimPosition = hit_pos,
							Result1 = hit_pos,
							Result2 = part,
							Result3 = normal,
						}
					end
					ok, e = pcall(function()
						event:FireServer("ShootGun", handle, origin, pellets, nil, nil, nil, range, damage)
					end)
					form = is_double_barrel(tool) and "ShootGun/DB" or "ShootGun/shotgun"
				else
					ok, e = pcall(function()
						event:FireServer("ShootGun", handle, origin, nil, hit_pos, part, normal, range, damage)
					end)
					form = "ShootGun"
				end
				if ok then
					ok_any, fired = true, fired + 1
				else
					err = e
				end
			end
			local ammo = tool:FindFirstChild("Ammo")
			if ammo and ammo.Value <= 0 then
				ensure_ammo(tool)
			end
			if ok_any then
				shoot_fail_streak = 0
				remote_status = form .. " x" .. tostring(fired) .. " → " .. part.Name
				if last_origin and last_hit then
					add_hit_tracer(last_origin, last_hit)
				end
				return true, last_hit
			end
			if string.find(tostring(remote_status), "reload", 1, true) then
				return false
			end
			shoot_fail_streak = shoot_fail_streak + 1
			event = nil
			remote_status = "ShootGun FAIL " .. tostring(err)
			return false, last_hit
		end

		local function fire_shoot_der(part, times)
			local tool = equipped_gun()
			if not tool then
				remote_status = "no gun"
				return false
			end
			if not ensure_ammo(tool) then
				return false
			end
			local handle = tool:FindFirstChild("Handle")
			local origin = gun_muzzle_origin(tool, handle) or get_gun_origin()
			local hit_pos = hit_pos_of(part)
			local ok_any, fired, form = false, 0, "?"
			for _ = 1, times do
				if not ensure_ammo(tool) then
					break
				end
				fire_mouse_pos(hit_pos)
				local ok_shoot = pcall(function()
					event:FireServer("Shoot")
				end)
				if ok_shoot then
					ok_any = true
					fired = fired + 1
					form = "Shoot"
				end
			end
			if ok_any then
				shoot_fail_streak = 0
				remote_status = form .. "/" .. MOUSE_ARG .. " x" .. tostring(fired) .. " → " .. part.Name
				if origin and hit_pos then
					add_hit_tracer(origin, hit_pos)
				end
				return true, hit_pos
			end
			shoot_fail_streak = shoot_fail_streak + 1
			remote_status = "Der Hood shoot FAIL — hold a gun"
			return false, hit_pos
		end

		local function fire_shoot(part, times, target)
			event = event or get_main_event()
			if not event or not part then
				remote_status = event and "no part" or "no shoot remote"
				return false
			end

			local alive = false
			pcall(function()
				alive = part.Parent ~= nil
			end)
			if not alive then
				remote_status = "stale part"
				return false
			end

			times = times or 1
			if times < 1 then
				times = 1
			end
			target = target or active_attach_target

			if is_der_hood() then
				return fire_shoot_der(part, times)
			end
			if is_des_hood() or event.Name == "MainGameEvent" then
				return fire_shoot_des(part, times)
			end

			local tool = equipped_gun()
			if not tool or not rage_gun_ok(tool) then
				remote_status = blocked_gun_status(equipped_any_gun())
				return false
			end
			mark_can_hit(tool, part, target)

			local payload, hit_pos, origin, on_tgt = build_shoot_payload(part, target)
			if not payload then
				remote_status = remote_status or "no origin"
				return false
			end

			local ok_any = false
			local err
			local fired = 0
			local last_hit, last_origin = hit_pos, origin
			local form = "?"
			fire_mouse_pos(hit_pos, part)

			for i = 1, times do
				if i > 1 then
					local t = payload[5]
					pcall(function()
						t = Workspace:GetServerTimeNow()
					end)
					if type(t) == "number" then
						payload[5] = t + (i * 1e-4)
					end
					pcall(function()
						local be = LP.Character and LP.Character:FindFirstChild("BodyEffects")
						local att = be and be:FindFirstChild("Attacking_CLIENT")
						if att then
							att.Value = false
						end
					end)
				end

				local ok1, e1 = pcall(function()
					event:FireServer("Shoot", payload)
				end)
				if ok1 then
					ok_any = true
					fired = fired + 1
					form = "table/1"
				else
					local ok2, e2 = pcall(function()
						event:FireServer("Shoot", payload[1], payload[2], payload[3], payload[4], payload[5])
					end)
					if ok2 then
						ok_any = true
						fired = fired + 1
						form = "args"
					else
						err = e2 or e1
					end
				end
			end

			if ok_any then
				shoot_fail_streak = 0
				last_shoot = tick()
				pcall(function()
					local be = LP.Character and LP.Character:FindFirstChild("BodyEffects")
					local gc = be and be:FindFirstChild("GunChanges")
					if gc then
						gc.Value = (tonumber(gc.Value) or 0) + fired
					end
					local att = be and be:FindFirstChild("Attacking_CLIENT")
					if att then
						att.Value = true
					end
				end)
				remote_status = "Shoot/"
					.. form
					.. " x"
					.. tostring(fired)
					.. (on_tgt and (" hit" .. tostring(on_tgt)) or "")
					.. " → "
					.. part.Name
				if last_origin and last_hit then
					add_hit_tracer(last_origin, last_hit)
				end
				return true, last_hit
			end

			shoot_fail_streak = shoot_fail_streak + 1
			event = get_main_event()
			remote_status = "Shoot FAIL " .. tostring(err)
			return false, last_hit
		end

		local function rage_shoot_target(target)
			if not cfg.shoot or not target or dead(target) or knocked(target) then
				return false
			end
			if cfg.ff_check and has_forcefield(target) then
				remote_status = "ForceField — waiting"
				return false
			end

			local now = tick()
			local held = equipped_any_gun()
			if held and not rage_gun_ok(held) then
				remote_status = blocked_gun_status(held)
				return false
			end
			local tool = equipped_gun()
			if not tool or not rage_gun_ok(tool) then
				remote_status = blocked_gun_status(held)
				return false
			end
			clear_shoot_locks(tool)
			if not ensure_ammo(tool) then
				return false
			end

			local wait_s = 0
			if cfg.aggressive ~= true then
				wait_s = cfg.interval or 0
				if type(wait_s) ~= "number" or wait_s < 0.03 then
					wait_s = 0.03
				end
			end
			if wait_s > 0 and last_shoot > 0 and (now - last_shoot) < wait_s then
				return false
			end

			local m = hc_model(target)
			local s = special(target)
			if is_hood_customs() then
				if not s or s.Name ~= "SpecialParts" then
					s = m and m:FindFirstChild("SpecialParts")
				end
				if not s then
					remote_status = "no SpecialParts"
					return false
				end
			elseif not s then
				remote_status = "no character"
				return false
			end

			local aim = find_part(s, "Head")
				or find_part(s, cfg.hitbox or "Head")
				or find_part(s, "UpperTorso")
				or find_part(s, "HumanoidRootPart")
				or find_part(m, "Head")
				or find_part(m, "HumanoidRootPart")
			if not aim then
				remote_status = "no hitbox"
				return false
			end

			if cfg.tp then
				void_pulse = false
				void_bait_peek = false
				snap_attach(target, nil, true)
			end

			local origin = shoot_origin_pos(tool)
			local live = part_aim_pos(aim) or aim.Position
			if not origin or not live then
				remote_status = "no origin"
				return false
			end

			fire_mouse_pos(live, aim)

			local bursts = cfg.burst or 12
			if type(bursts) ~= "number" or bursts < 1 then
				bursts = 12
			end
			if cfg.aggressive then
				if is_uzi(tool) then
					bursts = math.max(bursts, 14)
				elseif is_revolver(tool) then
					bursts = math.max(bursts, 10)
				end
			end
			if bursts > 16 then
				bursts = 16
			end
			return fire_shoot(aim, bursts, target)
		end

		local function menu_open()
			local ok, open = pcall(function()
				return win and win:IsOpen()
			end)
			return ok and open == true
		end

		local function on_attach_render()
			if not menu_open() then
				update_hit_tracers()
			end
		end

		local function fire_stomp()
			event = get_main_event()
			if not event then
				remote_status = "no MainEvent"
				return false
			end
			local ok, err = pcall(function()
				event:FireServer("Stomp")
			end)
			remote_status = ok and "Stomp ok" or ("Stomp FAIL " .. tostring(err))
			return ok
		end

		do
			local INS_UI_URL =
				"https://raw.githubusercontent.com/lec1e/Matcha-UI-Libraries/refs/heads/main/INS%20UI.lua"
			local ok_load, result = pcall(function()
				return loadstring(game:HttpGet(INS_UI_URL))()
			end)
			Lib = (ok_load and result) or INSUI or INSui
		end

		if not Lib then
			error("[HC] INSUI failed to load — check HttpGet / INSUI global")
		end

		win = Lib:CreateWindow({
			title = SCRIPT_NAME,
			subtitle = "Ragebot · Matcha",
			size = Vector2.new(740, 860),
			menuKey = "p",
			configName = "hood_ware",
			configFolder = "hood_ware",
			autoSave = true,
			checkboxStyle = true,
			smartFps = true,
			keybindOverlay = true,
			startOpen = true,
			opacity = 0.98,
			font = "Proxima",
			logo = "https://raw.githubusercontent.com/lec1e/Matcha-UI-Libraries/main/assets/hc-ragebot-logo.png",
			theme = { accent = Color3.fromRGB(255, 72, 92) },
			accentA = Color3.fromRGB(255, 72, 92),
			accentB = Color3.fromRGB(255, 140, 60),
			backgroundEffect = "Rain",
			backgroundEffectColor = Color3.fromRGB(255, 80, 90),
		})

		pcall(function()
			win:AddSettingsTab("gear")
		end)
		pcall(function()
			Lib:ApplyThemePreset("Crimson")
		end)
		pcall(function()
			Lib:SetAccent(Color3.fromRGB(255, 72, 92), Color3.fromRGB(255, 140, 60))
		end)

		pcall(function()
			status_box = Lib:CreateBox({
				title = SCRIPT_NAME,
				position = Vector2.new(18, 120),
				width = 280,
			})
			if status_box then
				status_box_lines = {
					status_box:Stat("status: boot"),
					status_box:Stat("remote: ready"),
					status_box:Stat("void: off"),
					status_box:Text("mode —"),
					status_box:Text("offsets —"),
				}
				status_box:SetVisible(cfg.status_box ~= false)
			end
		end)

		local function box_clip(s, n)
			s = tostring(s or "")
			s = string.gsub(s, "%s+|%s+", " · ")
			if #s > n then
				return string.sub(s, 1, n - 1) .. "…"
			end
			return s
		end

		local function refresh_status_box()
			local lines = status_box_lines
			if not lines or not status_box then
				return
			end
			local mode = cfg.void_method or "Pulse"
			local void_val = "off"
			if void_hide_active() then
				void_val = mode .. (void_pulse and " pulse" or (void_bait_peek and " bait" or " ready"))
			end
			local mode_txt = (cfg.aggressive and "AGG · " or "")
				.. tostring(cfg.tp_write or "CFrame")
				.. (cfg.mem_tp and " mem" or "")
				.. " · "
				.. tostring(cfg.tp_mode or "?")
			pcall(function()
				lines[1].Value = "status: " .. box_clip(status, 18)
				lines[2].Value = "remote: " .. box_clip(remote_status, 18)
				lines[3].Value = "void: " .. box_clip(void_val, 18)
				lines[4].Value = box_clip(mode_txt, 34)
				lines[5].Value = box_clip(offsets_hud_line(), 34)
			end)
		end

		Lib:Category("RAGE")
		local tab = win:Tab("Ragebot", "crosshair")

		local rage = tab:Section("Ragebot", "Left", "multi-select targets — list auto-refreshes on leave")
		rage_handle = rage:Toggle("Enabled", false, function(on)
			cfg.on = on == true
			sync_bind_active(rage_handle, cfg.on)
			status = cfg.on and "ON" or "OFF"
			if cfg.on then
				void_pulse = false
				void_bait_peek = false
				if void_hide_active() then
					pcall(function()
						Lib:Notify(SCRIPT_NAME, "Void Hide still on — attach skips void while raging", 2, "info")
					end)
				end
			end
			pcall(function()
				Lib:Notify(SCRIPT_NAME, cfg.on and "ragebot on" or "ragebot off", 2, cfg.on and "success" or "info")
			end)
		end)
		pcall(function()
			rage_handle:AddKeybind("c", "Toggle", function(active)
				on_gated_keybind(rage_handle, active)
			end)
		end)
		pcall(function()
			rage_handle:SetRisk()
		end)

		rage:Toggle("Aggressive", true, function(on)
			cfg.aggressive = on == true
			if cfg.aggressive then
				cfg.hard_snap = true
				cfg.interval = 0
			end
		end):SetRisk()
		rage:Info("Aggressive = max dump on Heartbeat. Keybind C (ignored off-Roblox / while typing).")
		rage:Toggle("Auto Target (closest)", true, function(on)
			cfg.auto_target = on == true
		end)
		rage:Info("Leave Targets empty + Auto Target = closest enemy. Equip gun yourself.")

		rage:Info("Targets update when players join/leave. Keybind: C")

		local targets_dd = rage:Dropdown(
			"Targets",
			{},
			function()
				return player_names()
			end,
			true,
			function(v)
				set_targets_from_list(v)
				status = "targets: " .. selected_text()
			end,
			"pick one or more players",
			true
		)

		rage:Button("Select All", function()
			local all = player_names()
			set_targets_from_list(all)
			pcall(function()
				targets_dd:Set(all)
			end)
			status = "added all (" .. tostring(#all) .. ")"
		end):AddButton("Clear", function()
			set_targets_from_list({})
			pcall(function()
				targets_dd:Set({})
			end)
			lplr_pos = nil
			status = "cleared targets"
		end)

		rage:Button("Refresh Targets", function()
			pcall(function()
				targets_dd:Refresh()
			end)
			prune_selected()
			status = "list refreshed"
			Lib:Notify(SCRIPT_NAME, "player list refreshed", 2, "success")
		end)

		rage:Label(function()
			return "Selected: " .. selected_text()
		end)
		rage:Label(function()
			return "Online: " .. tostring(#Players:GetPlayers() - 1)
		end)
		rage:Label(function()
			return "Status: " .. tostring(status)
		end)
		rage:Label(function()
			return "Remote: " .. tostring(remote_status)
		end)
		rage:Label(function()
			return "Game: " .. GAME_TITLE .. " (" .. GAME_KIND .. ")"
		end)
		rage:Label(function()
			return "Chars: " .. (chars_folder() and "OK" or "MISSING")
		end)
		rage:Toggle("Status Box", true, function(on)
			cfg.status_box = on == true
			pcall(function()
				if status_box then
					status_box:SetVisible(cfg.status_box)
				end
			end)
		end)

		local tp = tab:Section("Teleport", "Left", "Primitive memory TP + auto offsets")
		tp:Toggle("Attach / Teleport", true, function(on)
			cfg.tp = on == true
		end)
		tp:Toggle("Hard Snap", true, function(on)
			cfg.hard_snap = on == true
		end)
		tp:Toggle("Face Target", true, function(on)
			cfg.face = on == true
		end)
		tp:Dropdown("Mode", { "Sticky" }, TP_MODES, false, function(v)
			cfg.tp_mode = (v and v[1]) or "Sticky"
		end)
		tp:Dropdown("Write Method", { "CFrame" }, TP_WRITE_METHODS, false, function(v)
			cfg.tp_write = (v and v[1]) or "CFrame"
		end)
		tp:Toggle("Memory Primitive TP", true, function(on)
			cfg.mem_tp = on == true
		end):SetRisk()
		tp:Toggle("Dual Write (mem+CFrame)", true, function(on)
			cfg.mem_dual = on == true
		end)
		tp:Info("Default Write=CFrame (reliable). Primitive needs Unsafe LuaU — use Dual if both.")
		tp:Toggle("Auto Refresh Offsets", true, function(on)
			cfg.mem_auto_refresh = on == true
		end)
		tp:Button("Refresh Offsets Now", function()
			local ok = refresh_offsets(true, "ui")
			Lib:Notify(
				SCRIPT_NAME,
				ok and offsets_hud_line() or ("offset fail: " .. tostring(Offsets.last_err)),
				3,
				ok and "success" or "error"
			)
		end):AddButton("Probe Root", function()
			local root = char_root()
			local prim, addr = get_primitive(root)
			local live = root and root.Position
			local memp = read_primitive_pos(root)
			local msg = string.format(
				"addr=%s prim=%s live=%s mem=%s",
				addr and string.format("0x%X", addr) or "nil",
				prim and string.format("0x%X", prim) or "nil",
				live and string.format("%.1f,%.1f,%.1f", live.X, live.Y, live.Z) or "nil",
				memp and string.format("%.1f,%.1f,%.1f", memp.X, memp.Y, memp.Z) or "nil"
			)
			status = msg
			print("[HC] probe", msg, offsets_hud_line())
			Lib:Notify(SCRIPT_NAME, msg, 4, prim and "success" or "warning")
		end)
		tp:Label(function()
			return offsets_hud_line()
		end)
		tp:Slider("Horizontal Offset", 3, 0.5, 2, 18, "", function(v)
			cfg.radius = v
		end)
		tp:Slider("Vertical Offset", 1, 0.5, -50, 50, "", function(v)
			cfg.y = v
		end)
		tp:Slider("Strafe Speed", 70, 1, 1, 100, "%", function(v)
			cfg.strafe_speed = v
		end)
		tp:Toggle("Chase Resolve", true, function(on)
			cfg.chase = on == true
		end)
		tp:Slider("Attach Lead", 0.16, 0.01, 0, 0.45, "s", function(v)
			cfg.attach_lead = v
		end)
		tp:Toggle("Air Intercept", true, function(on)
			cfg.air_intercept = on == true
		end)
		tp:Slider("Catch Power", 140, 5, 10, 200, "", function(v)
			cfg.sticky_speed = v
		end)
		tp:Info("Write Method=Primitive uses live offsets. If off-target, Refresh Offsets after a Roblox update.")

		local shoot = tab:Section("Shoot", "Right", "MainEvent Shoot")
		shoot:Toggle("Fire Shoot Remote", true, function(on)
			cfg.shoot = on == true
		end)
		shoot:Toggle("ForceField Check", true, function(on)
			cfg.ff_check = on == true
		end)
		shoot:Dropdown("Hitbox", { "Head" }, HITBOXES, false, function(v)
			cfg.hitbox = (v and v[1]) or "Head"
		end)
		shoot:Info(
			is_der_hood() and "Der Hood: MainEvent skid mouse + Shoot. Hold a gun."
				or is_des_hood() and "Des Hood: MainGameEvent ShootGun (Handle, origin, hit)."
				or "Hood Customs: [Revolver] + [SMG] only. [DoubleBarrel] blocked (gun AC)."
		)
		shoot:Slider("Fire Interval", 0, 0.01, 0, 0.5, "s", function(v)
			cfg.interval = tonumber(v) or 0
			if not cfg.aggressive and cfg.interval < 0.03 then
				cfg.interval = 0.03
			end
		end)
		shoot:Slider("Burst / tick", 16, 1, 1, 16, "", function(v)
			cfg.burst = math.floor(tonumber(v) or 16)
		end)
		shoot:Toggle("Render Fire", false, function(on)
			cfg.render_fire = on == true
		end)
		shoot:Info("Shoot on Heartbeat only. Render Fire is off so the menu stays clickable.")
		shoot:Slider("Prediction", 0.14, 0.01, 0, 0.45, "", function(v)
			cfg.pred = v
		end)
		shoot:Slider("Ping Lead", 1.45, 0.05, 0.5, 2.5, "x", function(v)
			cfg.pred_ping = v
		end)
		shoot:Slider("Agg Mult", 1.35, 0.05, 1, 2.2, "x", function(v)
			cfg.agg_mul = v
		end)
		shoot:Toggle("Air Prediction", true, function(on)
			cfg.air_pred = on == true
		end)
		shoot:Slider("Air Pred Mult", 2.45, 0.05, 1, 4, "x", function(v)
			cfg.air_pred_mul = v
		end)
		shoot:Info("Shoot rays must hit SpecialParts — do not exclude target. Status should show Shoot/… hit1.")

		local fx = tab:Section("Hit Tracers", "Right", "Drawing line gun → hit part")
		fx:Toggle("Hit Tracers", true, function(on)
			cfg.hit_tracers = on == true
			if not cfg.hit_tracers then
				clear_hit_tracers()
			end
		end)
		fx:Colorpicker("Tracer Color", DEFAULT_TRACER_COLOR, function(c)
			if typeof(c) == "Color3" then
				cfg.tracer_color = c
			end
		end)
		fx:Slider("Tracer Lifetime", 0.55, 0.05, 0.15, 2, "s", function(v)
			cfg.tracer_life = v
		end)
		fx:Slider("Tracer Thickness", 1.5, 0.5, 1, 4, "", function(v)
			cfg.tracer_thick = v
		end)
		fx:Info("Uses Matcha WorldToScreen + Drawing.Line from muzzle to target")

		local stomp = tab:Section("Stomp", "Right")
		stomp:Toggle("Auto Stomp", true, function(on)
			cfg.stomp = on == true
		end)
		stomp:Toggle("TP Back After Stomp", true, function(on)
			cfg.tp_back = on == true
		end)
		stomp:Slider("Height", 2.5, 0.1, 1, 5, "", function(v)
			cfg.stomp_h = v
		end)
		stomp:Dropdown("On Kill Return", { "Position" }, ON_KILL_RETURNS, false, function(v)
			cfg.on_kill_return = (v and v[1]) or "Position"
		end)
		stomp:Info("When all targets die: Position = your saved spot, Void = hide in void, None = stay")

		local anti = tab:Section("Anti Aim", "Right", "hood ware void methods (Matcha CFrame)")
		void_hide_handle = anti:Toggle("Void Hide", false, function(on)
			cfg.void_hide = on == true
			sync_bind_active(void_hide_handle, cfg.void_hide)
			if not cfg.void_hide then
				void_pulse = false
				void_bait_peek = false
			end
			if cfg.void_hide and cfg.no_void_kill then
				set_no_void_kill(true)
			elseif not cfg.void_hide then
				set_no_void_kill(false)
			end
		end)
		pcall(function()
			void_hide_handle:AddKeybind("v", "Toggle", function(active)
				on_gated_keybind(void_hide_handle, active)
			end)
		end)
		pcall(function()
			void_hide_handle:SetRisk()
		end)
		anti:Toggle("No Void Kill", true, function(on)
			cfg.no_void_kill = on == true
			if void_hide_active() then
				set_no_void_kill(cfg.no_void_kill)
			elseif not cfg.no_void_kill then
				set_no_void_kill(false)
			end
		end)
		anti:Dropdown("Void Method", { "Pulse" }, VOID_METHODS, false, function(v)
			cfg.void_method = (v and v[1]) or "Pulse"
			void_pulse = false
			void_bait_peek = false
		end)
		anti:Info(
			"Pulse / Flicker = classic void. Bait = void then map peek. Exp = deep + look snap. Sky / Under Map = Y offsets."
		)
		anti:Divider("Pulse / Random")
		anti:Slider("Pulse Interval", 0.1, 0.01, 0.02, 0.5, "s", function(v)
			cfg.void_interval = v
		end)
		anti:Slider("Pulse Time", 0.1, 0.01, 0.02, 0.5, "s", function(v)
			cfg.void_time = v
		end)
		anti:Slider("Pulse Spread", 20, 1, 0, 80, "", function(v)
			cfg.void_pulse_spread = v
		end)
		anti:Divider("Experimental")
		anti:Slider("Exp Interval", 0.06, 0.01, 0.02, 0.5, "s", function(v)
			cfg.void_exp_interval = v
		end)
		anti:Slider("Exp Time", 0.14, 0.01, 0.02, 0.6, "s", function(v)
			cfg.void_exp_time = v
		end)
		anti:Slider("Exp Spread", 80, 1, 0, 200, "", function(v)
			cfg.void_exp_spread = v
		end)
		anti:Toggle("Exp Look Snap", true, function(on)
			cfg.void_exp_look = on == true
		end)
		anti:Toggle("Exp Vel Dump", true, function(on)
			cfg.void_exp_vel = on == true
		end)
		anti:Divider("Bait")
		anti:Slider("Bait Void Time", 0.35, 0.01, 0.05, 1, "s", function(v)
			cfg.void_bait_time = v
		end)
		anti:Slider("Bait Peek Gap", 0.18, 0.01, 0.05, 0.8, "s", function(v)
			cfg.void_bait_peek = v
		end)
		anti:Slider("Bait Offset", 12, 1, 2, 40, "", function(v)
			cfg.void_bait_offset = v
		end)
		anti:Divider("Sky / Under")
		anti:Slider("Sky Height", 500, 10, 50, 2000, "", function(v)
			cfg.void_sky_height = v
		end)
		anti:Slider("Under Depth", 80, 5, 10, 400, "", function(v)
			cfg.void_under_depth = v
		end)
		anti:Divider("Flicker")
		anti:Slider("Flicker Speed", 0.04, 0.01, 0.02, 0.2, "s", function(v)
			cfg.void_flicker_speed = v
		end)
		anti:Slider("Flicker Time", 0.04, 0.01, 0.02, 0.2, "s", function(v)
			cfg.void_flicker_time = v
		end)
		anti:Toggle("Anti Loop", false, function(on)
			cfg.anti_loop = on == true
			if cfg.anti_loop and cfg.no_void_kill then
				set_no_void_kill(true)
			end
		end):SetRisk()
		anti:Slider("Closest Range", 20, 1, 8, 40, "", function(v)
			cfg.anti_loop_range = v
		end)
		anti:Toggle("Anti Loop Jitter", true, function(on)
			cfg.anti_loop_jitter = on == true
		end)
		anti:Toggle("Anti Loop Vel Desync", false, function(on)
			cfg.anti_loop_vel = on == true
		end)
		anti:Info("When on: closest player in range → light void pulses (less laggy)")
		anti:Label(function()
			if not cfg.anti_loop then
				return "Closest: (anti loop off)"
			end
			local plr, d = closest_cache.plr, closest_cache.d
			if not plr then
				return "Closest: none"
			end
			local in_range = d <= (cfg.anti_loop_range or 20)
			return "Closest: "
				.. plr.Name
				.. " "
				.. string.format("%.1f", d)
				.. (in_range and " — ACTIVE" or " — out of range")
		end)

		local misc = tab:Section("Unload", "Right")
		misc:Button("Unload Script", function()
			Lib:Dialog({
				title = "Unload?",
				text = "Stop the ragebot and destroy the menu?",
				confirm = "Unload",
				onConfirm = function()
					if _G.hc_ragebot_unload then
						_G.hc_ragebot_unload()
					end
				end,
			})
		end):SetRisk()

		local function on_heartbeat(dt)
			if not running then
				return
			end
			if typeof(dt) ~= "number" or dt <= 0 or dt > 0.25 then
				dt = 0.016
			end

			local now = tick()
			prune_selected()

			local me = hrp(LP)

			if rage_active() and cfg.tp and not menu_open() then
				local early = active_attach_target
				if not early or dead(early) then
					early = pick_primary(true, true) or pick_primary(true, false)
				end
				if early and not dead(early) and not knocked(early) then
					active_attach_target = early
					snap_attach(early, dt, true)
					me = hrp(LP) or me
				end
			end

			if me then
				local attaching_now = rage_active() and cfg.tp and active_attach_target and lplr_pos
				if attaching_now and not is_void_y(lplr_pos.Y) then
					if not is_void_y(me.Position.Y) then
						void_safe_cf = lplr_pos
					end
				elseif is_void_y(me.Position.Y) and void_safe_cf then
					lplr_pos = void_safe_cf
				else
					lplr_pos = me.CFrame
					if not is_void_y(me.Position.Y) then
						void_safe_cf = lplr_pos
					end
				end
			end

			local tp_msg = "tp off"
			local did_rage = false

			if rage_active() then
				local sel = selected_list()
				local use_auto = (#sel == 0 and cfg.auto_target ~= false)
				if #sel == 0 and not use_auto then
					active_attach_target = nil
					status = "no targets — pick from Targets"
				else
					local alive_n, dead_n = selected_alive_count()
					if use_auto then
						local closest = pick_closest_combat(true, true) or pick_closest_combat(true, false)
						alive_n = closest and 1 or 0
						dead_n = 0
					end

					if alive_n == 0 then
						active_attach_target = nil
						local mode = cfg.on_kill_return or "Position"
						if use_auto then
							status = "no enemies nearby"
						elseif mode == "Void" then
							local ok_ret = apply_kill_return(me, true)
							status = ok_ret and "kill return Void — waiting respawn"
								or ("all dead (" .. tostring(dead_n) .. ") — waiting respawn")
						elseif not kill_returned then
							local ok_ret = apply_kill_return(me, false)
							kill_returned = true
							status = ok_ret and ("kill return " .. mode .. " — waiting respawn")
								or ("all dead (" .. tostring(dead_n) .. ") — waiting respawn")
						else
							status = "all dead (" .. tostring(dead_n) .. ") — waiting respawn"
						end
					else
						kill_returned = false
						if me and is_void_y(me.Position.Y) and return_cf then
							lplr_pos = return_cf
							apply_cf(lplr_pos, nil, true)
						end
						did_rage = true
						local shootable = pick_primary(true, true) or pick_primary(true, false)
						local knocked_plr = (not use_auto) and cfg.stomp and pick_knocked() or nil

						local do_stomp = false
						if knocked_plr and me then
							if not shootable then
								do_stomp = true
							else
								do_stomp = dist_to(knocked_plr) <= dist_to(shootable) + 6
							end
						end

						if do_stomp then
							active_attach_target = nil
							local part = aim_part(knocked_plr, "UpperTorso")
								or aim_part(knocked_plr, "HumanoidRootPart")
								or hrp(knocked_plr)
							if part then
								remember_return_cf(me)
								if not saved_cf and me and not is_void_y(me.Position.Y) then
									saved_cf = me.CFrame
								end
								local p = part.Position
								lplr_pos = cf_xyz(p.X, p.Y + cfg.stomp_h, p.Z)
								apply_cf(lplr_pos, nil, true)
								if now - last_stomp > 0.03 then
									last_stomp = now
									fire_stomp()
								end
								status = "stomp " .. knocked_plr.Name .. " | " .. remote_status
							else
								status = "stomp fail — no torso " .. knocked_plr.Name
							end
						else
							if saved_cf then
								if cfg.tp_back then
									lplr_pos = saved_cf
									apply_cf(lplr_pos, nil, true)
								end
								saved_cf = nil
							end

							local target = shootable or pick_primary(false)
							if target and dead(target) then
								target = nil
							end

							local track = target and target_tracks[track_key(target)] or nil
							local held = equipped_any_gun()
							local gun_blocked = held and not rage_gun_ok(held)

							if target and cfg.tp then
								active_attach_target = target
								tp_msg = (cfg.aggressive and "agg " or "")
									.. ((cfg.tp_mode == "Sticky") and "sticky lock" or ("tp " .. tostring(cfg.tp_mode)))
								if menu_open() then
									tp_msg = tp_msg .. " | menu"
								elseif snap_attach(target, dt, true) then
									track = target_tracks[track_key(target)]
								else
									tp_msg = "attach fail"
								end
							else
								active_attach_target = target
							end
							if gun_blocked then
								remote_status = blocked_gun_status(held)
								tp_msg = tp_msg .. " | weapon blocked"
							end

							local ff_tag = ""
							if target and not gun_blocked then
								if cfg.ff_check and has_forcefield(target) then
									ff_tag = " | FF"
									remote_status = "ForceField — waiting"
								else
									local aim = aim_part(target, cfg.hitbox)
										or aim_part(target, "Head")
										or aim_part(target, "HumanoidRootPart")
										or hrp(target)
									if aim then
										fire_mouse_pos(part_aim_pos(aim) or aim.Position, aim)
									end
									rage_shoot_target(target)
								end
							end

							local primary = target and target.Name or "?"
							local dead_tag = dead_n > 0 and (" | " .. tostring(dead_n) .. " dead") or ""
							status = primary
								.. " +"
								.. tostring(math.max(0, alive_n - 1))
								.. dead_tag
								.. ff_tag
								.. " | "
								.. tp_msg
								.. " | "
								.. remote_status
						end
					end
				end
			else
				active_attach_target = nil
				status = "OFF"
			end

			local attaching = active_attach_target ~= nil and cfg.tp and rage_active()
			local loop_on, looper, loop_d = anti_loop_pressure(me, now, active_attach_target)
			if attaching then
				loop_on = false
			end
			if loop_on and cfg.no_void_kill then
				set_no_void_kill(true)
			end

			local hid, hide_mode = false, nil

			if attaching or (rage_active() and cfg.tp and active_attach_target) then
				void_pulse = false
				void_bait_peek = false
			elseif not attaching then
				local force_void = loop_on
				hid, hide_mode = apply_void_hide(lplr_pos, now, force_void)
				if loop_on and me and hid then
					apply_anti_vel(me, now)
				end
			elseif void_pulse or void_bait_peek then
				void_pulse = false
				void_bait_peek = false
			end

			if hid or hide_mode == "jitter" then
				local tag = hide_mode or "void"
				if loop_on and looper then
					tag = "anti-loop " .. looper.Name .. " (" .. string.format("%.0f", loop_d) .. ")"
				elseif tag == "void" or tag == "anti-loop" then
					tag = "void hide"
				end
				if status == "OFF" or not did_rage then
					status = tag
				else
					status = tostring(status) .. " | " .. tag
				end
			elseif loop_on and looper and (status == "OFF" or not did_rage) then
				status = "loop pressure " .. looper.Name
			end
			refresh_status_box()
		end

		local function bind_signal(signal, fn, name)
			if not signal then
				return
			end
			local ok, conn = pcall(function()
				return signal:Connect(fn)
			end)
			if ok and conn then
				connections[#connections + 1] = conn
				print("[HC] connected", name or "?")
			end
		end

		bind_signal(RunService.Heartbeat, function(dt)
			on_heartbeat(dt)
			if not menu_open() then
				update_hit_tracers()
			end
		end, "Heartbeat")

		bind_signal(UserInputService.InputBegan, function(input)
			local code = keycode_of(input)
			if is_slash_key(code) then
				chat_typing_guess = true
				typing_cache = true
				typing_cache_at = tick()
			elseif is_chat_end_key(code) then
				chat_typing_guess = false
				typing_cache_at = 0
			end
		end, "InputBegan")

		pcall(function()
			if RunService.RenderStepped then
				bind_signal(RunService.RenderStepped, on_attach_render, "RenderStepped")
			elseif RunService.PreRender then
				bind_signal(RunService.PreRender, on_attach_render, "PreRender")
			end
		end)
		pcall(function()
			if drawing_available() and typeof(WorldToScreen) == "function" then
				print("[HC] Drawing + WorldToScreen ok — hit tracers enabled")
			else
				warn("[HC] Drawing/WorldToScreen missing — tracers disabled")
			end
		end)

		_G.hc_ragebot_unload = function()
			running = false
			for i = 1, #connections do
				pcall(function()
					connections[i]:Disconnect()
				end)
				connections[i] = nil
			end
			clear_hit_tracers()
			active_attach_target = nil
			last_random_off = nil
			last_random_t = 0
			for n in pairs(selected_targets) do
				selected_targets[n] = nil
			end
			lplr_pos = nil
			saved_cf = nil
			return_cf = nil
			kill_returned = false
			void_pulse = false
			void_bait_peek = false
			void_safe_cf = nil
			closest_cache.plr = nil
			closest_cache.d = math.huge
			closest_cache.t = 0
			for k in pairs(target_tracks) do
				target_tracks[k] = nil
			end
			no_void_kill_on = false
			set_no_void_kill(false)
			pcall(function()
				if status_box then
					status_box:Remove()
				end
			end)
			status_box = nil
			status_box_lines = nil
			pcall(function()
				if win then
					if win.Unload then
						win:Unload()
					else
						win:Destroy()
					end
				elseif Lib then
					if Lib.Unload then
						Lib:Unload()
					else
						Lib:Destroy()
					end
				end
			end)
			win = nil
			Lib = nil
			_G.hc_ragebot_unload = nil
		end

		pcall(function()
			Lib:Notify(SCRIPT_NAME, "ready — P menu, C rage, V void (blocked off-focus / typing)", 4, "success")
		end)
		print(
			"[HC] Matcha ragebot ready",
			GAME_KIND,
			"INSUI",
			"agg",
			cfg.aggressive,
			"void",
			cfg.void_method,
			"write",
			cfg.tp_write,
			offsets_hud_line()
		)
	end
	hc_ragebot_rest()
end
hc_ragebot_main()
