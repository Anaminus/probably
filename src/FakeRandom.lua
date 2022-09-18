local FakeRandom = {__index={}}

function FakeRandom.__index:NextInteger(min: number, max: number): number
	if self.max then
		return max
	else
		return min
	end
end

function FakeRandom.__index:NextNumber(min: number, max: number): number
	min = min or 0
	max = max or 1
	if self.max then
		return max
	else
		return min
	end
end

function FakeRandom.__index:NextUnitVector(): Vector3
	return self.source:NextUnitVector()
end

local function newMin()
	return setmetatable({
		source = Random.new(),
		max = false,
	}, FakeRandom)
end

local function newMax()
	return setmetatable({
		source = Random.new(),
		max = true,
	}, FakeRandom)
end

function FakeRandom.__index:Clone(): Random
	if self.max then
		return newMax()
	else
		return newMin()
	end
end

return {
	min = newMin,
	max = newMax,
}
