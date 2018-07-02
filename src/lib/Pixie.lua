--------------------------------------------------------------------------------
-- Pixie
-- Copyright (c) greenya. All rights reserved
--------------------------------------------------------------------------------

local Pixie = {
	window = nil,
	color = { a=1.0, r=1.0, g=1.0, b=1.0 },
	line = true,
	width = 1,
	x = 0,
	y = 0
}

function Pixie.setup (data)
	if data.window ~= nil then Pixie.window = data.window end
	if data.color ~= nil then Pixie.color = data.color end
	if data.line ~= nil then Pixie.line = data.line end
	if data.width ~= nil then Pixie.width = data.width end
end

function Pixie.move (x, y)
	Pixie.x = x
	Pixie.y = y
end

function Pixie.draw (x, y, x_to, y_to)
	--assert(Pixie.window ~= nil)

	local o = { Pixie.x, Pixie.y, x, y }
	if x_to ~= nil and y_to ~= nil then
		o = { x, y, x_to, y_to }
	end

	local p = Pixie.window:AddPixie({
		cr = Pixie.color,
		bLine = Pixie.line,
		fWidth = Pixie.width,
		loc = { fPoints = { 0, 0, 0, 0 }, nOffsets = o }
	})

	Pixie.move(x, y)

	return p
end

function Pixie.text (x, y, w, h, text, font, flags)
	--assert(Pixie.window ~= nil)

	local p = Pixie.window:AddPixie({
		cr = Pixie.color,
		strText = text,
		strFont = font,
		flagsText = flags,
		loc = { nOffsets = { x, y, x + w, y + h } }
	})

	return p
end

Apollo.GetAddon('LagMeter').lib.Pixie = Pixie
