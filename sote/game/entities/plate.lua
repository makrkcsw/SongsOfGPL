---@class Plate
---@field new fun(self:Plate):Plate
---@field tiles table<Tile, Tile> Table containing tile references
---@field plate_id number ID of this plate
---@field r number
---@field g number
---@field b number
---@field add_tile fun(self:Plate, tile:Tile)
---@field speed number
---@field direction number
---@field done_expanding boolean
---@field current_tiles table
---@field next_tiles table

local plate = {}

plate.Plate = {}
plate.Plate.__index = plate.Plate
---Creates a new plate. Requires "WORLD" to exist
---@return Plate
function plate.Plate:new()
	local ne = {}

	ne.r = love.math.random()
	ne.g = love.math.random()
	ne.b = love.math.random()
	ne.plate_id = WORLD.entity_counter
	WORLD.entity_counter = WORLD.entity_counter + 1
	WORLD.plates[ne.plate_id] = ne

	ne.tiles = {}

	ne.done_expanding = false
	ne.speed = 0
	ne.direction = 1
	ne.current_tiles = {}
	ne.next_tiles = {}

	setmetatable(ne, plate.Plate)

	return ne
end

---Adds a tile to the plate, removing it from the previous plate...
---@param tile Tile ID of the tile to add!
function plate.Plate:add_tile(tile)
	-- First, remove the tile from the previous plate...

	-- ID of the plate that the tile is currently assigned to
	local old_plate = tile.plate
	if old_plate ~= nil then
		-- remove the tile from the plate...
		old_plate.tiles[tile] = nil
	else
		-- the plate doesn't exist, proceed
	end

	-- Set the reference on the tile...
	tile.plate = self

	-- Set the reference on yourself
	self.tiles[tile] = tile
end

return plate
