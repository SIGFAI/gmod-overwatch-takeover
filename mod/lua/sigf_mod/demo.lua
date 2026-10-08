-- Demo: robots vs heroes, medals, hero abilities, player ultimate, revive, payload victory.
local function omnic(dist, titan)
	local e = Sigf.BringNPC(dist or 320)
	if IsValid(e) then e.SigfSide = "combine" Ow.MakeOmnic(e, titan) end
	return e
end
local function hero(key)
	for _, n in ipairs(Sigf.NPCs()) do if n.OwHero == key then return n end end
end

Sigf.Demo(1, function() Sigf.Text("OVERWATCH TAKEOVER", 3, { y = 0.8 }) end)
Sigf.Demo(8, function()
	Sigf.Text("Rogue robots vs the heroes", 4, { y = 0.8 })
	local e = omnic(320)
	if not IsValid(e) then return end
	Sigf.LookAt(e, 2) Sigf.Shoot(1.0)
	Sigf.After(1.1, function() Sigf.KillByHost(e) end)
end)
Sigf.Demo(16, function()
	Sigf.Text("Tracer blinks and fires her Pulse Bomb", 4, { y = 0.8 })
	local t = hero("tracer")
	for i = 1, 3 do omnic(500) end
	if IsValid(t) then Ow.HeroUlt(t) end
end)
Sigf.Demo(26, function()
	Sigf.Text("Heroes never die: Mercy revives them", 4, { y = 0.8 })
	local h = hero("soldier") or hero("reaper")
	if IsValid(h) then h:SetHealth(1) h:TakeDamage(500, Sigf.Host(), Sigf.Host()) end
end)
Sigf.Demo(36, function()
	Sigf.Text("Kills charge your ULTIMATE", 3, { y = 0.8 })
	for i = 1, 4 do omnic(450) end
	Sigf.Pilot(false)
end)
Sigf.Demo(40, function()
	Sigf.Text("Press Q: Justice rains from above!", 4, { y = 0.8 })
	local h = Sigf.Host()
	for i = 1, 4 do local e = omnic(420) if IsValid(e) then e:SetPos(Sigf.Front(380 + i * 40) + VectorRand() * 60) end end
	Ow.Charge = 100 SetGlobalInt("ow_ult", 100)
	Sigf.After(1, function() Ow.HostUlt() end)
end)
Sigf.Demo(52, function() Sigf.Pilot(true) Sigf.Text("Omnic Titan boss incoming", 4, { y = 0.8 }) Ow.SpawnTitan(Sigf.Front(500)) end)
Sigf.Demo(62, function()
	Sigf.Text("Escort the payload to win", 4, { y = 0.8 })
	Ow.Progress(0.97)
end)
