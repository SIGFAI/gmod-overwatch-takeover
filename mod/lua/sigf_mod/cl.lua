-- Overwatch Takeover: client HUD (objective bar, ultimate meter, kill feed, name tags, medals, play of the game).
local function F(name, size, weight)
	surface.CreateFont(name, { font = "Roboto", size = size, weight = weight or 800, antialias = true })
end
F("OwBig", 96, 900) F("OwMid", 44, 900) F("OwSm", 24, 800) F("OwTag", 20, 800) F("OwTiny", 16, 700)

local ORANGE, BLUE, RED, GOLD = Color(255, 150, 30), Color(70, 170, 255), Color(255, 70, 60), Color(255, 220, 90)
local feed, medal, potg, intro, victory = {}, nil, nil, nil, nil
local glow = Material("sigf/ultico")
local wings = Material("sigf/wings")

net.Receive("ow_msg", function()
	local kind = net.ReadString()
	local d = net.ReadTable()
	local now = RealTime()
	if kind == "feed" then
		feed[#feed + 1] = { a = d.a, b = d.b, col = Color(d.r, d.g, d.b2), die = now + 6 }
		while #feed > 6 do table.remove(feed, 1) end
	elseif kind == "medal" then medal = { text = d.text, t = now }
	elseif kind == "potg" then potg = { hero = d.hero, kills = d.kills, t = now }
	elseif kind == "intro" then intro = now
	elseif kind == "victory" then victory = now end
end)

local function sx(v) return v * ScrH() / 1080 end

local function tagged()
	local list = {}
	for _, e in ipairs(ents.GetAll()) do
		if e:IsNPC() and e:GetNWInt("ow_team", 0) > 0 and e:Health() > 0 then list[#list + 1] = e end
	end
	return list
end
local cache, cacheT = {}, 0

local function bar(x, y, w, h, frac, col)
	surface.SetDrawColor(0, 0, 0, 180) surface.DrawRect(x - 1, y - 1, w + 2, h + 2)
	surface.SetDrawColor(col.r, col.g, col.b, 255) surface.DrawRect(x, y, w * math.Clamp(frac, 0, 1), h)
end

local function slant(x, y, w, h, col)
	draw.NoTexture()
	surface.SetDrawColor(col)
	surface.DrawPoly({ { x = x + h * 0.4, y = y }, { x = x + w, y = y }, { x = x + w - h * 0.4, y = y + h }, { x = x, y = y + h } })
end

hook.Add("HUDPaint", "ow_hud", function()
	local W, H = ScrW(), ScrH()
	local now = RealTime()

	-- name tags and health bars
	if now - cacheT > 0.4 then cache = tagged() cacheT = now end
	local eye = EyePos()
	for _, e in ipairs(cache) do
		if IsValid(e) and e:Health() > 0 then
			local dist = eye:Distance(e:GetPos())
			if dist < 2200 then
				local p = (e:GetPos() + Vector(0, 0, e:OBBMaxs().z + 14)):ToScreen()
				if p.visible then
					local team = e:GetNWInt("ow_team")
					local c = team == 1 and BLUE or RED
					local a = math.Clamp(1 - (dist - 1400) / 800, 0.25, 1)
					local w = sx(90)
					bar(p.x - w / 2, p.y, w, sx(7), e:Health() / math.max(1, e:GetNWInt("ow_max", 100)), c)
					draw.SimpleTextOutlined(e:GetNWString("ow_name"), "OwTag", p.x, p.y - sx(4), Color(c.r, c.g, c.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, Color(0, 0, 0, 255 * a))
				end
			end
		end
	end

	-- top objective bar
	local prog = GetGlobalFloat("ow_prog", 0)
	local state = GetGlobalInt("ow_state", 0)
	local cx = W / 2
	local bw = sx(520)
	slant(cx - bw / 2, sx(18), bw, sx(40), Color(15, 20, 30, 215))
	local col = state == 2 and RED or (state == 1 and ORANGE or Color(200, 200, 200))
	draw.SimpleText("ESCORT THE PAYLOAD", "OwSm", cx, sx(28), Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	bar(cx - bw / 2 + sx(30), sx(46), bw - sx(60), sx(8), prog, col)
	local label = state == 2 and "CONTESTED!" or (state == 1 and "ESCORTING" or "NO ESCORT")
	draw.SimpleTextOutlined(math.floor(prog * 100) .. "%  " .. label, "OwTiny", cx, sx(72), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0))
	draw.SimpleTextOutlined("ELIMINATIONS " .. GetGlobalInt("ow_kills", 0) .. "   |   OBJECTIVES " .. GetGlobalInt("ow_caps", 0), "OwTiny", cx, sx(92), Color(230, 230, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0))

	-- payload marker
	local cart = GetGlobalEntity("ow_cart")
	if IsValid(cart) then
		local p = (cart:GetPos() + Vector(0, 0, 90)):ToScreen()
		local x, y = math.Clamp(p.x, 60, W - 60), math.Clamp(p.y, 130, H - 60)
		local d = math.floor(eye:Distance(cart:GetPos()) / 52)
		draw.NoTexture() surface.SetDrawColor(col)
		local s = sx(16) + math.sin(now * 5) * 2
		surface.DrawPoly({ { x = x, y = y - s }, { x = x + s, y = y }, { x = x, y = y + s }, { x = x - s, y = y } })
		draw.SimpleTextOutlined(d .. " m", "OwTag", x, y + s + 10, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0))
	end

	-- ultimate meter
	local ult = GetGlobalInt("ow_ult", 0)
	local ux, uy, ur = W - sx(130), H - sx(130), sx(62)
	draw.NoTexture() surface.SetDrawColor(10, 15, 25, 220)
	local pts = {}
	for i = 0, 40 do local a = i / 40 * math.pi * 2 pts[#pts + 1] = { x = ux + math.cos(a) * ur, y = uy + math.sin(a) * ur } end
	surface.DrawPoly(pts)
	local ready = ult >= 100
	local ring = ready and Color(255, 200 + math.sin(now * 8) * 55, 60) or ORANGE
	surface.SetDrawColor(ring)
	for i = 0, math.floor(ult / 100 * 60) do
		local a = -math.pi / 2 + i / 60 * math.pi * 2
		surface.DrawRect(ux + math.cos(a) * ur - 3, uy + math.sin(a) * ur - 3, 7, 7)
	end
	surface.SetMaterial(glow) surface.SetDrawColor(255, 255, 255, ready and 255 or 110)
	surface.DrawTexturedRect(ux - ur * 0.7, uy - ur * 0.7, ur * 1.4, ur * 1.4)
	draw.SimpleTextOutlined(ready and "READY" or (ult .. "%"), "OwSm", ux, uy + ur + sx(18), ring, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0))
	if ready then draw.SimpleTextOutlined("PRESS Q", "OwTiny", ux, uy - ur - sx(14), Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0)) end

	-- kill feed
	for i = #feed, 1, -1 do if now > feed[i].die then table.remove(feed, i) end end
	for i, f in ipairs(feed) do
		local y = sx(120) + (i - 1) * sx(30)
		surface.SetFont("OwTag")
		local txt = f.a .. "  >  " .. f.b
		local tw = surface.GetTextSize(txt)
		draw.RoundedBox(4, W - tw - sx(40), y, tw + sx(24), sx(26), Color(10, 15, 25, 200))
		draw.SimpleText(f.a, "OwTag", W - tw - sx(28), y + sx(13), Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local aw = surface.GetTextSize(f.a .. "  >  ")
		draw.SimpleText(f.b, "OwTag", W - tw - sx(28) + aw, y + sx(13), f.col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-- elimination medal
	if medal then
		local t = now - medal.t
		if t > 2.2 then medal = nil else
			local a = 255 * math.Clamp(2.2 - t, 0, 1)
			local s = 1 + math.max(0, 0.4 - t) * 2
			draw.SimpleTextOutlined(medal.text, "OwMid", W / 2, H * 0.68 - sx(10) * (t > 0.3 and 1 or 0), Color(255, 210, 70, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 3, Color(0, 0, 0, a))
		end
	end

	-- hero select intro banner
	if intro then
		local t = now - intro
		if t > 6 then intro = nil else
			local a = math.Clamp(math.min(t / 0.4, (6 - t) / 0.8), 0, 1)
			surface.SetDrawColor(10, 15, 25, 190 * a) surface.DrawRect(0, H * 0.34, W, sx(190))
			surface.SetDrawColor(255, 150, 30, 255 * a) surface.DrawRect(0, H * 0.34, W, sx(5)) surface.DrawRect(0, H * 0.34 + sx(185), W, sx(5))
			draw.SimpleTextOutlined("OVERWATCH TAKEOVER", "OwBig", W / 2, H * 0.34 + sx(70), Color(255, 255, 255, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 3, Color(255, 120, 0, 255 * a))
			draw.SimpleTextOutlined("ATTACK  -  ESCORT THE PAYLOAD  -  HEROES NEVER DIE", "OwMid", W / 2, H * 0.34 + sx(140), Color(255, 190, 80, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 255 * a))
		end
	end

	-- victory banner
	if victory then
		local t = now - victory
		if t > 5 then victory = nil else
			local a = math.Clamp(math.min(t / 0.3, (5 - t) / 0.8), 0, 1)
			surface.SetDrawColor(255, 160, 30, 90 * a) surface.DrawRect(0, H * 0.36, W, sx(150))
		end
	end

	-- play of the game
	if potg then
		local t = now - potg.t
		if t > 6 then potg = nil else
			local a = math.Clamp(math.min(t / 0.3, (6 - t) / 0.6), 0, 1)
			surface.SetDrawColor(0, 0, 0, 120 * a) surface.DrawRect(0, 0, W, H)
			surface.SetDrawColor(10, 15, 25, 230 * a) surface.DrawRect(0, H * 0.3, W, sx(260))
			surface.SetDrawColor(255, 150, 30, 255 * a) surface.DrawRect(0, H * 0.3, W, sx(6)) surface.DrawRect(0, H * 0.3 + sx(254), W, sx(6))
			draw.SimpleTextOutlined("PLAY OF THE GAME", "OwBig", W / 2, H * 0.3 + sx(80), Color(255, 255, 255, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 3, Color(255, 120, 0, 255 * a))
			draw.SimpleTextOutlined(potg.hero .. "  -  " .. potg.kills .. " ELIMINATIONS", "OwMid", W / 2, H * 0.3 + sx(170), Color(255, 210, 70, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 255 * a))
		end
	end
end)
