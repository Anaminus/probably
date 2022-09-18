local root = script.Parent

local Fusion = require(root.lib.Fusion)
local Value = Fusion.Value
local Observer = Fusion.Observer

-- Returns a function that calls *func* after *window* seconds. This window
-- resets while the function is called during the window.
local function Accumulate(window, func)
	if window <= 0 then
		return func
	end
	local active
	return function(...)
		if active then
			task.cancel(active)
		end
		active = task.delay(window, function(...)
			active = nil
			func(...)
		end, ...)
	end
end

local SETTINGS = "ProbablySettings"

local function Settings(plugin, maid, defaults)
	local loaded = plugin:GetSetting(SETTINGS) or {}
	local settings = {}
	local cleanup = {}
	for name, default in defaults do
		local l = loaded[name]
		local v
		if l ~= nil then
			v = Value(l)
		else
			v = Value(default)
		end
		cleanup[name] = Observer(v):onChange(Accumulate(1, function()
			local saved = {}
			for k,v in settings do
				saved[k] = v:get()
			end
			plugin:SetSetting(SETTINGS, saved)
		end))
		settings[name] = v
	end
	table.insert(maid, cleanup)
	return settings
end

return Settings
