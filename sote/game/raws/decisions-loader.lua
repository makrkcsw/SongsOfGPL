local path = require "game.ai.pathfinding"
local tabb = require "engine.table"
local ll = {}

function ll.load()
	local Decision = require "game.raws.decisions"

	require "game.raws.decisions.war-decisions" ()

	-- Logic flow:
	-- 1. Loop through all realms
	-- 2. Loop through all decisions
	-- 3. Check base probability (AI only) << base_probability >>
	-- 4. Check pretrigger << pretrigger >>
	-- 5. Select target (AI only) << ai_target >>
	-- 6. Check clickability << clickable >>
	-- 6a. If clickability failed, go back to 5, up to << ai_targetting_attempts >> times (AI only)
	-- 7. Select secondary target (AI only) << ai_secondary_target >>
	-- 8. Check is the decision is available (can be used on that specific target) << available >>
	-- 9. Check action probability (AI only) << ai_will_do >>
	-- 10. Apply decisions << effect >>

	--[[
	Decision:new {
		name = 'cheat-for-money',
		ui_name = 'Money Cheat',
		tooltip = "Because developers don't wanna wait for monthly income when testing buildings",
		sorting = 0,
		base_probability = 0,
		effect = function(realm, primary_target, secondary_target)
			realm.treasury = realm.treasury + 1000
		end,
	}
	Decision:new {
		name = 'never-possible',
		ui_name = 'this should never be visible',
		sorting = 0,
		secondary_target = 'tile',
		base_probability = 0,
		effect = function(realm, primary_target, secondary_target)
			print("This should never happen!")
		end,
		pretrigger = function()
			return false
		end
	}
	Decision:new {
		name = 'target-debug',
		ui_name = 'debugging (province selection)',
		tooltip = "This decision does nothing. It exists only to debug secondary target selection",
		sorting = 0,
		primary_target = 'province',
		secondary_target = 'province',
		base_probability = 0, -- AI will never do this, it's just for debugging the system
		effect = function(realm, primary_target, secondary_target)
			print("Stuff is happening!")
			WORLD:emit_event(WORLD.events_by_name['default'], realm, nil)
		end,
		clickable = function(realm, primary_target)
			return primary_target.realm == realm
		end,
		get_secondary_targets = function(realm, primary_target)
			local r = {}
			for _, province in pairs(realm.provinces) do
				r[#r + 1] = province
			end
			return r
		end,
	}
	--]]
	local gift_cost_per_pop = require "game.gifting".gift_cost_per_pop
	Decision:new {
		name = 'give-gifts',
		ui_name = "Hand out gifts",
		tooltip = "Hand out gifts to the local population, effectively bribing them for support.",
		sorting = 1,
		primary_target = "province",
		secondary_target = 'none',
		base_probability = 1 / 25,
		pretrigger = function(root)
			---@type Realm
			local root = root
			return root.treasury > 10
		end,
		clickable = function(root, primary_target)
			---@type Realm
			local root = root
			---@type Province
			local primary_target = primary_target
			return root == primary_target.realm
		end,
		available = function(root, primary_target)
			---@type Realm
			local root = root
			---@type Province
			local primary_target = primary_target
			local pop = primary_target:population()
			return root.treasury > pop * gift_cost_per_pop
		end,
		ai_will_do = function(root, primary_target, secondary_target)
			-- AI will only do it if mood in the province is negative
			if primary_target.mood < 0 then
				return 1
			else
				return 0
			end
		end,
		ai_targetting_attempts = 1,
		ai_target = function(root)
			---@type Realm
			local root = root
			local n = tabb.size(root.provinces)
			local r = tabb.nth(root.provinces, love.math.random(n))
			if r then
				return r, true
			else
				return nil, false
			end
		end,
		ai_secondary_target = function(root, primary_target)
			return nil, true
		end,
		effect = function(root, primary_target, secondary_target)
			---@type Realm
			local root = root
			---@type Province
			local primary_target = primary_target
			primary_target.mood = math.min(10, primary_target.mood + 1)
			root.treasury = math.max(0, root.treasury - primary_target:population() * gift_cost_per_pop)
			if root == WORLD.player_realm then
				WORLD:emit_notification("Population of " .. primary_target.name .. " is jubilant after receiving our gifts!")
			end
		end
	}
	Decision:new {
		name = 'explore-province',
		ui_name = "Explore province",
		tooltip = "Explore province",
		sorting = 1,
		primary_target = 'province',
		secondary_target = 'none',
		base_probability = 1 / 12,
		-- The first check -- used to cull potential decision takers
		pretrigger = function(root)
			return true
		end,
		-- Controls if the action is clickable by the player
		clickable = function(root, primary_target)
			---@type Realm
			local root = root
			---@type Province
			local primary_target = primary_target
			local explore_cost = root:get_explore_cost(primary_target)
			return explore_cost < root.treasury
		end,
		-- Controls if the action can be clicked by the player
		available = function(root, primary_target, secondary_target)
			return true
		end,
		-- Returns probability that the AI will take the action (after all other checks)
		ai_will_do = function(root, primary_target, secondary_target)
			return 1
		end,
		-- Number of attempts an AI will take to select the target
		ai_targetting_attempts = 1,
		-- Returns a potential target (the target may be invalid)
		ai_target = function(root)
			---@type Realm
			local root = root
			local n = tabb.size(root.known_provinces)
			local r = tabb.nth(root.known_provinces, love.math.random(n))
			if r then
				return r, true
			else
				return nil, false
			end
		end,
		-- Returns a secondary target (the target may be invalid)
		ai_secondary_target = function(root, primary_target)
			return nil, true
		end,
		-- If all checks are met, this function is applied
		-- Put any effects of the decision here
		-- Use events and notifications when applicable!
		effect = function(root, primary_target, secondary_target)
			---@type Realm
			local root = root
			root:explore(primary_target)
			--print("Exploration from decision! Tresury: ", root.treasury)
		end
	}
	Decision:new {
		name = 'offend-locals',
		ui_name = "Offend locals",
		tooltip = "(DEBUG EVENT) Sometimes, offending the people you rule over is just the thing you want to do!.",
		sorting = 1,
		primary_target = 'province',
		secondary_target = 'none',
		base_probability = 0 / 12,
		-- The first check -- used to cull potential decision takers
		pretrigger = function(root)
			return true
		end,
		-- Controls if the action is clickable by the player
		clickable = function(root, primary_target)
			---@type Realm
			local root = root
			---@type Province
			local primary_target = primary_target
			return root == primary_target.realm
		end,
		-- Controls if the action can be clicked by the player
		available = function(root, primary_target, secondary_target)
			return true
		end,
		-- Returns probability that the AI will take the action (after all other checks)
		ai_will_do = function(root, primary_target, secondary_target)
			return 0
		end,
		-- Number of attempts an AI will take to select the target
		ai_targetting_attempts = 1,
		-- Returns a potential target (the target may be invalid)
		ai_target = function(root)
			---@type Realm
			local root = root
			local n = tabb.size(root.provinces)
			local r = tabb.nth(root.provinces, love.math.random(n))
			if r then
				return r, true
			else
				return nil, false
			end
		end,
		-- Returns a secondary target (the target may be invalid)
		ai_secondary_target = function(root, primary_target)
			return nil, true
		end,
		-- If all checks are met, this function is applied
		-- Put any effects of the decision here
		-- Use events and notifications when applicable!
		effect = function(root, primary_target, secondary_target)
			---@type Realm
			local root = root
			---@type Province
			local primary_target = primary_target
			primary_target.mood = primary_target.mood - 1
			if root == WORLD.player_realm then
				WORLD:emit_notification("People were greatly upset!")
			end
		end
	}

	-- War related events
	Decision:new {
		name = 'covert-raid',
		ui_name = "Covert raid",
		tooltip = "Loots the province covertly with small forces. Can avoid diplomatic issues. Loots only from the local provincial wealth pool.",
		sorting = 1,
		primary_target = "province",
		secondary_target = 'none',
		base_probability = 1 / 25,
		pretrigger = function(root)
			--print("pre")
			---@type Realm
			local root = root
			return root:get_realm_ready_military() > 0
		end,
		clickable = function(root, primary_target)
			--print("cli")
			---@type Realm
			local root = root
			---@type Province
			local primary_target = primary_target
			if primary_target.realm == root then
				return false
			end
			return primary_target:neighbors_realm(root)
		end,
		available = function(root, primary_target)
			--print("avl")
			---@type Realm
			local root = root
			---@type Province
			local primary_target = primary_target
			return true
		end,
		ai_will_do = function(root, primary_target, secondary_target)
			--print("aiw")
			return 1
		end,
		ai_targetting_attempts = 2,
		ai_target = function(root)
			--print("ait")
			---@type Realm
			local root = root
			local n = tabb.size(root.provinces)
			---@type Province
			local p = tabb.nth(root.provinces, love.math.random(n))
			if p then
				-- Once you target a province, try selecting a random neighbor
				local s = tabb.size(p.neighbors)
				---@type Province
				local ne = tabb.nth(p.neighbors, love.math.random(s))
				if ne then
					if ne.realm then
						return ne, true
					end
				end
			end
			return nil, false
		end,
		ai_secondary_target = function(root, primary_target)
			--print("ais")
			return nil, true
		end,
		effect = function(root, primary_target, secondary_target)
			--print("eff")
			---@type Realm
			local root = root
			---@type Province
			local primary_target = primary_target
			local travel_time, _ = path.hours_to_travel_days(path.pathfind(root.capitol, primary_target))

			if root == WORLD.player_realm then
				WORLD:emit_notification("We sent out our warriors to " ..
					primary_target.name ..
					", they should arrive in " ..
					travel_time .. " days. We can expect to hear back from them in " .. (travel_time * 2) .. " days.")
			end

			-- A raid will raise up to a certain number of troops
			local max_covert_raid_size = 10
			local army = root:raise_army_of_size(max_covert_raid_size)
			army.destination = primary_target

			WORLD:emit_action(
				WORLD.events_by_name["covert-raid"],
				primary_target.realm,
				{ target = primary_target, raider = root, travel_time = travel_time, army = army },
				travel_time
			)
			--print("done")
		end
	}
end

return ll
