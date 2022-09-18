local root = script

local Fusion = require(root.lib.Fusion)
local New = Fusion.New
local Children = Fusion.Children
local Value = Fusion.Value
local OnEvent = Fusion.OnEvent
local Out = Fusion.Out
local Computed = Fusion.Computed
local Observer = Fusion.Observer

local PluginWidgets = root.lib.widgets.PluginComponents
local Toolbar = require(PluginWidgets.Toolbar)
local ToolbarButton = require(PluginWidgets.ToolbarButton)
local Widget = require(PluginWidgets.Widget)

local StudioWidgets = root.lib.widgets.StudioComponents
local Util = root.lib.widgets.StudioComponents.Util
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

local Components = root.Components
local Panel = require(Components.Panel)
local Field = require(Components.Field)
local NumberInput = require(Components.NumberInput)
local DistGraph = require(Components.DistGraph)

local themeProvider = require(Util.themeProvider)

local Lattice = require(root.lib.Lattice)

local maid = {}
local cleanup = require(root.cleanup)
maid.unloading = plugin.Unloading:Connect(function()
	cleanup(maid)
end)

local settings = {
	resolution = Value(100),
	budget = Value(10000),
	updates = Value(60),
}

local lower = Value(math.huge)
local upper = Value(-math.huge)
local peak = Value(0)
local graph = DistGraph({
	Resolution = settings.resolution,
	Lower = lower,
	Upper = upper,
	Peak = peak,
})

local random = Random.new()
local distFunc: ((Random)->number)? = nil

local source = Value("")
local errorMessage = Value("")
maid.source = Observer(source):onChange(function()
	local source = source:get()
	local func, err = loadstring(source, "dist")
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
	graph:Reset()
	graph:ResetBounds()
	distFunc = comp
	errorMessage:set("")
end)

local function sample()
	if distFunc then
		local ok, v = pcall(distFunc, random)
		if not ok or type(v) ~= "number" or v ~= v then
			return
		end
		graph:AddSample(v)
	end
end

local running = Value(false)
local rid = 0
maid.runner = Observer(running):onChange(function()
	if running:get() then
		local id = rid+1
		rid = id
		local budgetTick = os.clock()
		local updateTick = budgetTick
		while running:get() and id == rid do
			sample()
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
				graph:Render()
				updateTick = os.clock()
			end
		end
	end
end)

local viewOpen = Value(false)
local toolbar = Toolbar{Name = "Probably"}
ToolbarButton{
	Toolbar = toolbar,
	Name = "Graph",
	ToolTip = "Toggle the graph view.",
	Image = "rbxasset://probably/logo.png",
	Active = viewOpen,
	[OnEvent "Click"] = function()
		viewOpen:set(not viewOpen:get())
	end,
}
Widget{
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
										graph:Reset()
										graph:Render()
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
								Text = Computed(function()
									return string.format("%.2f%%", peak:get()*100)
								end),
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
									return string.format("%.3g", lower:get())
								end),
								Position = UDim2.new(0,0,0,0),
								Size = UDim2.new(0,1,1,0),
								TextXAlignment = Enum.TextXAlignment.Right,
							},
							Label {
								Name = "Max",
								Text = Computed(function()
									return string.format("%.3g", upper:get())
								end),
								Position = UDim2.new(1,0,0,0),
								Size = UDim2.new(0,1,1,0),
								TextXAlignment = Enum.TextXAlignment.Right,
							},
						},
					}),
					Lattice.cell(1,1, 1,2, graph.Frame),
					Lattice.cell(2,1, 1,1, TextInput{
						Name = "Source",
						MultiLine = true,
						Font = Enum.Font.Code,
						TextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextWrapped = false,
						Text = source,
						[Out "Text"] = source,
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
						TextColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.ErrorText),
					}),
				},
			},
		},
	},
}

source:set([[
return function(r: Random)
    local a = r:NextNumber(1,6)
    local b = r:NextNumber(1,6)
    return a+b
end]])
