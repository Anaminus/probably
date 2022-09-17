local UILattice = require(script.UILattice)

local Plugin = script:FindFirstAncestorWhichIsA("Plugin")
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local Hydrate = Fusion.Hydrate

local StudioComponents = Plugin:FindFirstChild("StudioComponents", true)
local StudioComponentsUtil = StudioComponents.Util
local stripProps = require(StudioComponentsUtil.stripProps)

local COMPONENT_ONLY_PROPERTIES = {
	"Columns",
	"Rows",
	"Margin",
	"Padding",
	"Constraints",
	"Frame",
}

export type LatticeProperties = {
	Columns: string?,
	Rows: string?,
	Margin: number?,
	Padding: number?,
	Constraints: Rect?,
	Frame: GuiObject,
	[any]: any,
}

return {
	new = function(props: LatticeProperties): Frame
		UILattice.update(props.Frame, props)
		local hydrateProps = stripProps(props, COMPONENT_ONLY_PROPERTIES)
		return Hydrate(props.Frame)(hydrateProps)
	end,
	pos = function(x: number, y: number, frame: GuiObject)
		frame:SetAttribute("UILatticeBounds", Vector2.new(x, y))
		return frame
	end,
	rect = function(minx: number, miny: number, maxx: number, maxy: number, frame: GuiObject)
		frame:SetAttribute("UILatticeBounds", Rect.new(minx, miny, maxx, maxy))
		return frame
	end,
	cell = function(posx: number, posy: number, sizex: number, sizey: number, frame: GuiObject)
		frame:SetAttribute("UILatticeBounds", Rect.new(posx, posy, posx+sizex, posy+sizey))
		return frame
	end,
	px = function(n)
		return {n, "px"}
	end,
	fr = function(n)
		return {n, "fr"}
	end,
	span = function(...)
		local span: {string|number} = {}
		for i = 1, select("#", ...), 2 do
			if i > 1 then
				table.insert(span, " ")
			end
			local n, u = select(i, ...)
			assert(type(n) == "number", "number expected")
			assert(u=="px" or u=="fr", "'px' or 'fr' expected")
			table.insert(span, n)
			table.insert(span, u)
		end
		return table.concat(span)
	end,
}
