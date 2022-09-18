local root = script.Parent.Parent

local Fusion = require(root.lib.Fusion)
local New = Fusion.New
local Children = Fusion.Children
local Observer = Fusion.Observer

local StudioWidgets = root.lib.widgets.StudioComponents
local Util = root.lib.widgets.StudioComponents.Util
local Background = require(StudioWidgets.Background)
local BoxBorder = require(StudioWidgets.BoxBorder)

local themeProvider = require(Util.themeProvider)

local cleanup = require(root.cleanup)

export type DistGraphOptions = {
	Resolution: Fusion.StateObject<number>,
	Lower: Fusion.StateObject<number>,
	Upper: Fusion.StateObject<number>,
	Peak: Fusion.StateObject<number>,
}

local function DistGraph(opt: DistGraphOptions)
	local maid: cleanup.Tasks = {}

	local fastMinX = math.huge
	local fastMaxX = -math.huge
	local fastMaxY = 0
	local fastTotal = 0
	local data = {}
	local dataFrames = {}
	local graphFrame = BoxBorder{
		[Children] = Background {
			Name = "Graph",
			[Children] = {
				New "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
				},
			},
		},
	}

	local resolution = opt.Resolution
	local lower = opt.Lower
	local upper = opt.Upper
	local peak = opt.Peak

	local self = {}

	self.Frame = graphFrame

	function self:Destroy()
		cleanup(maid)
	end

	local dataFrameColor = themeProvider:GetColor(Enum.StudioStyleGuideColor.LinkText)
	local function updateResolution()
		local res = resolution:get()
		if res == #dataFrames then
			return
		end
		data = table.create(res, 0)
		if res < #dataFrames then
			for i = res+1, #dataFrames do
				dataFrames[i]:Destroy()
				dataFrames[i] = nil
			end
		elseif res > #dataFrames then
			for i = #dataFrames+1, res do
				local frame = New "Frame" {
					BackgroundColor3 = dataFrameColor,
					BorderSizePixel = 0,
				}
				frame.Parent = graphFrame
				dataFrames[i] = frame
			end
		end
		for i, frame in dataFrames do
			frame.Position = UDim2.new((i-1)/res,0,0,0)
		end
		self:Reset()
		self:Render()
	end

	function self:Render()
		local res = resolution:get()
		lower:set(fastMinX)
		upper:set(fastMaxX)
		for i, frame in dataFrames do
			local v = data[i]
			frame.Size = UDim2.new(1/res,0,v/fastMaxY,0)
		end
		if fastTotal == 0 then
			peak:set(0)
		else
			peak:set(fastMaxY/fastTotal)
		end
	end

	function self:Reset()
		for i in data do
			data[i] = 0
		end
		fastMaxY = 0
		fastTotal = 0
	end

	function self:ResetBounds()
		fastMinX = math.huge
		fastMaxX = -math.huge
	end

	function self:AddSample(value: number)
		local reset = false
		if value < fastMinX then
			fastMinX = value
			reset = true
		end
		if value > fastMaxX then
			fastMaxX = value
			reset = true
		end
		if reset then
			self:Reset()
		end
		local res = resolution:get()
		if res > 0 and fastMinX < fastMaxX then
			local i = math.floor((value-fastMinX)/(fastMaxX-fastMinX)*(res-1))+1
			if data[i] == nil then
				error(string.format("%g %d %g %g", value, i, fastMinX, fastMaxX))
			end
			local n = data[i] + 1
			data[i] = n
			fastTotal += 1
			if n > fastMaxY then
				fastMaxY = n
			end
		end
	end

	maid.resChanged = Observer(resolution):onChange(updateResolution)
	updateResolution()

	return self
end

return DistGraph
