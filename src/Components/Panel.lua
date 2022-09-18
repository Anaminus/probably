local root = script.Parent.Parent

local Fusion = require(root.lib.Fusion)
local New = Fusion.New

local function Panel(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	return New "Frame" (props)
end
-- Panel = function(props)
-- 	props.BorderSizePixel = 1
-- 	props.Text = props.Name
-- 	return New "TextLabel" (props)
-- end

return Panel
