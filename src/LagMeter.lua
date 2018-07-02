--------------------------------------------------------------------------------
-- LagMeter
-- Copyright (c) greenya. All rights reserved
--------------------------------------------------------------------------------

local Addon = {}

function Addon:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	self.lib = {}

	self.conf = {
		version 	= 1,
		wndpos 		= { 100, 100, 300, 160 }, -- default/initial window location (values in xml ignored)
		interval	= 200, -- update interval in milliseconds
		size		= 100, -- history size, amount of time points
		bad			= 200 -- maximum latency value considered as 'bad'
	}

	return o
end

function Addon:OnSave (level)
	if level == GameLib.CodeEnumAddonSaveLevel.Character then
		return self.conf
	end
end

function Addon:OnRestore (level, data)
	if level == GameLib.CodeEnumAddonSaveLevel.Character
	and data ~= nil
	and data.version == self.conf.version then
		self.conf = data
	end
end

function Addon:OnLoad ()
	self.xmlDoc = XmlDoc.CreateFromFile('LagMeter.xml')
	self.xmlDoc:RegisterCallback('OnDocLoaded', self)
end

function Addon:OnDocLoaded ()
	self.wndSettings = Apollo.LoadForm(self.xmlDoc, 'SettingsForm', nil, self)

	local p = self.conf.wndpos
	self.wndMain = Apollo.LoadForm(self.xmlDoc, 'MainForm', nil, self)
	self.wndMain:Move(p[1], p[2], p[3] - p[1], p[4] - p[2])

	self.xmlDoc = nil

	self:init_data()
	self:init_graph()
	self:init_timer()
end

function Addon:OnConfigure ()
	local c = self.conf
	local w = self.wndSettings

	w:FindChild('IntervalSlider'):SetValue(c.interval)
	w:FindChild('SizeSlider'):SetValue(c.size)
	w:FindChild('BadSlider'):SetValue(c.bad)
	self:OnSettingsChanged(nil)

	w:Invoke(true)
end

function Addon:OnSettingsCancel ()
	self.wndSettings:Close()
end

-- todo: figure out how to GetTickAmount() from slider and get rid of street magic like '50' and '5'
function Addon:OnSettingsChanged (target)
	local c = self.conf
	local w = self.wndSettings

	c.interval = w:FindChild('IntervalSlider'):GetValue()
	c.interval = math.floor(c.interval / 50) * 50
	w:FindChild('IntervalValue'):SetText(c.interval .. ' ms')

	c.size = w:FindChild('SizeSlider'):GetValue()
	c.size = math.floor(c.size / 5) * 5
	w:FindChild('SizeValue'):SetText(c.size .. ' points')

	c.bad = w:FindChild('BadSlider'):GetValue()
	c.bad = math.floor(c.bad / 5) * 5
	w:FindChild('BadValue'):SetText(c.bad .. ' ms')

	-- re-init only necessary parts

	local n = target ~= nil and target:GetName() or ''

	if n == 'IntervalSlider' then
		self:init_timer()
	elseif n == 'SizeSlider' then
		self:init_data()
		self:init_graph()
	elseif n == 'BadSlider' then
		self:update_graph()
	end
end

function Addon:OnTimer ()
	local l = GameLib.GetLatency()
	self.data.points:push(l)
	self:update_graph()
end

function Addon:OnWindowMove (wndHandler, wndControl, nOldLeft, nOldTop, nOldRight, nOldBottom)
	self.conf.wndpos = { self.wndMain:GetLocation():GetOffsets() }
end

function Addon:init_timer ()
	if self.timer ~= nil then
		self.timer:Stop()
	end

	self.timer = ApolloTimer.Create(self.conf.interval / 1000, true, 'OnTimer', self)
end

function Addon:init_data ()
	local c = self.conf

	self.data = {
		points = self.lib.Points:new(c.size, GameLib.GetLatency()),
		graph = {
			width = c.wndpos[3] - c.wndpos[1],
			height = c.wndpos[4] - c.wndpos[2],
			pixies = {},
			aux = {},
			font = {
				name = 'CRB_Interface9', -- todo: move to config when i'll figure out how to measure text for arbitrary font face
				txtw = 50, -- todo: calc w and h on the fly with something like font.measure_text('999 ms')
				txth = 20 -- but for now i leave this street magic here
			}
		}
	}
end

function Addon:init_graph ()
	local p = self.lib.Pixie
	local s = self.conf.size
	local g = self.data.graph
	local xd = g.width / s
	local iy = g.height + 10 -- place initial points outside of the graph

	self.wndMain:DestroyAllPixies()

	p.setup({ window = self.wndMain, width = 3, color = { a=1.0, r=1.0, g=1.0, b=1.0 } })
	p.move(0, iy)

	for i = 1, s do
		g.pixies[#g.pixies + 1] = p.draw(i * xd, iy)
	end

	g.aux.txt = p.text(0, 0, 0, 0, '', g.font.name, {})
	g.aux.txt_avg = p.text(0, 0, 0, 0, '', g.font.name, {})
end

function Addon:update_graph ()
	local s = self.conf.size
	local b = self.conf.bad
	local g = self.data.graph
	local p = self.data.points

	--assert(s == #g.pixies)
	--assert(s == #p.data)

	-- update graph points

	local xd = g.width / s
	local yd = g.height / (b * 1.05)
	local yp = -1
	local al = 0
	local bl = b * 0.75

	for i = 1, s do
		local l = p.data[i]
		al = al + l

		if l > b then l = b end

		local q = self:color(l, b, bl)
		local yc = l * yd

		if yp < 0 then yp = yc end

		self.wndMain:UpdatePixie(g.pixies[i], {
			cr = { a=1, r=1-q, g=q, b=0 },
			loc = { nOffsets = { (i - 1) * xd - 1, g.height - yp, i * xd, g.height - yc } },
			bLine = true
		})

		yp = yc
	end

	-- update average value text

	al = al / s

	local ay = al * yd
	local aly = g.height - ay

	if aly < g.font.txth then aly = g.font.txth end
	self.wndMain:UpdatePixie(g.aux.txt_avg, {
		loc = { nOffsets = { 5, aly - g.font.txth, g.font.txtw, aly } },
		strText = math.floor(al + 0.5) .. ' ms'
	})

	-- update current value text

	local cly = g.height - yp
	if cly < g.font.txth then cly = g.font.txth end
	self.wndMain:UpdatePixie(g.aux.txt, {
		loc = { nOffsets = { g.width - g.font.txtw - 5, cly - g.font.txth, g.width - 5, cly } },
		strText = p.data[s] .. ' ms',
		flagsText = { DT_RIGHT = true }
	})
end

function Addon:color (value, top, low)
	--assert(value >= 0)
	--assert(top > low)
	if value < low then
		return 1
	end

	if value > top then
		return 0
	end

	local t = top - low
	local v = value - low
	return (t - v) / t
end

local addon = Addon:new()
Apollo.RegisterAddon(addon, true, 'LagMeter')
Apollo.RegisterSlashCommand('lagmeter', 'OnConfigure', addon)
