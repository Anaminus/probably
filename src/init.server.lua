local Fusion = require(script.lib.Fusion)
local New = Fusion.New
local Hydrate = Fusion.Hydrate
local Children = Fusion.Children
local Value = Fusion.Value
local OnEvent = Fusion.OnEvent
local Out = Fusion.Out
local Ref = Fusion.Ref
local Computed = Fusion.Computed
local OnChange = Fusion.OnChange
local Observer = Fusion.Observer
local Tween = Fusion.Tween

local PluginWidgets = script.lib.widgets.PluginComponents
local Toolbar = require(PluginWidgets.Toolbar)
local ToolbarButton = require(PluginWidgets.ToolbarButton)
local Widget = require(PluginWidgets.Widget)

local StudioWidgets = script.lib.widgets.StudioComponents
local Util = script.lib.widgets.StudioComponents.Util
local Background = require(StudioWidgets.Background)
local BaseButton = require(StudioWidgets.BaseButton)
local BoxBorder = require(StudioWidgets.BoxBorder)
local Button = require(StudioWidgets.Button)
local Checkbox = require(StudioWidgets.Checkbox)
local ClassIcon = require(StudioWidgets.ClassIcon)
local ColorPicker = require(StudioWidgets.ColorPicker)
local IconButton = require(StudioWidgets.IconButton)
local Label = require(StudioWidgets.Label)
local LimitedTextInput = require(StudioWidgets.LimitedTextInput)
local Loading = require(StudioWidgets.Loading)
local MainButton = require(StudioWidgets.MainButton)
local ProgressBar = require(StudioWidgets.ProgressBar)
local ScrollFrame = require(StudioWidgets.ScrollFrame)
local Shadow = require(StudioWidgets.Shadow)
local Slider = require(StudioWidgets.Slider)
local TextInput = require(StudioWidgets.TextInput)
local Title = require(StudioWidgets.Title)
local VerticalCollapsibleSection = require(StudioWidgets.VerticalCollapsibleSection)
local VerticalExpandingList = require(StudioWidgets.VerticalExpandingList)

local themeProvider = require(Util.themeProvider)

local Lattice = require(script.lib.Lattice)

local maid = {}
local function finish()
	for _, task in maid do
		if type(task) == "function" then
			task()
		elseif typeof(task) == "RBXScriptConnection" then
			task:Disconnect()
		end
	end
	table.clear(maid)
end
maid.unloading = plugin.Unloading:Connect(finish)

local function Panel(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	return New "Frame" (props)
end
-- Panel = function(props)
-- 	props.BorderSizePixel = 1
-- 	props.Text = props.Name
-- 	return New "TextLabel" (props)
-- end

local function Field(props)
	return New "Frame" {
		Name = props.Name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1,0,0,25),
		[Children] = {
			Label {
				Text = props.Name,
				Enabled = props.Enabled,
				Position = UDim2.new(0,0,0,0),
				Size = UDim2.new(0.5,0,1,0),
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			Hydrate(props.Value) {
				Position = UDim2.new(0.5,0,0,0),
				Size = UDim2.new(0.5,0,1,0),
			},
		},
	}
end

local function NumberInput(value)
	local lastGood = ""
	local input; input = TextInput{
		Text = value,
		[OnChange "Text"] = function(text)
			local t = tonumber(text)
			if t == nil then
				input.Text = lastGood
				return
			end
			lastGood = t
		end,
		[OnEvent "FocusLost"] = function(enter)
			local t = tonumber(input.Text)
			if t then
				value:set(t)
				return
			end
			input.Text = value:get()
		end,
	}
	return input
end

local viewOpen = Value(false)
local graphFrame = Value()
local settings = {
	resolution = Value(100),
	budget = Value(10000),
	updates = Value(60),
}
local minX = Value(0)
local maxX = Value(1)
local maxY = Value(1)

local running = Value(false)
local data = {}
local dataFrames = {}

local Computation: ((Random)->number)? = nil
local computationSource = Value("")
local errorMessage = Value("")
local errorTextColor = themeProvider:GetColor(Enum.StudioStyleGuideColor.ErrorText)

local fastMinX = math.huge
local fastMaxX = -math.huge
local fastMaxY = 0
local fastTotal = 0

local function updateDisplay()
	local res = settings.resolution:get()
	minX:set(fastMinX)
	maxX:set(fastMaxX)
	for i, frame in dataFrames do
		local v = data[i]
		frame.Size = UDim2.new(1/res,0,v/fastMaxY,0)
	end
	if fastTotal == 0 then
		maxY:set("0.00%")
	else
		maxY:set(string.format("%.2f%%", fastMaxY/fastTotal*100))
	end
end

local function resetData()
	for i in data do
		data[i] = 0
	end
	fastMaxY = 0
	fastTotal = 0
end

local random = Random.new()
local function computeData()
	if Computation then
		local ok, v = pcall(Computation, random)
		if not ok or type(v) ~= "number" or v ~= v then
			return
		end
		local reset = false
		if v < fastMinX then
			fastMinX = v
			reset = true
		end
		if v > fastMaxX then
			fastMaxX = v
			reset = true
		end
		if reset then
			resetData()
		end
		local res = settings.resolution:get()
		if res > 0 and fastMinX < fastMaxX then
			local i = math.floor((v-fastMinX)/(fastMaxX-fastMinX)*(res-1))+1
			if data[i] == nil then
				error(string.format("%g %d %g %g", v, i, fastMinX, fastMaxX))
			end
			local n = data[i] + 1
			data[i] = n
			fastTotal += 1
			if n > fastMaxY then
				fastMaxY = n
			end
		end
	end
end

maid.source = Observer(computationSource):onChange(function()
	local source = computationSource:get()
	local func, err = loadstring(source, "computation")
	if not func then
		errorMessage:set(tostring(err))
		return
	end
	local ok, comp = pcall(func)
	if not ok then
		errorMessage:set(tostring(comp))
		return
	end
	ok, err = pcall(comp, random)
	if not ok then
		errorMessage:set(err)
		return
	end
	resetData()
	fastMinX = math.huge
	fastMaxX = -math.huge
	Computation = comp
	errorMessage:set("")
end)

local dataFrameColor = themeProvider:GetColor(Enum.StudioStyleGuideColor.LinkText)
local function onResChanged()
	local res = settings.resolution:get()
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
			frame.Parent = graphFrame:get()
			dataFrames[i] = frame
		end
	end
	for i, frame in dataFrames do
		frame.Position = UDim2.new((i-1)/res,0,0,0)
	end
	resetData()
	updateDisplay()
end
maid.resChanged = Observer(settings.resolution):onChange(onResChanged)

local rid = 0
maid.runner = Observer(running):onChange(function()
	if running:get() then
		local id = rid+1
		rid = id
		local budgetTick = os.clock()
		local updateTick = budgetTick
		while running:get() and id == rid do
			computeData()
			local budget = settings.budget:get()/1000000
			if budget > 1 then
				budget = 1
			end
			if os.clock() - budgetTick > budget then
				task.wait()
				budgetTick = os.clock()
			end
			local updates = 1/settings.updates:get()
			if os.clock() - updateTick > updates then
				updateDisplay()
				updateTick = os.clock()
			end
		end
	end
end)

local toolbar = Toolbar{Name = "Probably"}
local toggleView = ToolbarButton{
	Toolbar = toolbar,
	Name = "ToggleGraphView",
	ToolTip = "Toggle the graph view.",
	Image = "",
	Active = viewOpen,
	[OnEvent "Click"] = function()
		viewOpen:set(not viewOpen:get())
	end,
}

local dock = Widget{
	Id = "GraphView",
	Name = "Probably",
	InitialDockTo = "Float",
	InitialEnabled = false,
	ForceInitialEnabled = false,
	FloatingSize = Vector2.new(1000, 600),
	MinimumSize = Vector2.new(800, 300),
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = viewOpen,
	[Out "Enabled"] = viewOpen,
	[Children] = {
		Lattice.new{
			Columns = "40px 3fr 2fr",
			Rows = "40px 1fr 91px 40px",
			Margin = 4,
			Padding = 4,
			Frame = Background{
				[Children] = {
					Lattice.cell(0,0, 3,1, Lattice.new{
						Columns = "40px 40px 1fr",
						Rows = "1fr",
						Padding = 4,
						Frame = Panel{
							Name = "TopPanel",
							[Children] = {
								Lattice.pos(0,0, IconButton{
									Name = "Run",
									Enabled = true,
									Icon = Computed(function()
										if running:get() then
											return "rbxasset://probably/pause.png"
										else
											return "rbxasset://probably/play.png"
										end
									end),
									[OnEvent "Activated"] = function()
										running:set(not running:get())
									end,
								}),
								Lattice.pos(1,0, IconButton{
									Name = "Reset",
									Enabled = true,
									Icon = "rbxasset://probably/reset.png",
									[OnEvent "Activated"] = function()
										resetData()
										updateDisplay()
									end,
								}),
							},
						},
					}),
					Lattice.cell(0,1, 1,2, Panel{
						Name = "YAxis",
						[Children] = {
							Label {
								Name = "Min",
								Text = "0.00%",
								Position = UDim2.new(0,0,1,0),
								Size = UDim2.new(1,0,0,1),
								TextYAlignment = Enum.TextYAlignment.Top,
							},
							Label {
								Name = "Max",
								Text = maxY,
								Position = UDim2.new(0,0,0,0),
								Size = UDim2.new(1,0,0,1),
								TextYAlignment = Enum.TextYAlignment.Top,
							},
						},
					}),
					Lattice.cell(1,3, 1,1, Panel{
						Name = "XAxis",
						[Children] = {
							Label {
								Name = "Min",
								Text = Computed(function()
									return string.format("%.3g", minX:get())
								end),
								Position = UDim2.new(0,0,0,0),
								Size = UDim2.new(0,1,1,0),
								TextXAlignment = Enum.TextXAlignment.Right,
							},
							Label {
								Name = "Max",
								Text = Computed(function()
									return string.format("%.3g", maxX:get())
								end),
								Position = UDim2.new(1,0,0,0),
								Size = UDim2.new(0,1,1,0),
								TextXAlignment = Enum.TextXAlignment.Right,
							},
						},
					}),
					Lattice.cell(1,1, 1,2, BoxBorder{
						[Children] = Background {
							Name = "Graph",
							[Ref] = graphFrame,
							[Children] = {
								New "UIListLayout" {
									FillDirection = Enum.FillDirection.Horizontal,
									VerticalAlignment = Enum.VerticalAlignment.Bottom,
								},
							},
						},
					}),
					Lattice.cell(2,1, 1,1, TextInput{
						Name = "Source",
						MultiLine = true,
						Font = Enum.Font.Code,
						TextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextWrapped = false,
						Text = computationSource,
						[Out "Text"] = computationSource,
					}),
					Lattice.cell(2,2, 1,1, BoxBorder{
						[Children] = Background {
							[Children] = {
								New "UIPadding" {
									PaddingTop = UDim.new(0,4),
									PaddingLeft = UDim.new(0,4),
									PaddingBottom = UDim.new(0,4),
									PaddingRight = UDim.new(0,4),
								},
								New "UIListLayout" {
									FillDirection = Enum.FillDirection.Vertical,
									HorizontalAlignment = Enum.HorizontalAlignment.Left,
									SortOrder = Enum.SortOrder.LayoutOrder,
									Padding = UDim.new(0, 4),
								},
								Field{
									Name = "Resolution",
									Value = NumberInput(settings.resolution),
									LayoutOrder = 1,
								},
								Field{
									Name = "Budget (μs)",
									Value = NumberInput(settings.budget),
									LayoutOrder = 2,
								},
								Field{
									Name = "Updates/s",
									Value = NumberInput(settings.updates),
									LayoutOrder = 3,
								},
							},
						},
					}),
					Lattice.cell(2,3, 1,1, Label{
						Name = "Error",
						Text = errorMessage,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = errorTextColor,
					}),
				},
			},
		},
	},
}

onResChanged()
computationSource:set([[
return function(r: Random)
    local a = r:NextNumber(1,6)
    local b = r:NextNumber(1,6)
    return a+b
end]])

task.wait(0.5)
viewOpen:set(true)
