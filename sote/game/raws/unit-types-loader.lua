local d = {}

function d.load()
	local UnitType = require "game.raws.unit-types"
	local tec = require "game.raws.raws-utils".technology

	UnitType:new {
		name = 'light-infantry',
		description = 'light infantry',
		icon = 'round-shield.png',
		r = 0.32,
		g = 0.42,
		b = 0.92,
		base_price = 15,
		upkeep = 0.35,
		supply_useds = 1,
		trade_good_requirements = {},
		base_health = 40,
		base_attack = 5,
		base_armor = 1,
		speed = 1,
		foraging = 0.1,
		bonuses = {},
		supply_capacity = 3,
		unlocked_by = tec('paleolithic-knowledge')
	}
	UnitType:new {
		name = 'spearmen',
		description = 'spearmen',
		icon = 'stone-spear.png',
		r = 0.42,
		g = 0.42,
		b = 0.42,
		base_price = 12.5,
		upkeep = 0.25,
		supply_useds = 1,
		trade_good_requirements = {},
		base_health = 40,
		base_attack = 5,
		base_armor = 1,
		speed = 1,
		foraging = 0.1,
		bonuses = {},
		supply_capacity = 2.5,
		unlocked_by = tec('paleolithic-knowledge')
	}
	UnitType:new {
		name = 'archers',
		description = 'archers',
		icon = 'bow-arrow.png',
		r = 0.32,
		g = 0.92,
		b = 0.52,
		base_price = 25,
		upkeep = 0.5,
		supply_useds = 1,
		trade_good_requirements = {},
		base_health = 30,
		base_attack = 7.5,
		base_armor = 0,
		speed = 1,
		foraging = 0.3,
		bonuses = {},
		supply_capacity = 2.5,
		unlocked_by = tec('paleolithic-knowledge')
	}

end

return d
