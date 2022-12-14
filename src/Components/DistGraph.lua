local root = script.Parent.Parent

local Fusion = require(root.lib.Fusion)
local New = Fusion.New
local Children = Fusion.Children
local Observer = Fusion.Observer
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local Out = Fusion.Out

local StudioWidgets = root.lib.PluginEssentials.StudioComponents
local Util = root.lib.PluginEssentials.StudioComponents.Util
local Background = require(StudioWidgets.Background)
local BoxBorder = require(StudioWidgets.BoxBorder)
local Label = require(StudioWidgets.Label)

local themeProvider = require(Util.themeProvider)
local constants = require(Util.constants)

local cleanup = require(root.cleanup)

local TextService = game:GetService("TextService")

export type DistGraphOptions = {
	Resolution: Fusion.StateObject<number>,
	Lower: Fusion.StateObject<number>,
	Upper: Fusion.StateObject<number>,
	Peak: Fusion.StateObject<number>,
}

local function DistGraph(opt: DistGraphOptions)
	local maid: cleanup.Tasks = {}

	local fastLower = math.huge
	local fastUpper = -math.huge
	local fastPeak = 0
	local fastTotal = 0
	local highlightedIndex: number? = nil
	local dataCount = {}
	local dataLower = {}
	local dataUpper = {}
	local dataFrames = {}

	local graphFrame: GuiObject

	local resolution = opt.Resolution
	local lower = opt.Lower
	local upper = opt.Upper
	local peak = opt.Peak

	local self = {}

	function self:Destroy()
		cleanup(maid)
	end

	local dataColor = themeProvider:GetColor(
		Enum.StudioStyleGuideColor.DialogMainButton,
		Enum.StudioStyleGuideModifier.Default
	)
	local dataHoverColor = themeProvider:GetColor(
		Enum.StudioStyleGuideColor.DialogMainButton,
		Enum.StudioStyleGuideModifier.Hover
	)

	local function updateResolution()
		local res = resolution:get()
		if res == #dataFrames then
			return
		end
		dataCount = table.create(res, 0)
		dataLower = table.create(res, math.huge)
		dataUpper = table.create(res, -math.huge)
		if res < #dataFrames then
			for i = res+1, #dataFrames do
				dataFrames[i]:Destroy()
				dataFrames[i] = nil
			end
		elseif res > #dataFrames then
			local color = dataColor:get()
			for i = #dataFrames+1, res do
				local frame = New "Frame" {
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 1),
					BackgroundColor3 = color,
				}
				frame.Parent = graphFrame
				dataFrames[i] = frame
			end
		end
		for i, frame in dataFrames do
			frame.Position = UDim2.fromScale((i-1)/res, 1)
		end
		self:Reset()
		self:Render()
	end

	local dataLabelBounds = Value(Vector2.new())
	local dataLabel = Label {
		Visible = false,
		ZIndex = 2,
		BorderSizePixel = 0,
		BackgroundTransparency = 0,
		BackgroundColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		[Out "TextBounds"] = dataLabelBounds,
		Size = Computed(function()
			local bounds = dataLabelBounds:get()
			if not bounds then
				return UDim2.new()
			end
			return UDim2.fromOffset(bounds.X, bounds.Y)
		end),
	}

	function self:UpdateLabel()
		if highlightedIndex then
			local count = dataCount[highlightedIndex]
			if count then
				local lower = dataLower[highlightedIndex]
				local upper = dataUpper[highlightedIndex]
				local prob = count/fastTotal*100
				if lower == math.huge or upper == -math.huge then
					dataLabel.Text = string.format("%.2f%%", prob)
				elseif lower == upper then
					dataLabel.Text = string.format("%.2f%%\n%g", prob, lower)
				else
					dataLabel.Text = string.format("%.2f%%\n%g to %g", prob, lower, upper)
				end
			end
		end
	end

	function self:Render()
		local res = resolution:get()
		lower:set(fastLower)
		upper:set(fastUpper)
		for i, frame in dataFrames do
			local v = dataCount[i]
			frame.Size = UDim2.new(1/res,0,v/fastPeak,0)
		end
		if fastTotal == 0 then
			peak:set(0)
		else
			peak:set(fastPeak/fastTotal)
		end
		self:UpdateLabel()
	end

	function self:RenderHover(position: Vector2?)
		highlightedIndex = nil
		dataLabel.Visible = false
		local color = dataColor:get()
		for i, frame in dataFrames do
			frame.BackgroundColor3 = color
		end
		if position == nil or #dataFrames == 0 or fastTotal == 0 then
			return
		end
		local graphPos = graphFrame.AbsolutePosition
		local graphSize = graphFrame.AbsoluteSize
		local scalar = ((position-graphPos)/graphSize).X
		if scalar < 0 or scalar >= 1 then
			return
		end
		highlightedIndex = math.floor(#dataFrames*scalar)+1
		local frame = dataFrames[highlightedIndex]
		local gp = graphFrame.AbsolutePosition
		local gs = graphFrame.AbsoluteSize
		local bp = frame.AbsolutePosition - gp
		local bs = frame.AbsoluteSize
		local ls = dataLabel.AbsoluteSize
		local pos = Vector2.new(math.clamp(bp.X + bs.X/2 - ls.X/2, 0, gs.X - ls.X), 0)

		dataLabel.Visible = true
		dataLabel.Position = UDim2.fromOffset(pos.X, pos.Y)
		frame.BackgroundColor3 = dataHoverColor:get()
		self:UpdateLabel()
	end

	function self:Reset()
		for i in dataCount do
			dataCount[i] = 0
		end
		fastPeak = 0
		fastTotal = 0
	end

	function self:ResetBounds()
		fastLower = math.huge
		fastUpper = -math.huge
		for i in dataCount do
			dataLower[i] = math.huge
			dataUpper[i] = -math.huge
		end
	end

	function self:UpdateBounds(value: number)
		local reset = false
		if value < fastLower then
			fastLower = value
			reset = true
		end
		if value > fastUpper then
			fastUpper = value
			reset = true
		end
		if reset then
			self:Reset()
		end
	end

	function self:BucketIndex(value: number)
		local res = resolution:get()
		local i = math.floor((value-fastLower)*(res-1)/(fastUpper-fastLower))+1
		if dataCount[i] == nil then
			error(string.format("%g %d %g %g", value, i, fastLower, fastUpper))
		end
		return i
	end

	function self:AddSample(value: number)
		self:UpdateBounds(value)
		if resolution:get() > 0 and fastLower < fastUpper then
			local i = self:BucketIndex(value)
			local n = dataCount[i] + 1
			dataCount[i] = n
			fastTotal += 1
			if n > fastPeak then
				fastPeak = n
			end
			if value < dataLower[i] then
				dataLower[i] = value
			end
			if value > dataUpper[i] then
				dataUpper[i] = value
			end
		end
	end

	graphFrame = BoxBorder{
		[Children] = Background {
			Name = "Graph",
			[Children] = dataLabel,
			[OnEvent "InputBegan"] = function(input: InputObject)
				if input.UserInputType ~= Enum.UserInputType.MouseMovement then
					return
				end
				maid.inputChanged = input:GetPropertyChangedSignal("Position"):Connect(function()
					if input.UserInputType ~= Enum.UserInputType.MouseMovement then
						return
					end
					self:RenderHover(Vector2.new(input.Position.X, input.Position.Y))
				end)
				self:RenderHover(Vector2.new(input.Position.X, input.Position.Y))
			end,
			[OnEvent "InputEnded"] = function(input: InputObject)
				if input.UserInputType ~= Enum.UserInputType.MouseMovement then
					return
				end
				if typeof(maid.inputChanged) == "RBXScriptConnection" then
					maid.inputChanged:Disconnect()
					maid.inputChanged = nil
				end
				if typeof(maid.inputEnded) == "RBXScriptConnection" then
					maid.inputEnded:Disconnect()
					maid.inputEnded = nil
				end
				self:RenderHover(nil)
			end,
		},
	}
	self.Frame = graphFrame

	maid.resChanged = Observer(resolution):onChange(updateResolution)
	updateResolution()

	return self
end

return DistGraph
