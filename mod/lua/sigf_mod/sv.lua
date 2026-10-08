-- Overwatch Takeover: rogue white robots vs hero squads, a payload to escort, ultimates, revives.
util.AddNetworkString("ow_msg")

Ow = Ow or {}
Sigf.Battle.combine = 6
Sigf.Battle.rebels = 4
Sigf.Battle.combineWeapons = { "weapon_smg1", "weapon_ar2" }

local cart, startPos, goalPos, progress
local BLUE, ORANGE, GOLD, RED, PURPLE = Color(90, 190, 255), Color(255, 150, 30), Color(255, 220, 90), Color(255, 70, 60), Color(190, 90, 255)

local HEROES = {
	tracer = { name = "TRACER", model = "models/alyx.mdl", mat = "sigf/tracer", hp = 110, color = ORANGE, ult = "PULSE BOMB", line = "CHEERS, LOVE! THE CAVALRY'S HERE!" },
	soldier = { name = "SOLDIER: 76", model = "models/Humans/Group03/male_03.mdl", mat = "sigf/soldier", hp = 170, color = BLUE, ult = "TACTICAL VISOR", line = "I'VE GOT YOU IN MY SIGHTS." },
	reaper = { name = "REAPER", model = "models/Humans/Group03/male_07.mdl", mat = "sigf/reaper", hp = 220, color = PURPLE, ult = "DEATH BLOSSOM", line = "DIE, DIE, DIE!" },
}
local ORDER = { "tracer", "soldier", "reaper", "tracer", "soldier" }
local heroN = 0

local function send(kind, d)
	net.Start("ow_msg") net.WriteString(kind) net.WriteTable(d or {}) net.Broadcast()
end
Ow.Send = send

local function feed(killer, victim, color)
	send("feed", { a = killer, b = victim, r = color.r, g = color.g, b2 = color.b })
end

---------------------------------------------------------------- setup of the two sides
local function setupHero(e, key)
	local h = HEROES[key]
	e.OwHero = key
	e:SetModel(h.model)
	e:SetMaterial(h.mat)
	e:SetMaxHealth(h.hp) e:SetHealth(h.hp)
	e:SetNWString("ow_name", h.name)
	e:SetNWInt("ow_team", 1)
	e:SetNWInt("ow_max", h.hp)
	e.OwHist = {}
	Sigf.Sprite("sprites/light_glow02_add", e, 30, 2, { color = h.color })
end

local function setupOmnic(e, titan)
	e.OwOmnic = true
	e:SetMaterial("sigf/omnic")
	if titan then
		e:SetModel("models/combine_super_soldier.mdl")
		e:SetModelScale(1.7, 0)
		e:SetMaxHealth(650) e:SetHealth(650)
		e:SetNWString("ow_name", "OMNIC TITAN")
		e:SetNWInt("ow_max", 650)
		e.OwTitan = true
	else
		e:SetModelScale(1.12, 0)
		e:SetMaxHealth(70) e:SetHealth(70)
		e:SetNWString("ow_name", "OMNIC")
		e:SetNWInt("ow_max", 70)
	end
	e:SetNWInt("ow_team", 2)
end

Ow.MakeOmnic = setupOmnic
Ow.Progress = function(v) progress = v end
hook.Add("SigfBattleSpawn", "ow_spawn", function(e, side)
	if side == "combine" then
		setupOmnic(e, false)
	else
		heroN = heroN + 1
		setupHero(e, ORDER[(heroN - 1) % #ORDER + 1])
	end
end)

---------------------------------------------------------------- hit and death feedback
local lastSpark = {}
hook.Add("EntityTakeDamage", "ow_hit", function(t, dmg)
	if not IsValid(t) then return end
	local at = dmg:GetAttacker()
	if IsValid(at) and ((t.OwHero or t:IsPlayer()) and (at.OwHero or at:IsPlayer()) or (t.OwOmnic and at.OwOmnic)) and at ~= t then
		dmg:SetDamage(0)
		return true
	end
	if t.OwOmnic or t.OwHero then
		local now = CurTime()
		if (lastSpark[t] or 0) < now - 0.12 then
			lastSpark[t] = now
			Sigf.Effect(t.OwOmnic and "ManhackSparks" or "Sparks", dmg:GetDamagePosition() ~= vector_origin and dmg:GetDamagePosition() or t:WorldSpaceCenter())
		end
		-- Tracer: recall when badly hurt (rewind position and health).
		if t.OwHero == "tracer" and (t.OwRecallAt or 0) < now and t:Health() - dmg:GetDamage() < 35 then
			t.OwRecallAt = now + 12
			dmg:SetDamage(0)
			local from = t:GetPos()
			local back = t.OwHist and t.OwHist[1]
			Sigf.Sprite("sigf/pulse", from + Vector(0, 0, 40), 90, 1.2, { color = BLUE })
			Sigf.Sound("sigf/recall.wav", from, 90, 100)
			if back then Sigf.Teleport(t, back, Vector(0, 0, 0)) end
			t:SetHealth(t:GetMaxHealth())
			Sigf.Sprite("sigf/pulse", t:GetPos() + Vector(0, 0, 40), 90, 1.2, { color = BLUE })
			Sigf.Text("TRACER: RECALL!", 2, { y = 0.3, size = 40, color = BLUE })
		end
	end
end)

local gibs = { "models/gibs/manhack_gib01.mdl", "models/gibs/manhack_gib02.mdl", "models/gibs/manhack_gib03.mdl", "models/gibs/manhack_gib04.mdl" }
local streak, streakAt = 0, 0
local ultWindow = {}

hook.Add("OnNPCKilled", "ow_kill", function(npc, attacker, inflictor)
	local pos = npc:WorldSpaceCenter()
	if npc.OwOmnic then
		Sigf.Sound("sigf/robodie.wav", pos, 85, 110)
		Sigf.Effect("Explosion", pos)
		for i = 1, npc.OwTitan and 8 or 3 do
			local g = Sigf.Prop(gibs[math.random(#gibs)], pos + VectorRand() * 12, 1.5, 15)
			if IsValid(g) then
				g:SetMaterial("sigf/omnic")
				local p = g:GetPhysicsObject()
				if IsValid(p) then p:SetVelocity(VectorRand() * 300 + Vector(0, 0, 350)) end
			end
		end
		local who = "A HERO"
		if IsValid(attacker) then
			who = attacker:IsPlayer() and string.upper(attacker:Nick()) or attacker:GetNWString("ow_name", "A HERO")
			if who == "" then who = "A HERO" end
		end
		feed(who, npc:GetNWString("ow_name", "OMNIC"), GOLD)
		for k, w in pairs(ultWindow) do if w.til > CurTime() then w.kills = w.kills + 1 end end
		if IsValid(attacker) and attacker:IsPlayer() then
			if CurTime() - streakAt > 6 then streak = 0 end
			streak = streak + 1 streakAt = CurTime()
			send("medal", { text = streak >= 3 and ("KILL STREAK x" .. streak) or "ELIMINATION", n = streak })
			Ow.Charge = math.min(100, (Ow.Charge or 0) + (npc.OwTitan and 60 or 22))
			SetGlobalInt("ow_ult", Ow.Charge)
		end
		Ow.Kills = (Ow.Kills or 0) + 1
		SetGlobalInt("ow_kills", Ow.Kills)
	elseif npc.OwHero then
		local h = HEROES[npc.OwHero]
		local who = IsValid(attacker) and attacker:GetNWString("ow_name", "OMNIC") or "OMNIC"
		feed(who, h.name, RED)
		-- Mercy resurrects most fallen heroes.
		if math.random() < 0.75 then
			local key = npc.OwHero
			Sigf.Sprite("sigf/wings", pos + Vector(0, 0, 50), 110, 3, { color = GOLD })
			Sigf.After(2.2, function()
				local e = Sigf.NPC("npc_citizen", Sigf.Ground(pos, 80), { weapon = "weapon_smg1", keys = { citizentype = 3 } })
				if not IsValid(e) then return end
				e.SigfSide = "rebel"
				setupHero(e, key)
				Sigf.Sound("sigf/revive.wav", e:GetPos(), 90, 100)
				Sigf.Effect("balloon_pop", e:WorldSpaceCenter(), { color = 3 })
				Sigf.Text("MERCY: HEROES NEVER DIE!", 2.5, { y = 0.3, size = 40, color = GOLD })
			end)
		end
	end
end)

---------------------------------------------------------------- hero abilities
local function nearestOmnic(pos, r)
	local best, bd = nil, (r or 1200) ^ 2
	for _, n in ipairs(Sigf.NPCs()) do
		if n.OwOmnic then
			local d = n:GetPos():DistToSqr(pos)
			if d < bd then best, bd = n, d end
		end
	end
	return best
end

-- history for recall + tracer blink toward the enemy
Sigf.Every(0.5, function()
	for _, n in ipairs(Sigf.NPCs()) do
		if n.OwHero and n.OwHist then
			table.insert(n.OwHist, n:GetPos())
			if #n.OwHist > 6 then table.remove(n.OwHist, 1) end
		end
	end
end)

Sigf.Every(3.2, function()
	for _, n in ipairs(Sigf.NPCs()) do
		if n.OwHero == "tracer" then
			local t = IsValid(n:GetEnemy()) and n:GetEnemy() or nearestOmnic(n:GetPos(), 1400)
			if IsValid(t) and n:GetPos():Distance(t:GetPos()) > 300 then
				local dir = (t:GetPos() - n:GetPos()) dir.z = 0 dir:Normalize()
				local from = n:GetPos()
				local to = Sigf.Ground(from + dir * 260, 60)
				Sigf.Sprite("sigf/pulse", from + Vector(0, 0, 40), 60, 0.5, { color = BLUE })
				Sigf.Teleport(n, to + Vector(0, 0, 4), nil)
				Sigf.Sprite("sigf/pulse", to + Vector(0, 0, 40), 70, 0.6, { color = BLUE })
				Sigf.Sound("sigf/blink.wav", to, 85, 100)
			end
		elseif n.OwHero == "soldier" and IsValid(n:GetEnemy()) and math.random() < 0.5 then
			-- helix rockets: three small blasts on the target
			local t = n:GetEnemy()
			for i = 0, 2 do
				Sigf.After(0.25 * i, function()
					if IsValid(t) and IsValid(n) then
						Sigf.Sprite("sprites/light_glow02_add", n:WorldSpaceCenter() + n:GetForward() * 30, 24, 0.3, { color = ORANGE })
						Sigf.Explode(t:GetPos() + VectorRand() * 30, 110, 45, n)
					end
				end)
			end
		end
	end
end)

---------------------------------------------------------------- ultimates
local function potg(key, hero, color)
	ultWindow[key] = { kills = 0, til = CurTime() + 5 }
	Sigf.After(5.2, function()
		local w = ultWindow[key]
		ultWindow[key] = nil
		if w and w.kills >= 3 then send("potg", { hero = hero, kills = w.kills }) end
	end)
end

local function pharahRain(center, attacker)
	Sigf.Text("JUSTICE RAINS FROM ABOVE!", 3, { y = 0.25, size = 56, color = ORANGE })
	Sigf.Sound2D("sigf/ult.wav")
	for i = 0, 13 do
		Sigf.After(0.25 * i, function()
			local tgt = Sigf.Ground(center, 380)
			local r = Sigf.Prop("models/weapons/w_missile_closed.mdl", tgt + Vector(0, 0, 900), 2, 3)
			if IsValid(r) then
				r:SetAngles(Angle(90, 0, 0))
				local p = r:GetPhysicsObject()
				if IsValid(p) then p:EnableGravity(false) p:SetVelocity(Vector(0, 0, -1500)) end
				Sigf.Sprite("sprites/light_glow02_add", r, 70, 1, { color = ORANGE })
				Sigf.After(0.58, function()
					if IsValid(r) then r:Remove() end
					Sigf.Explode(tgt, 230, 90, attacker)
					Sigf.Shake(tgt, 6, 0.5)
				end)
			end
		end)
	end
end

function Ow.HostUlt()
	local host = Sigf.Host()
	if not IsValid(host) or (Ow.Charge or 0) < 100 then return false end
	Ow.Charge = 0
	SetGlobalInt("ow_ult", 0)
	potg("host", string.upper(host:Nick()))
	pharahRain(Sigf.Front(450), host)
	return true
end

hook.Add("PlayerButtonDown", "ow_key", function(ply, btn)
	if btn == KEY_Q and ply == Sigf.Host() then Ow.HostUlt() end
end)

local function heroUlt(n)
	local h = HEROES[n.OwHero]
	Sigf.Text(h.name .. ": " .. h.ult .. "!", 3, { y = 0.25, size = 52, color = h.color })
	Sigf.Sound2D("sigf/ult.wav")
	local id = tostring(n)
	potg(id, h.name)
	if n.OwHero == "tracer" then
		local t = nearestOmnic(n:GetPos(), 1500)
		if not IsValid(t) then return end
		local tp = t:GetPos()
		Sigf.Sprite("sigf/pulse", tp + Vector(0, 0, 60), 100, 1.4, { color = BLUE })
		Sigf.After(1.4, function()
			Sigf.Effect("HelicopterMegaBomb", tp + Vector(0, 0, 30))
			Sigf.Sprite("sigf/pulse", tp + Vector(0, 0, 60), 350, 0.5, { color = BLUE })
			Sigf.Explode(tp, 340, 400, n)
			Sigf.Shake(tp, 12, 1)
		end)
	elseif n.OwHero == "soldier" then
		for i = 0, 9 do
			Sigf.After(0.3 * i, function()
				if not IsValid(n) then return end
				local t = nearestOmnic(n:GetPos(), 1600)
				if IsValid(t) then
					Sigf.Sprite("sigf/pulse", t:WorldSpaceCenter(), 40, 0.25, { color = RED })
					local d = DamageInfo() d:SetDamage(55) d:SetAttacker(n) d:SetInflictor(n) d:SetDamageType(DMG_BULLET)
					t:TakeDamageInfo(d)
				end
			end)
		end
	elseif n.OwHero == "reaper" then
		for i = 0, 7 do
			Sigf.After(0.35 * i, function()
				if not IsValid(n) then return end
				Sigf.Effect("VortDispel", n:GetPos() + Vector(0, 0, 30))
				Sigf.Sprite("sigf/pulse", n:GetPos() + Vector(0, 0, 40), 220, 0.4, { color = PURPLE })
				Sigf.Explode(n:GetPos(), 260, 40, n)
			end)
		end
	end
end

Sigf.Every(15, function()
	local list = {}
	for _, n in ipairs(Sigf.NPCs()) do if n.OwHero then list[#list + 1] = n end end
	local n = Sigf.Pick(list)
	if IsValid(n) and nearestOmnic(n:GetPos(), 1500) then heroUlt(n) end
end)
Ow.HeroUlt = heroUlt

---------------------------------------------------------------- titan boss
Sigf.Every(30, function()
	for _, n in ipairs(Sigf.NPCs()) do if n.OwTitan then return end end
	Ow.SpawnTitan()
end)
function Ow.SpawnTitan(pos)
	local e = Sigf.NPC("npc_combine_s", pos or Sigf.Ground(Sigf.Arena(), 900), { weapon = "weapon_ar2" })
	if not IsValid(e) then return end
	e.SigfSide = "combine"
	setupOmnic(e, true)
	Sigf.Text("WARNING: OMNIC TITAN INCOMING!", 3, { y = 0.25, size = 48, color = RED })
	Sigf.Sound2D("sigf/ult.wav")
	return e
end

---------------------------------------------------------------- payload
local function groundAt(p)
	local tr = util.TraceLine({ start = p + Vector(0, 0, 300), endpos = p - Vector(0, 0, 600), mask = MASK_SOLID_BRUSHONLY })
	return tr.Hit and tr.HitPos or p
end

local function newPayload()
	if IsValid(cart) then cart:Remove() end
	local c = Sigf.Arena()
	startPos = Sigf.Ground(c, 700)
	for _ = 1, 12 do
		goalPos = Sigf.Ground(c, 900)
		if goalPos:Distance(startPos) > 1000 then break end
	end
	progress = 0
	cart = Sigf.Prop("models/props_wasteland/laundry_cart001.mdl", startPos + Vector(0, 0, 20), 1.6, 0)
	if not IsValid(cart) then return end
	cart:SetMaterial("sigf/omnic")
	cart:SetColor(Color(255, 255, 255))
	local p = cart:GetPhysicsObject()
	if IsValid(p) then p:EnableMotion(false) end
	Sigf.Sprite("sprites/light_glow02_add", cart, 90, 0, { color = ORANGE })
	local dir = (goalPos - startPos) dir.z = 0
	cart:SetAngles(dir:Angle())
	SetGlobalEntity("ow_cart", cart)
	SetGlobalVector("ow_goal", goalPos)
end
Ow.NewPayload = newPayload

local function nearCount(pos, r)
	local f, o = 0, 0
	for _, a in ipairs(Sigf.Near(pos, r)) do
		if a.OwOmnic then o = o + 1 elseif a.OwHero or a:IsPlayer() then f = f + 1 end
	end
	return f, o
end

Sigf.Every(0.1, function()
	if not IsValid(cart) then return end
	local f, o = nearCount(cart:GetPos(), 420)
	local speed = 20
	if o > 0 then speed = 0 elseif f > 0 then speed = 90 end
	SetGlobalInt("ow_state", o > 0 and 2 or (f > 0 and 1 or 0))
	local len = startPos:Distance(goalPos)
	progress = math.min(1, progress + speed * 0.1 / len)
	local flat = LerpVector(progress, startPos, goalPos)
	local g = groundAt(flat)
	cart:SetPos(g + Vector(0, 0, 22))
	SetGlobalFloat("ow_prog", progress)
	if progress >= 1 then
		Sigf.Text("VICTORY", 5, { y = 0.3, size = 90, color = GOLD })
		Sigf.Sound2D("sigf/victory.wav")
		send("victory", {})
		for i = 1, 3 do Sigf.Effect("balloon_pop", cart:GetPos() + VectorRand() * 60 + Vector(0, 0, 60), { color = i }) end
		Ow.Caps = (Ow.Caps or 0) + 1
		SetGlobalInt("ow_caps", Ow.Caps)
		cart:Remove()
		Sigf.After(4, newPayload)
		cart = nil
	end
end)

-- Idle heroes escort the payload.
Sigf.Every(4, function()
	if not IsValid(cart) then return end
	for _, n in ipairs(Sigf.NPCs()) do
		if n.OwHero and not IsValid(n:GetEnemy()) then
			n:SetLastPosition(Sigf.Ground(cart:GetPos(), 150))
			n:SetSchedule(SCHED_FORCED_GO_RUN)
		end
	end
end)

Sigf.After(1, function()
	Ow.Charge = 0
	SetGlobalInt("ow_ult", 0)
	newPayload()
	send("intro", {})
	Sigf.Sound2D("sigf/ult.wav")
end)
