-- Groove Select Module v0.0.3d

-- by dionednd

-- Commissioned by Jerry

local grooveSelect = {}

grooveSelect.GLOBAL_DEF_PATH = "external/mods/grooves.def"
grooveSelect.MOTIF_PATH = "external/mods/groove_motif.def"

-- selectState value we inject for groove select phase
local GROOVE_STATE = 5

grooveSelect.t_grooveDefs = {}

grooveSelect.t_selected = { {}, {} }

grooveSelect.menu = {}

grooveSelect.motif = loadIni(grooveSelect.MOTIF_PATH, true, false)

local function trim(s)
	return (s or ""):match("^%s*(.-)%s*$")
end

local function f_parseDef(path)
	local file = io.open(path, "r")
	if not file then return nil, nil end
	local parsed, order, current, count = {}, {}, nil, {}
	for raw in file:lines() do
		local line = trim(raw):gsub(";.*$", "")
		if line ~= "" then
			local sec = line:match("^%[(.-)%]$")
			if sec then
				local leadTrimmed = sec:match("^%s*(.*)$")
				local lower = leadTrimmed:lower()
				local grooveName = nil
				local _, kwEnd = lower:find("^groovedef%s+")
				if kwEnd then
					grooveName = leadTrimmed:sub(kwEnd + 1)
				end

				local display = trim(sec)
				local key = display:lower()
				count[key] = (count[key] or 0) + 1
				current = count[key] == 1 and key or (key .. "_" .. count[key])
				parsed[current] = { __name = display, __grooveName = grooveName }
				table.insert(order, current)
			elseif current then
				local k, v = line:match("^([^=]+)=(.*)$")
				if k then
					k = trim(k):lower()
					v = trim(v)

					if k == "color" then
						local color = {}
						for value in v:gmatch("[^,]+") do
							table.insert(color, tonumber(trim(value)))
						end

						parsed[current][k] = color
					else
						parsed[current][k] = v
					end
				end
			end
		end
	end
	file:close()
	return parsed, order
end

local function f_extractGrooves(parsed, order)
	local list, seen = {}, {}
	for _, sec in ipairs(order) do
		local s = parsed[sec]

		local name = s.__grooveName
		if not name or name == "" then goto skip end
		if s["enabled"] and tonumber(s["enabled"]) == 0 then goto skip end
		if seen[name] then goto skip end
		seen[name] = true
		table.insert(list, {
			name = name,
			map_name = (s["map_name"] ~= "" and s["map_name"]) or nil,
			map_value = (s["map_value"] ~= "" and s["map_value"]) or nil,
			color = {s["color"] and s["color"][1] or -1, s["color"] and s["color"][2] or -1, s["color"] and s["color"][3] or -1, s["color"] and s["color"][4] or -1}
		})
		::skip::
	end
	return list
end

local function f_loadGlobalGrooves()
	local parsed, order = f_parseDef(grooveSelect.GLOBAL_DEF_PATH)
	grooveSelect.t_grooveDefs["default"] = parsed and f_extractGrooves(parsed, order) or {}
end

local function f_loadCharGrooves(charRef, defPath)
	if grooveSelect.t_grooveDefs[charRef] ~= nil then return end
	local parsed, order = f_parseDef(defPath)
	if parsed then
		local list = f_extractGrooves(parsed, order)
		grooveSelect.t_grooveDefs[charRef] = (#list > 0) and list or false
	else
		grooveSelect.t_grooveDefs[charRef] = false
	end
end

local function f_getGrooveList(charRef)
	local c = grooveSelect.t_grooveDefs[charRef]
	if c and #c > 0 then return c end
	local d = grooveSelect.t_grooveDefs["default"]
	if d and #d > 0 then return d end
	return nil
end

local function f_initMenuState(side)
	grooveSelect.menu[side] = {
		active = false,
		member = 0,
		player = 0,
		charRef = nil,
		list = nil,
		cursorIdx = 1,
	}
	grooveSelect.t_selected[side] = {}
end

-- Resolve per-member motif tables (p3/p4/..), fallback to p1/p2 when undefined.
local function f_getMotifP(t, pn, side)
	if type(t) ~= "table" then return nil end
	local p = t["p" .. pn]
	if p ~= nil then return p end
	return t["p" .. side]
end

local function f_draw(side, member, item)
	local ms = grooveSelect.menu[side]
	local m = grooveSelect.motif
	local pn = 2 * (member - 1) + side
	-- f_getMotifP is defined in start.lua, accessible globally
	local pCfg = f_getMotifP(motif.select_info, pn, side)

	local chosen = ms.list[ms.cursorIdx]
	local grooveName = chosen and chosen.name or ""

	if pCfg.groovemenu and pCfg.groovemenu.title
	 and pCfg.groovemenu.title.TextSpriteData then
		textImgReset(pCfg.groovemenu.title.TextSpriteData)
		textImgDraw(pCfg.groovemenu.title.TextSpriteData)
	else
		local txt = textImgNew()
		textImgSetLocalcoord(txt, m.info.localcoord[1], m.info.localcoord[2])
		textImgSetFont(txt, motif.Fnt[m.groove_select['p' .. side].groove.title.font[1]] or motif.Fnt[1])
		textImgSetBank(txt, m.groove_select['p' .. side].groove.title.font[2])
		textImgSetAlign(txt, m.groove_select['p' .. side].groove.title.font[3])
		textImgSetText(txt, m.groove_select['p' .. side].groove.title.text)
		textImgSetPos(txt, m.groove_select['p' .. side].groove.title.offset[1], m.groove_select['p' .. side].groove.title.offset[2])
		textImgSetColor(txt, m.groove_select['p' .. side].groove.title.font[4], m.groove_select['p' .. side].groove.title.font[5], m.groove_select['p' .. side].groove.title.font[6])
		textImgSetScale(txt, m.groove_select['p' .. side].groove.title.scale[1], m.groove_select['p' .. side].groove.title.scale[1])
		textImgSetProjection(txt, m.groove_select['p' .. side].groove.title.projection)
		textImgSetLayerno(txt, 2)
		textImgDraw(txt)
	end

	if pCfg.groovemenu and pCfg.groovemenu.name
	 and pCfg.groovemenu.name.TextSpriteData then
		textImgReset(pCfg.groovemenu.name.TextSpriteData)
		textImgSetText(pCfg.groovemenu.name.TextSpriteData, grooveName)
		textImgDraw(pCfg.groovemenu.name.TextSpriteData)
	else
		local txt = textImgNew()
		textImgSetLocalcoord(txt, m.info.localcoord[1], m.info.localcoord[2])
		textImgSetFont(txt, motif.Fnt[m.groove_select['p' .. side].groove.text.font[1]] or motif.Fnt[1])
		textImgSetBank(txt, m.groove_select['p' .. side].groove.text.font[2])
		textImgSetAlign(txt, m.groove_select['p' .. side].groove.text.font[3])
		textImgSetText(txt, grooveName)
		textImgSetPos(txt, m.groove_select['p' .. side].groove.text.offset[1], m.groove_select['p' .. side].groove.text.offset[2])
		if item.color[1] > -1 or item.color[2] > -1 or item.color[3] > -1 or item.color[4] > -1 then
			textImgSetColor(txt, item.color[1] > -1 and item.color[1] or m.groove_select['p' .. side].groove.text.font[4], item.color[2] > -1 and item.color[2] or m.groove_select['p' .. side].groove.text.font[5], item.color[3] > -1 and item.color[3] or m.groove_select['p' .. side].groove.text.font[6], item.color[4] > -1 and item.color[4] or 255)
		else
			textImgSetColor(txt, m.groove_select['p' .. side].groove.text.font[4], m.groove_select['p' .. side].groove.text.font[5], m.groove_select['p' .. side].groove.text.font[6])
		end
		textImgSetScale(txt, m.groove_select['p' .. side].groove.text.scale[1], m.groove_select['p' .. side].groove.text.scale[1])
		textImgSetProjection(txt, m.groove_select['p' .. side].groove.text.projection)
		textImgSetLayerno(txt, 2)
		textImgDraw(txt)
	end
end

local function f_grooveMenu(side, cmd, player, member)
	local ms = grooveSelect.menu[side]
	local m = grooveSelect.motif
	local total = #ms.list
	local pSide = 'p' .. side

	local keyNext = motif.select_info[pSide].palmenu.next.key
	local keyPrev = motif.select_info[pSide].palmenu.previous.key
	local keyDone = motif.select_info[pSide].palmenu.done.key
	local keyCancel = motif.select_info[pSide].palmenu.cancel.key

	if getInput(cmd, keyNext) then
		ms.cursorIdx = (ms.cursorIdx % total) + 1
		sndPlay(motif.Snd, m.groove_select.cursor.move[1], m.groove_select.cursor.move[2])

	elseif getInput(cmd, keyPrev) then
		ms.cursorIdx = ((ms.cursorIdx - 2 + total) % total) + 1
		sndPlay(motif.Snd, m.groove_select.cursor.move[1], m.groove_select.cursor.move[2])

	elseif getInput(cmd, keyDone) then
		local chosen = ms.list[ms.cursorIdx]
		grooveSelect.t_selected[side][member] = {
			name = chosen.name,
			map_name = chosen.map_name,
			map_value = chosen.map_value,
		}
		sndPlay(motif.Snd, m.groove_select.cursor.done[1], m.groove_select.cursor.done[2])
		ms.active = false
		return 3

	elseif getInput(cmd, keyCancel) then
		sndPlay(motif.Snd, m.groove_select.cursor.cancel[1], m.groove_select.cursor.cancel[2])
		grooveSelect.t_selected[side][member] = nil
		ms.active = false

		local st = start.p[side].t_selTemp[member]
		if st then
			local pn = 2 * (member - 1) + side
			st.face_data = start.f_animGet(
				start.c[player].selRef, side, member,
				motif.select_info['p' .. pn].face, nil, true, st.face_data)
			st.face2_data = start.f_animGet(
				start.c[player].selRef, side, member,
				motif.select_info['p' .. pn].face2, nil, true, st.face2_data)
			st.currentIdx = nil
			st.validPals = nil
		end
		return 0
	end

	f_draw(side, member, ms.list[ms.cursorIdx])
	return GROOVE_STATE
end

local function f_freezePalette(side, player, member)
	local st = start.p[side].t_selTemp[member]
	if not st then return end
	if st.currentIdx and st.validPals then
		local maxIdx = #st.validPals + 1
		if st.currentIdx == maxIdx then
			local frozenPal = start.c[player].randPalPreview or start.f_randomPal(start.c[player].selRef, st.validPals)
			st.pal = frozenPal
			st.currentIdx = 1
			for i, p in ipairs(st.validPals) do
				if p == frozenPal then st.currentIdx = i; break end
			end
		end
	end
	start.c[player].randPalCnt     = nil
	start.c[player].randPalPreview = nil
	start.p[side].inPalMenu = false
end

local _origSelectMenu = start.f_selectMenu

start.f_selectMenu = function(side, cmd, player, member, selectState)
	if gameMode() ~= 'coloredit' then
		if selectState == GROOVE_STATE then
			local ms = grooveSelect.menu[side]
			if not ms or not ms.active then
				return _origSelectMenu(side, cmd, player, member, 3)
			end
			local nextState = f_grooveMenu(side, cmd, player, member)
			return nextState, false
		end
	end

	local newState, needUpdate = _origSelectMenu(side, cmd, player, member, selectState)

	if gameMode() ~= 'coloredit' then
		if newState == 3 and selectState ~= 3 then
			local selRef = start.c[player].selRef
			if selRef == nil then
				return newState, needUpdate
			end
	
			local charData = start.f_getCharData(selRef)
			if charData and charData.def then
				f_loadCharGrooves(selRef, charData.def)
			end
	
			local list = f_getGrooveList(selRef)
			if not list or #list == 0 then
				return newState, needUpdate
			end

			f_freezePalette(side, player, member)
	
			local ms = grooveSelect.menu[side]
			ms.active = true
			ms.member = member
			ms.player = player
			ms.charRef = selRef
			ms.list = list
			ms.cursorIdx = 1

			return GROOVE_STATE, needUpdate
		end
	end

	return newState, needUpdate
end

hook.add("start.f_selectReset.side", "groove_select_reset", function(side, hardReset)
	f_initMenuState(side)
end)

function grooveSelect.getSelected(side, member)
	return grooveSelect.t_selected[side] and grooveSelect.t_selected[side][member] or nil
end

local function f_init()
	f_loadGlobalGrooves()
	f_initMenuState(1)
	f_initMenuState(2)
end

f_init()

hook.add("loop", "groove_map_set", function()
	if gameMode() == "demo" then return end
	if roundState() ~= 0 then return end
	for side = 1, 2 do
		for member, v in pairs(start.p[side].t_selected) do
			if teamMode() == "turns" then
				player(side)
				if start.f_getCharData(v.ref).name == displayName() and start.f_getCharData(v.ref).author == authorName() then
					pn = side
				else
					pn = 69420 -- for the memes
				end
			else
				pn = 2 * (member - 1) + side
			end

			slot = teamMode() == "turns" and memberNo() or member
			if start.t_orderRemap and start.t_orderRemap[side] and start.t_orderRemap[side][slot] then
				slot = start.t_orderRemap[side][slot]
			end
			local selected = grooveSelect.t_selected and grooveSelect.t_selected[side] and grooveSelect.t_selected[side][slot]

			if player(pn) and selected and map(string.lower(selected.map_name or "")) ~= tonumber(selected.map_value or "0") then
				mapSet(string.lower(grooveSelect.t_selected[side][slot].map_name),  tonumber(grooveSelect.t_selected[side][slot].map_value or "0"))
				printConsole(memberNo() .. " - " .. grooveSelect.t_selected[side][slot].map_name .. " = " .. tonumber(grooveSelect.t_selected[side][slot].map_value or "0"), false)
			end
		end
	end
end)
