local root = script.Parent.Parent

local Fusion = require(root.lib.Fusion)
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange

local StudioWidgets = root.lib.PluginEssentials.StudioComponents
local TextInput = require(StudioWidgets.TextInput)

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

return NumberInput
