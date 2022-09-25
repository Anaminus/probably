local root = script

local Asset = require(root.Asset)
local Settings = require(root.Settings)

local Fusion = require(root.lib.Fusion)
local New = Fusion.New
local Children = Fusion.Children
local Value = Fusion.Value
local OnEvent = Fusion.OnEvent
local Out = Fusion.Out
local Computed = Fusion.Computed
local Observer = Fusion.Observer

local PluginWidgets = root.lib.PluginEssentials.PluginComponents
local Toolbar = require(PluginWidgets.Toolbar)
local ToolbarButton = require(PluginWidgets.ToolbarButton)
local Widget = require(PluginWidgets.Widget)

local StudioWidgets = root.lib.PluginEssentials.StudioComponents
local Util = root.lib.PluginEssentials.StudioComponents.Util
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

local constants = require(Util.constants)
local themeProvider = require(Util.themeProvider)

local Lattice = require(root.lib.Lattice)
local fr = "fr"
local px = "px"

local FakeRandom = require(root.FakeRandom)

local maid = {}
local cleanup = require(root.cleanup)
maid.unloading = plugin.Unloading:Connect(function()
	cleanup(maid)
end)

local settings = Settings(plugin, maid, {
	resolution = 11,
	budget     = 10000,
	updates    = 60,
	source     = [[
return function(r: Random)
	-- Roll two dice (2d6)
    local a = r:NextInteger(1,6)
    local b = r:NextInteger(1,6)
    return a+b
end]]
})

local lower = Value(math.huge)
local upper = Value(-math.huge)
local peak = Value(0)
local graph = DistGraph({
	Resolution = settings.resolution,
	Lower = lower,
	Upper = upper,
	Peak = peak,
})

local randomMin = FakeRandom.min()
local randomMax = FakeRandom.max()
local random = Random.new()
local distFunc: ((Random)->number)? = nil

local function sample(random, bounds)
	if distFunc then
		local ok, v = pcall(distFunc, random)
		if not ok or
			type(v) ~= "number" or
			v ~= v or
			v == math.huge or
			v == -math.huge then
			return
		end
		if bounds then
			graph:UpdateBounds(v)
		else
			graph:AddSample(v)
		end
	end
end

local errorMessage = Value("")
local function updateSource()
	local source = settings.source:get()
	local ok, func, err = pcall(loadstring, source, "dist")
	if not ok then
		errorMessage:set(func)
		return
	end
	if not func then
		errorMessage:set(tostring(err))
		return
	end
	local comp
	ok, comp = pcall(func)
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
	-- Attempt to find lower and upper bounds early.
	sample(randomMin, true)
	sample(randomMax, true)
end
maid.source = Observer(settings.source):onChange(updateSource)
updateSource()

local running = Value(false)
local rid = 0
maid.runner = Observer(running):onChange(function()
	if running:get() then
		local id = rid+1
		rid = id
		local budgetTick = os.clock()
		local updateTick = budgetTick
		while running:get() and id == rid do
			sample(random)
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

local textSize = constants.TextSize
local textSizeCode = 16
local textSizeLarge = textSize*3

local viewOpen = Value(false)
local aboutOpen = Value(false)
maid.pauseOnClose = Observer(viewOpen):onChange(function()
	if not viewOpen:get() then
		running:set(false)
		aboutOpen:set(false)
	end
end)
local toolbar = Toolbar{Name = "Probably"}
ToolbarButton{
	Toolbar = toolbar,
	Name = "Graph",
	ToolTip = "Toggle the graph view.",
	Image = Asset.Logo,
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
				Visible = Computed(function() return not aboutOpen:get() end),
				[Children] = {
					Lattice.cell(0,0, 3,1, Lattice.new{
						Columns = "40px 40px 1fr 40px",
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
											return Asset.Pause
										else
											return Asset.Play
										end
									end),
									[OnEvent "Activated"] = function()
										running:set(not running:get())
									end,
								}),
								Lattice.pos(1,0, IconButton{
									Name = "Reset",
									Enabled = true,
									Icon = Asset.Reset,
									[OnEvent "Activated"] = function()
										graph:Reset()
										graph:Render()
									end,
								}),
								Lattice.pos(3,0, IconButton{
									Name = "About",
									Enabled = true,
									Icon = Asset.About,
									[OnEvent "Activated"] = function()
										aboutOpen:set(true)
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
									return tostring(lower:get())
								end),
								Position = UDim2.new(0,0,0,0),
								Size = UDim2.new(0,1,1,0),
								TextXAlignment = Enum.TextXAlignment.Right,
							},
							Label {
								Name = "Max",
								Text = Computed(function()
									return tostring(upper:get())
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
						TextSize = textSizeCode,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextWrapped = false,
						Text = settings.source,
						[Out "Text"] = settings.source,
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
		Lattice.new{
			Columns = Lattice.span(1,fr, 40,px, 1,fr, 40,px, 1,fr, 40,px),
			Rows = Lattice.span(40,px, textSize*7,px, textSize,px, 1,fr),
			Margin = 4,
			Padding = 4,
			Frame = Background{
				Visible = aboutOpen,
				[Children] = {
					Lattice.cell(0,0, 5,1, Panel{
						Name = "Title",
						[Children] = {
							New "UIListLayout" {
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							},
							New "ImageLabel" {
								Size = UDim2.fromOffset(32, 32),
								BackgroundTransparency = 1,
								Image = Asset.Logo,
							},
							Title{
								Text = "Probably",
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Center,
								TextSize = textSizeLarge,
								AutomaticSize = Enum.AutomaticSize.XY,
								Size = UDim2.fromScale(0, 0),
							},
							Label{
								Text = "v" .. (script:GetAttribute("Version") or "DEV"),
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Bottom,
								TextSize = textSize,
								AutomaticSize = Enum.AutomaticSize.XY,
								Size = UDim2.fromScale(0, 1),
							},
						},
					}),
					Lattice.cell(5,0, 1,1, IconButton{
						Name = "Back",
						Enabled = true,
						Icon = Asset.Back,
						[OnEvent "Activated"] = function()
							aboutOpen:set(false)
						end,
					}),
					Lattice.cell(0,1, 6,1, Label{
						Name = "Description",
						Text = [[
A plugin for displaying the probability distributions of Luau functions.

<b>Authors:</b> Anaminus

<i>The source code and assets for Probably, except for the logo, are licensed under MIT.</i>]],
						RichText = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextSize = textSize,
						TextWrapped = true,
					}),
					Lattice.cell(0,2, 6,1, Label{
						Name = "LibDesc",
						Text = "Probably was made with the following libraries:",
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextSize = textSize,
						TextWrapped = true,
					}),
					Lattice.cell(0,3, 2,1, Panel{
						Name = "Libraries",
						[Children] = {
							New "UIListLayout" {
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
							},
							Title {Text = "Library"},
							Label {Text = "Fusion"},
							Label {Text = "PluginEssentials"},
							Label {Text = "UILattice"},
						},
					}),
					Lattice.cell(2,3, 2,1, Panel{
						Name = "Authors",
						[Children] = {
							New "UIListLayout" {
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
							},
							Title {Text = "Author"},
							Label {Text = "Elttob"},
							Label {Text = "Yasu Yoshida (mvyasu)"},
							Label {Text = "Anaminus"},
						},
					}),
					Lattice.cell(4,3, 2,1, Panel{
						Name = "Licenses",
						[Children] = {
							New "UIListLayout" {
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
							},
							Title {Text = "License"},
							Label {Text = "MIT"},
							Label {Text = "MIT"},
							Label {Text = "MIT-0"},
						},
					}),
				},
			},
		},
	},
}
