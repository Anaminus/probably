local root = script.Parent.Parent

local Fusion = require(root.lib.Fusion)
local New = Fusion.New
local Hydrate = Fusion.Hydrate
local Children = Fusion.Children

local StudioWidgets = root.lib.PluginEssentials.StudioComponents
local Label = require(StudioWidgets.Label)

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

return Field
