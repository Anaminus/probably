export type Tasks = {[string|number]: ()->() | RBXScriptConnection | Tasks}

local function cleanup(maid: Tasks)
	for _, task in maid do
		if type(task) == "function" then
			task()
		elseif type(task) == "table" then
			cleanup(task)
		elseif typeof(task) == "RBXScriptConnection" then
			task:Disconnect()
		end
	end
	table.clear(maid)
end

return cleanup
