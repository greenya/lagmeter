--------------------------------------------------------------------------------
-- Points
-- Copyright (c) greenya. All rights reserved
--------------------------------------------------------------------------------

local Points = {}

function Points:new (size, val)
	--assert(type(size) == 'number')
	--assert(size > 0)

	local o = {}
	setmetatable(o, self)
	self.__index = self

	o.min = 0
	o.max = 0
	o.data = {}
	for i = 1, size do
		o.data[#o.data + 1] = val
	end

	return o
end

function Points:push (value)
	self.min = value
	self.max = value

	for i = 2, #self.data do
		local v = self.data[i]
		self.data[i - 1] = v

		if v < self.min then self.min = v end
		if v > self.max then self.max = v end
	end

	self.data[#self.data] = value
end

function Points:dump ()
	local s = ''
	for i = 1, #self.data do
		if (s:len() > 0) then s = s .. ', ' end
		s = s .. self.data[i]
	end
	Print(s)
end

Apollo.GetAddon('LagMeter').lib.Points = Points
