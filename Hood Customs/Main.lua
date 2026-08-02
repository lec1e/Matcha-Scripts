if _G.hc_ragebot_unload then
	pcall(_G.hc_ragebot_unload)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local connections = {}
local Lib, win

local HITBOXES = { "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "Torso" }
local TP_MODES = { "Sticky", "Strafe", "Random teleport", "Above", "Behind", "In Front", "Orbit" }
local ON_KILL_RETURNS = { "Position", "Void", "None" }
local DEFAULT_TRACER_COLOR = Color3.fromRGB(0, 213, 255)

print("[HC] load", getgamename(), LP and LP.Name)

local function get_main_event()
	return ReplicatedStorage:FindFirstChild("MainEvent")
end

local event = get_main_event()
print("[HC] event", event and event:GetFullName() or "NIL")

local running = true
local last_shoot = 0
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

local cfg = {
	on = false,
	tp = true,
	face = true,
	tp_mode = "Sticky",
	radius = 3,
	y = 2,
	strafe_speed = 50,
	shoot = true,
	hitbox = "Head",
	delay = 0,
	burst = 4,
	pred = 0.06,
	ff_check = true,
	stomp = true,
	tp_back = true,
	stomp_h = 2.5,
	on_kill_return = "Position",
	void_hide = false,
	void_interval = 0.1,
	void_time = 0.1,
	no_void_kill = true,
	anti_loop = false,
	anti_loop_range = 20,
	anti_loop_jitter = true,
	anti_loop_vel = false,
	chase = true,
	attach_lead = 0.04,
	sticky_speed = 30,
	hit_tracers = true,
	tracer_life = 0.55,
	tracer_color = DEFAULT_TRACER_COLOR,
	tracer_thick = 1.5,
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
local last_void_end = 0
local void_safe_cf = nil
local saved_fallen_height = nil
local target_tracks = {}
local closest_cache = { plr = nil, d = math.huge, t = 0 }
local last_anti_jitter = 0
local last_anti_vel = 0
local no_void_kill_on = false

local function chars_folder()
	local p = Workspace:FindFirstChild("Players")
	return p and p:FindFirstChild("Characters")
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
	return m and (m:FindFirstChild("SpecialParts") or m)
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
	part = find_part(s, "Head")
		or find_part(s, "UpperTorso")
		or find_part(s, "HumanoidRootPart")
	if part then
		return part
	end
	return hrp(plr)
end

local function body_effects(plr)
	local m = hc_model(plr)
	return m and m:FindFirstChild("BodyEffects")
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
	if not plr then
		return false
	end
	return ko_flag(plr) and not dead_flag(plr)
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

local function pick_primary(prefer_alive, skip_ff)
	local best, best_d = nil, math.huge
	local best_ff, best_ff_d = nil, math.huge
	for name in pairs(selected_targets) do
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
			speed = 0,
			t = now,
			spike = false,
		}
		target_tracks[key] = tr
		return tr
	end

	local dt = now - tr.t
	if dt <= 0.001 or dt > 0.5 then
		tr.px, tr.py, tr.pz = pos.X, pos.Y, pos.Z
		tr.t = now
		tr.spike = false
		return tr
	end

	local dx = pos.X - tr.px
	local dy = pos.Y - tr.py
	local dz = pos.Z - tr.pz
	local mag = math.sqrt(dx * dx + dy * dy + dz * dz)
	tr.t = now
	tr.px, tr.py, tr.pz = pos.X, pos.Y, pos.Z

	if mag >= 500 or (typeof(pos.Y) == "number" and pos.Y < -50000) then
		tr.spike = true
		tr.vx, tr.vy, tr.vz, tr.speed = 0, 0, 0, 0
		return tr
	end

	tr.spike = mag >= 55
	if tr.spike then
		tr.vx, tr.vy, tr.vz, tr.speed = 0, 0, 0, 0
		return tr
	end

	local ivx, ivy, ivz = dx / dt, dy / dt, dz / dt
	local avx, avy, avz = get_part_vel(part)
	local av_speed = math.sqrt(avx * avx + avy * avy + avz * avz)
	if av_speed > 2 and av_speed < 400 then
		ivx = ivx * 0.45 + avx * 0.55
		ivy = ivy * 0.45 + avy * 0.55
		ivz = ivz * 0.45 + avz * 0.55
	end

	tr.vx = tr.vx * 0.55 + ivx * 0.45
	tr.vy = tr.vy * 0.55 + ivy * 0.45
	tr.vz = tr.vz * 0.55 + ivz * 0.45
	tr.speed = math.sqrt(tr.vx * tr.vx + tr.vz * tr.vz)
	tr.sx, tr.sy, tr.sz = pos.X, pos.Y, pos.Z
	return tr
end

local function resolved_target_pos(plr, part, now, lead)
	local tr = update_target_track(plr, part, now)
	local px, py, pz = part.Position.X, part.Position.Y, part.Position.Z
	if not tr then
		return px, py, pz, 0
	end

	if cfg.chase then
		if tr.spike or (typeof(py) == "number" and py < -50000) then
			px, py, pz = tr.sx, tr.sy, tr.sz
		end
		lead = lead or 0
		if lead > 0 and not tr.spike then
			px = px + tr.vx * lead
			py = py + tr.vy * lead * 0.35
			pz = pz + tr.vz * lead
		end
	end
	return px, py, pz, tr.speed or 0
end

local function apply_cf(cf)
	if not cf then
		return false
	end
	local ok = false
	local zero = Vector3.new()
	local function write(part)
		if not part then
			return
		end
		pcall(function()
			part.CFrame = cf
			part.AssemblyLinearVelocity = zero
			part.AssemblyAngularVelocity = zero
		end)
		pcall(function()
			part.Velocity = zero
			part.RotVelocity = zero
		end)
		ok = true
	end
	local me = hrp(LP)
	write(me)
	if LP.Character then
		local char_hrp = LP.Character:FindFirstChild("HumanoidRootPart")
		if char_hrp and char_hrp ~= me then
			write(char_hrp)
		end
	end
	return ok
end

local function rage_active()
	if rage_handle then
		local ok, on = pcall(function()
			return rage_handle:IsActivated()
		end)
		if ok then
			cfg.on = on == true
			return on == true
		end
	end
	return cfg.on == true
end

local function void_hide_active()
	if void_hide_handle then
		local ok, on = pcall(function()
			return void_hide_handle:IsActivated()
		end)
		if ok then
			return on == true
		end
	end
	return cfg.void_hide == true
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
		apply_cf(lplr_pos)
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
	apply_cf(lplr_pos)
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
	apply_cf(cf_xyz(bx + math.cos(ang) * j, by, bz + math.sin(ang) * j))
	return true
end

local function apply_void_hide(base_cf, now, force_anti)
	local manual = void_hide_active()
	if not manual and not force_anti then
		if void_pulse and void_safe_cf then
			apply_cf(void_safe_cf)
		end
		void_pulse = false
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

	local interval = cfg.void_interval or 0.1
	local dur = cfg.void_time or 0.1
	if force_anti and not manual then
		interval = math.max(interval, 0.1)
		dur = math.min(dur, 0.08)
	end

	if void_pulse then
		if now >= void_pulse_until then
			void_pulse = false
			last_void_end = now
			if void_safe_cf then
				apply_cf(void_safe_cf)
			else
				apply_cf(base_cf)
			end
			return false, "restore"
		end
	elseif (now - last_void_end) >= interval then
		void_pulse = true
		void_pulse_until = now + dur
	else
		if force_anti and apply_anti_jitter(base_cf, now) then
			return false, "jitter"
		end
		return false, nil
	end

	if not void_pulse then
		return false, nil
	end

	local bx, by, bz = base_cf.X, base_cf.Y, base_cf.Z
	local spread = force_anti and 16 or 20
	local rx = math.random(-spread, spread)
	local rz = math.random(-spread, spread)
	apply_cf(cf_xyz(bx - rx, by - (9e9 - 1000), bz - rz))
	return true, force_anti and "anti-loop" or "void"
end

local function attach_cf(target_hrp, mode, aim_x, aim_y, aim_z)
	if not target_hrp then
		return nil
	end
	local tpos = target_hrp.Position
	local tx = aim_x or tpos.X
	local ty = aim_y or tpos.Y
	local tz = aim_z or tpos.Z
	local tcf = target_hrp.CFrame
	local h = cfg.radius or 3
	local v = cfg.y or 2
	local speed = cfg.strafe_speed or 50
	mode = mode or "Sticky"

	local nx, ny, nz = tx, ty + v, tz
	local yaw = 0

	if mode == "Sticky" then
		nx, ny, nz = tx, ty + v, tz
	elseif mode == "Strafe" or mode == "Orbit" then
		yaw = math.fmod(tick() * speed * 0.35, math.pi * 2)
		local off = (CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, h)).Position
		nx, ny, nz = tx + off.X, ty + v, tz + off.Z
	elseif mode == "Random teleport" or mode == "Random" then
		local now = tick()
		if (not last_random_off) or (now - last_random_t) >= 0.1 then
			last_random_off = {
				x = (math.random() * 2 - 1) * h,
				y = (math.random() * 2 - 1) * math.min(math.abs(v), 3),
				z = (math.random() * 2 - 1) * h,
			}
			last_random_t = now
		end
		nx = tx - last_random_off.x
		ny = ty + v - last_random_off.y
		nz = tz - last_random_off.z
	elseif mode == "Behind" then
		local lv = tcf.LookVector
		nx, ny, nz = tx - lv.X * h, ty + v, tz - lv.Z * h
	elseif mode == "In Front" then
		local lv = tcf.LookVector
		nx, ny, nz = tx + lv.X * h, ty + v, tz + lv.Z * h
	elseif mode == "Above" then
		nx, ny, nz = tx, ty + h + v, tz
	end

	local look = Vector3.new(tx, ty, tz)
	if cfg.face then
		return cf_look(Vector3.new(nx, ny, nz), look)
	end
	if mode == "Strafe" or mode == "Orbit" then
		return cf_xyz(nx, ny, nz) * CFrame.Angles(0, yaw, 0)
	end
	return cf_xyz(nx, ny, nz)
end

local function snap_attach(target)
	if not target or not cfg.tp or dead(target) then
		return false
	end
	local th = hrp(target)
	if not th then
		return false
	end

	local me = hrp(LP)
	remember_return_cf(me)

	local tx, ty, tz = th.Position.X, th.Position.Y, th.Position.Z
	if cfg.chase then
		local tr = update_target_track(target, th, tick())
		if tr and not tr.spike then
			local lead = cfg.attach_lead or 0.04
			tx = tx + (tr.vx or 0) * lead
			ty = ty + (tr.vy or 0) * lead * 0.2
			tz = tz + (tr.vz or 0) * lead
		end
	end

	local cf = attach_cf(th, cfg.tp_mode or "Sticky", tx, ty, tz)
	if not cf then
		return false
	end

	apply_cf(cf)
	lplr_pos = cf
	active_attach_target = target
	return true
end

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

local function get_gun_origin()
	local char = LP.Character
	if char then
		local tool = char:FindFirstChildOfClass("Tool")
		if tool then
			local muzzle = nil
			for _, d in tool:GetDescendants() do
				if d:IsA("Attachment") then
					local n = string.lower(d.Name)
					if string.find(n, "muzzle", 1, true)
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
			local handle = tool:FindFirstChild("Handle")
			if handle then
				local lv = handle.CFrame.LookVector
				return Vector3.new(handle.Position.X + lv.X * 1.8, handle.Position.Y + lv.Y * 1.8, handle.Position.Z + lv.Z * 1.8)
			end
		end
	end
	local me = hrp(LP)
	if me then
		local lv = me.CFrame.LookVector
		return Vector3.new(me.Position.X + lv.X * 2.2, me.Position.Y + 1.35 + lv.Y * 2.2, me.Position.Z + lv.Z * 2.2)
	end
	return nil
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

local function make_hit(part, pred, track_vel)
	local center = part.Position
	local hit_pos = center
	local vx, vy, vz = 0, 0, 0

	pred = pred or 0
	if pred > 0 then
		vx, vy, vz = get_part_vel(part)
		local part_speed = math.sqrt(vx * vx + vy * vy + vz * vz)
		if track_vel and (part_speed < 4 or part_speed > 500) then
			vx = track_vel.vx or 0
			vy = track_vel.vy or 0
			vz = track_vel.vz or 0
		elseif track_vel and track_vel.speed and track_vel.speed > part_speed then
			vx = vx * 0.35 + (track_vel.vx or 0) * 0.65
			vy = vy * 0.35 + (track_vel.vy or 0) * 0.65
			vz = vz * 0.35 + (track_vel.vz or 0) * 0.65
		end
		hit_pos = Vector3.new(center.X + vx * pred, center.Y + vy * pred, center.Z + vz * pred)
		local dx = hit_pos.X - center.X
		local dy = hit_pos.Y - center.Y
		local dz = hit_pos.Z - center.Z
		local d = math.sqrt(dx * dx + dy * dy + dz * dz)
		local max_off = cfg.chase and 1.6 or 0.9
		if d > max_off and d > 0 then
			local s = max_off / d
			hit_pos = Vector3.new(center.X + dx * s, center.Y + dy * s, center.Z + dz * s)
		end
	end

	local offset = Vector3.new(0, 0, 0)
	pcall(function()
		offset = part.CFrame:PointToObjectSpace(hit_pos)
	end)
	return hit_pos, offset
end

local function fire_mouse_pos(pos)
	event = event or get_main_event()
	if not event or not pos then
		return
	end
	last_mouse_pos = pos
	pcall(function()
		event:FireServer("MousePosUpdate", pos)
	end)
end

local function build_shoot_payload(part, pred, track_vel)
	local hit_pos, offset = make_hit(part, pred, track_vel)
	local gun_origin = get_gun_origin()
	local origin = gun_origin or select(1, shoot_origin())
	if not origin then
		return nil
	end

	local dx = hit_pos.X - origin.X
	local dy = hit_pos.Y - origin.Y
	local dz = hit_pos.Z - origin.Z
	local mag = math.sqrt(dx * dx + dy * dy + dz * dz)

	if mag < 3 then
		local me = hrp(LP)
		local back = Vector3.new(0, 0, -1)
		pcall(function()
			if me then
				local lv = me.CFrame.LookVector
				back = Vector3.new(lv.X, lv.Y * 0.25, lv.Z)
				if back.Magnitude < 0.05 then
					back = Vector3.new(0, 0, -1)
				else
					back = back.Unit
				end
			end
		end)
		origin = Vector3.new(hit_pos.X - back.X * 8, hit_pos.Y - back.Y * 8 + 1, hit_pos.Z - back.Z * 8)
		dx = hit_pos.X - origin.X
		dy = hit_pos.Y - origin.Y
		dz = hit_pos.Z - origin.Z
		mag = math.sqrt(dx * dx + dy * dy + dz * dz)
	end

	if mag < 0.001 then
		dx, dy, dz, mag = 0, 0, -1, 1
	end
	local ux, uy, uz = dx / mag, dy / mag, dz / mag

	local tracer_to = hit_pos
	pcall(function()
		tracer_to = part.Position
	end)
	local tracer_from = gun_origin or origin
	if gun_origin and tracer_to then
		local gx = tracer_to.X - gun_origin.X
		local gy = tracer_to.Y - gun_origin.Y
		local gz = tracer_to.Z - gun_origin.Z
		if math.sqrt(gx * gx + gy * gy + gz * gz) < 2.5 then
			tracer_from = origin
		end
	end

	return {
		{
			{
				Position = hit_pos,
				Normal = Vector3.new(-ux, -uy, -uz),
				Instance = part,
			},
		},
		{
			{
				thePart = part,
				theOffset = offset,
			},
		},
		origin,
		Vector3.new(hit_pos.X + ux * 80, hit_pos.Y + uy * 80, hit_pos.Z + uz * 80),
		server_time(),
	}, hit_pos, tracer_from, tracer_to
end

local function fire_shoot(part, pred, track_vel, times)
	event = event or get_main_event()
	if not event or not part then
		remote_status = event and "no part" or "no MainEvent"
		return false
	end

	local parent_ok = false
	pcall(function()
		parent_ok = part.Parent ~= nil
	end)
	if not parent_ok then
		remote_status = "stale part"
		return false
	end

	local payload, hit_pos, tracer_from, tracer_to = build_shoot_payload(part, pred, track_vel)
	if not payload then
		remote_status = "no origin"
		return false
	end

	fire_mouse_pos(hit_pos)

	times = times or 1
	if times < 1 then
		times = 1
	end

	local ok_any = false
	local err
	local fired = 0
	for _ = 1, times do
		local ok, e = pcall(function()
			event:FireServer("Shoot", payload)
		end)
		if ok then
			ok_any = true
			fired = fired + 1
		else
			err = e
			ok, e = pcall(function()
				event:FireServer("Shoot", payload[1], payload[2], payload[3], payload[4], payload[5])
			end)
			if ok then
				ok_any = true
				fired = fired + 1
			else
				err = e
			end
		end
	end

	if ok_any then
		shoot_fail_streak = 0
		remote_status = "Shoot x" .. tostring(fired) .. " → " .. part.Name
		if fired > 0 then
			local from = tracer_from or payload[3]
			local to = tracer_to or hit_pos
			if from and to then
				add_hit_tracer(from, to)
			end
		end
		return true, hit_pos
	end

	shoot_fail_streak = shoot_fail_streak + 1
	event = get_main_event()
	remote_status = "Shoot FAIL " .. tostring(err)
	return false, hit_pos
end

local function rage_shoot_target(target)
	if not cfg.shoot or not target or dead(target) or knocked(target) then
		return false
	end
	if cfg.ff_check and has_forcefield(target) then
		remote_status = "ForceField — waiting"
		return false
	end
	local hitbox = cfg.hitbox or "Head"
	local aim = aim_part(target, hitbox)
	if not aim then
		return false
	end
	local track = target_tracks[track_key(target)]
	local burst = cfg.burst or 4
	if burst < 1 then
		burst = 1
	end
	return fire_shoot(aim, cfg.pred or 0.06, track, burst)
end

local function on_attach_render()
	update_hit_tracers()
	if not running or not rage_active() then
		return
	end
	local target = active_attach_target
	if not target or dead(target) then
		return
	end
	if cfg.tp then
		snap_attach(target)
	end
	rage_shoot_target(target)
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
	local ok_load, result = pcall(function()
		return loadstring(game:HttpGet("https://raw.githubusercontent.com/lec1e/Matcha-UI-Libraries/refs/heads/main/INS%20UI.lua"))()
	end)
	Lib = (ok_load and result) or INSui
end

if not Lib then
	error("[HC] INS ui failed to load — check HttpGet / INSui global")
end

win = Lib:CreateWindow({
	title = "Hood Customs",
	subtitle = "Ragebot",
	size = Vector2.new(720, 800),
	menuKey = "p",
	configName = "hc_ragebot",
	configFolder = "hc_ragebot",
	checkboxStyle = true,
	smartFps = true,
	startOpen = true,
})

pcall(function()
	win:AddSettingsTab("cog")
end)

Lib:Category("RAGE")
local tab = win:Tab("Ragebot", "crosshair")

local rage = tab:Section("Ragebot", "Left", "multi-select targets — list auto-refreshes on leave")
rage_handle = rage:Toggle("Enabled", false, function(on)
	cfg.on = on == true
	status = cfg.on and "ON" or "OFF"
end)
pcall(function()
	rage_handle:AddKeybind("r", "Toggle")
end)
pcall(function()
	rage_handle:SetRisk()
end)

rage:Info("Targets update when players join/leave. Multi-select + searchable. Keybind: R")

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
	Lib:Notify("Hood Customs", "player list refreshed", 2, "success")
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
	return "Chars: " .. (chars_folder() and "OK" or "MISSING")
end)

local tp = tab:Section("Teleport", "Left", "smooth lock on RenderStepped")
tp:Toggle("Attach / Teleport", true, function(on)
	cfg.tp = on == true
end)
tp:Toggle("Face Target", true, function(on)
	cfg.face = on == true
end)
tp:Dropdown("Mode", { "Sticky" }, TP_MODES, false, function(v)
	cfg.tp_mode = (v and v[1]) or "Sticky"
end)
tp:Slider("Horizontal Offset", 3, 1, 0, 50, "", function(v)
	cfg.radius = v
end)
tp:Slider("Vertical Offset", 2, 0.5, -50, 50, "", function(v)
	cfg.y = v
end)
tp:Slider("Strafe Speed", 50, 1, 1, 100, "%", function(v)
	cfg.strafe_speed = v
end)
tp:Toggle("Chase Resolve", true, function(on)
	cfg.chase = on == true
end)
tp:Slider("Attach Lead", 0.04, 0.01, 0, 0.35, "s", function(v)
	cfg.attach_lead = v
end)
tp:Slider("Sticky Speed", 30, 1, 10, 120, "", function(v)
	cfg.sticky_speed = v
end)
tp:Info("Sticky = hard lock on target every Render + Heartbeat. Small offset = faster stick.")

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
shoot:Info("Head / UpperTorso = most reliable full hits on SpecialParts")
shoot:Slider("Burst", 4, 1, 1, 12, "", function(v)
	cfg.burst = v
end)
shoot:Slider("Prediction", 0.06, 0.01, 0, 0.25, "", function(v)
	cfg.pred = v
end)
shoot:Info("ForceField Check skips shooting until their FF is gone")

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

local anti = tab:Section("Anti Aim", "Right", "break enemy attach / target lock")
void_hide_handle = anti:Toggle("Void Hide", false, function(on)
	cfg.void_hide = on == true
	if cfg.void_hide and cfg.no_void_kill then
		set_no_void_kill(true)
	elseif not cfg.void_hide then
		set_no_void_kill(false)
	end
end)
pcall(function()
	void_hide_handle:AddKeybind("v", "Toggle")
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
anti:Slider("Void Interval", 0.1, 0.01, 0.05, 0.5, "s", function(v)
	cfg.void_interval = v
end)
anti:Slider("Void Time", 0.1, 0.01, 0.05, 0.5, "s", function(v)
	cfg.void_time = v
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

	if me then
		if is_void_y(me.Position.Y) and void_safe_cf then
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
		if #sel == 0 then
			active_attach_target = nil
			status = "no targets — pick from Targets"
		else
			local alive_n, dead_n = selected_alive_count()

			if alive_n == 0 then
				active_attach_target = nil
				local mode = cfg.on_kill_return or "Position"
				if mode == "Void" then
					local ok_ret = apply_kill_return(me, true)
					status = ok_ret and ("kill return Void — waiting respawn")
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
					apply_cf(lplr_pos)
				end
				did_rage = true
				local shootable = pick_primary(true, true) or pick_primary(true, false)
				local knocked_plr = cfg.stomp and pick_knocked() or nil

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
						apply_cf(lplr_pos)
						apply_cf(lplr_pos)
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
							apply_cf(lplr_pos)
						end
						saved_cf = nil
					end

					local target = shootable or pick_primary(false)
					if target and dead(target) then
						target = nil
					end

					local track = target and target_tracks[track_key(target)] or nil

					if target and cfg.tp then
						active_attach_target = target
						if snap_attach(target) then
							track = target_tracks[track_key(target)]
							tp_msg = (cfg.tp_mode == "Sticky") and "sticky lock" or ("tp " .. tostring(cfg.tp_mode))
						else
							tp_msg = "attach fail"
						end
					else
						active_attach_target = target
					end

					local ff_tag = ""
					if target then
						if cfg.ff_check and has_forcefield(target) then
							ff_tag = " | FF"
							remote_status = "ForceField — waiting"
						else
							rage_shoot_target(target)
							last_shoot = now
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

	local attaching = active_attach_target ~= nil and cfg.tp
	local loop_on, looper, loop_d = anti_loop_pressure(me, now, active_attach_target)
	if attaching then
		loop_on = false
	end
	if loop_on and cfg.no_void_kill then
		set_no_void_kill(true)
	end

	local hid, hide_mode = false, nil
	if not attaching then
		local force_void = loop_on
		hid, hide_mode = apply_void_hide(lplr_pos, now, force_void)
		if loop_on and me and hid then
			apply_anti_vel(me, now)
		end
	elseif void_pulse then
		void_pulse = false
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

bind_signal(RunService.Heartbeat, on_heartbeat, "Heartbeat")
bind_signal(RunService.Heartbeat, update_hit_tracers, "TracerHeartbeat")
local render_bound = false
pcall(function()
	if RunService.PreRender then
		bind_signal(RunService.PreRender, on_attach_render, "PreRender")
		render_bound = true
	end
end)
if not render_bound then
	bind_signal(RunService.RenderStepped, on_attach_render, "RenderStepped")
end
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
		if win then
			win:Destroy()
		elseif Lib then
			Lib:Destroy()
		end
	end)
	win = nil
	Lib = nil
	_G.hc_ragebot_unload = nil
end

pcall(function()
	Lib:Notify("Hood Customs", "Press P for menu — multi-select Targets", 4, "success")
end)
