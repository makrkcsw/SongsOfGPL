local gam = {}

local cpml = require "cpml"
local world = require "game.entities.world"
local cube = require "game.cube"
local tile = require "game.entities.tile"

local plate_gen = require "game.world-gen.plate-gen"

---@type Technology|nil
gam.cached_selected_tech = nil

---Called when a tile is clicked.
function gam.on_tile_click()
	local tile_id = gam.clicked_tile_id
	local tile = WORLD.tiles[tile_id]

	--[[
	print('REAL_NUTRIENT_IN_TILE:', REAL_NUTRIENT_IN_TILE[tile])
	print('WATER_IN_TILE_VALUES:', WATER_IN_TILE_VALUES[tile])
	print('RAINFALL_IN_TILE:', RAINFALL_IN_TILE[tile])
	print('PERMEABILITY_OF_TILE:', PERMEABILITY_OF_TILE[tile])
	print('SUNLIGHT_VALUES:', SUNLIGHT_VALUES[tile])
	print('SHRUB_COUNT:', SHRUB_COUNT[tile])
	print('WATER_MULTIPLIER:', WATER_MULTIPLIER[tile])
	print('NUTRIENT_MULTIPLIER:', NUTRIENT_MULTIPLIER[tile])
	print('LIGHT_MULTIPLIER:', LIGHT_MULTIPLIER[tile])
	print('BROADLEAF_TEMP_MULTIPLIER:', BROADLEAF_TEMP_MULTIPLIER[tile])
	print('SHRUB_COUNT:', SHRUB_COUNT[tile])
	print('GRASS_COUNT:', GRASS_COUNT[tile])
	print('CONIFER_COUNT:', CONIFER_COUNT[tile])
	print('BROADLEAF_COUNT:', BROADLEAF_COUNT[tile])
	print('DEBUG_1:', DEBUG_1[tile])
	print('DEBUG_2:', DEBUG_2[tile])
	print('DEBUG_3:', DEBUG_3[tile])
	print('DEBUG_4:', DEBUG_4[tile])
	print('BASE_GROWTH', BASE_GROWTH[tile])
	print('WATER_MULTIPLIER', WATER_MULTIPLIER[tile])
	print('NUTRIENT_MULTIPLIER', NUTRIENT_MULTIPLIER[tile])
	print('LIGHT_MULTIPLIER', LIGHT_MULTIPLIER[tile])
	print('SOILDEPTH_MULTIPLIER', SOILDEPTH_MULTIPLIER[tile])
	print('TEMP_MULTIPLIER', TEMP_MULTIPLIER[tile])
	print('KILL', KILL[tile])
	--]]


	if tile ~= nil then
		local tab = require "engine.table"
		if tab.contains(ARGS, "--dev") then
			print("Tile", tile_id)
			tab.print(tile)
			print("Climate Cell")
			tab.print(tile.climate_cell)

			local la, lo = tile:latlon()
			print(la, lo)
			local utt = require "game.climate.utils"
			local x, y = utt.get_x_y(tile.climate_cell.cell_id)
			local cla, clo = utt.latitude(y), utt.longitude(x)
			print(cla, clo)

			if tile.biome ~= nil then
				print("Biome:", tile.biome.name)
			else
				print("Biome:", nil)
			end

			if tile.province then
				print("Foragers limit: ", tile.province.foragers_limit)
			end
		end

		if gam.map_mode == "selected_tile" or gam.map_mode == "diplomacy" then
			gam.refresh_map_mode()
		end
	end
end

---Called in dev mode. Draws debuggig UI.
function gam.debug_ui()
	local ui = require "engine.ui"
	if ui.text_button("Run code", ui.rect(10, 10, 50, 50)) then
		print("running code!")
		--Add your code here!
		plate_gen.run()
		-- Refresh the map mode after loading!
		gam.refresh_map_mode()
		print("code finished running!")
	end
	if ui.text_button("Plates", ui.rect(10, 10 + 60, 50, 50)) then
		gam.update_map_mode("plates")
	end
	if ui.text_button("Selected tile", ui.rect(10, 10 + 60 * 2, 50, 50)) then
		gam.update_map_mode("selected_tile")
	end
	if ui.text_button("Debug", ui.rect(10, 10 + 60 * 3, 50, 50)) then
		gam.update_map_mode("debug")
	end
	if ui.text_button("Take\nsnapshot", ui.rect(10 + 60, 10, 75, 50)) then
		world.save("cache.snapshot")
		gam.refresh_map_mode()
	end
	if ui.text_button("Load\nsnapshot", ui.rect(10 + 60 + 85, 10, 75, 50)) then
		world.load("cache.snapshot")
		gam.refresh_map_mode()
	end
end

---Initializes the planet mesh and does some other, similar setup
function gam.init()
	gam.show_map_mode_panel = false -- for rendering the panel
	gam.map_mode_slider = 0 -- for the map mode slider
	gam.game_canvas = love.graphics.newCanvas()
	gam.planet_mesh = require "game.scenes.game.planet".get_planet_mesh()
	gam.planet_shader = require "game.scenes.game.planet-shader".get_shader()
	gam.paused = true
	gam.speed = 1
	gam.tile_province_image_data = nil
	gam.tile_province_texture = nil
	gam.inspector = nil
	gam.load_camera_position_or_set_to_default()
	local default_map_mode = "elevation"
	gam.map_mode = default_map_mode
	if CACHED_MAP_MODE == nil then
		CACHED_MAP_MODE = gam.map_mode
	else
		gam.map_mode = CACHED_MAP_MODE
	end
	gam.camera_lock = false
	if CACHED_LOCK_STATE == nil then
		CACHED_LOCK_STATE = gam.camera_lock
	else
		gam.camera_lock = CACHED_LOCK_STATE
	end

	local ws = WORLD.world_size
	local dim = ws * 3
	local imd = love.image.newImageData(dim, dim, "rgba8")
	for x = 1, dim do
		for y = 1, dim do
			imd:setPixel(x - 1, y - 1, 0.1, 0.1, 0.1, 1)
		end
	end
	gam.tile_color_image_data = imd
	gam.tile_color_texture = love.graphics.newImage(imd)
	gam.refresh_map_mode()
	gam.click_tile(-1)

	gam.minimap = require "game.minimap".make_minimap()
end

---Call this to make sure that a camera position exists.
---Whenever possible, it'll load from a global instead.
function gam.load_camera_position_or_set_to_default()
	gam.camera_position = cpml.vec3.new(0, 0, -2.5)
	if CACHED_CAMERA_POSITION == nil then
		CACHED_CAMERA_POSITION = gam.camera_position
	else
		gam.camera_position = CACHED_CAMERA_POSITION
	end
end

gam.time_since_last_tick = 0
---@param dt number
function gam.update(dt)
	gam.speed = gam.speed or 1
	gam.time_since_last_tick = gam.time_since_last_tick + dt
	if gam.time_since_last_tick > 1 / 30 then
		gam.time_since_last_tick = 0
		if gam.paused ~= nil and not gam.paused and gam.selected_decision == nil and
			WORLD.pending_player_event_reaction == false then
			-- the game is unpaused, call tick on world!
			--print("-- tick start --")
			local start = love.timer.getTime()
			for _ = 1, 4 ^ gam.speed do
				WORLD:tick()
				if love.timer.getTime() - start > 1 / 15 then
					break
				end
			end
			--print("-- tick end --")
		else
			-- the game is paused, nothing to do!
		end
	end
end

local up_direction = cpml.vec3.new(0, 1, 0)
local origin_point = cpml.vec3.new(0, 0, 0)

function gam.handle_camera_controls()
	local ui = require "engine.ui"
	if not gam.camera_lock then
		if gam.camera_position == nil then
			print("!!! Weird error during hot loading... Camera position was set to nil")
			gam.load_camera_position_or_set_to_default()
		end
		-- Handle camera controls...
		local up = up_direction
		local camera_speed = (gam.camera_position:len() - 0.75) * 0.006
		local zoom_speed = 0.02
		if ui.is_key_held('lshift') then
			camera_speed = camera_speed * 3
			zoom_speed = zoom_speed * 3
		end
		local mouse_zoom_sensor_size = 3
		local mouse_x, mouse_y = ui.mouse_position()
		--print(ui.mouse_position())
		local screen_x, screen_y = ui.get_reference_screen_dimensions()
		if ui.is_key_held('a') or mouse_x < mouse_zoom_sensor_size then
			gam.camera_position = gam.camera_position:rotate(-camera_speed, up)
		end
		if ui.is_key_held('d') or mouse_x > screen_x - mouse_zoom_sensor_size then
			gam.camera_position = gam.camera_position:rotate(camera_speed, up)
		end
		if ui.is_key_held('w') or mouse_y < mouse_zoom_sensor_size then
			local rot = gam.camera_position:cross(up)
			gam.camera_position = gam.camera_position:rotate(-camera_speed, rot)
		end
		if ui.is_key_held('s') or mouse_y > screen_y - mouse_zoom_sensor_size then
			local rot = gam.camera_position:cross(up)
			gam.camera_position = gam.camera_position:rotate(camera_speed, rot)
		end
		if ui.is_key_held('e') or ui.mouse_wheel() < 0 then
			gam.camera_position = gam.camera_position * (1 + zoom_speed)
			local l = gam.camera_position:len()
			if l > 3 then
				gam.camera_position = gam.camera_position:normalize() * 3
			end
		end
		if ui.is_key_held('q') or ui.mouse_wheel() > 0 then
			gam.camera_position = gam.camera_position * (1 - zoom_speed)
			local l = gam.camera_position:len()
			if l < 1.015 then
				gam.camera_position = gam.camera_position:normalize() * 1.015
			end
		end
		CACHED_CAMERA_POSITION = gam.camera_position
	end
	if ui.is_key_pressed("f8") then
		print("!")
		gam.camera_lock = not gam.camera_lock
		CACHED_LOCK_STATE = gam.camera_lock
	end
end

---@param tile_id number
function gam.click_tile(tile_id)
	gam.clicked_tile_id = tile_id
	gam.clicked_tile = WORLD.tiles[tile_id]
	gam.reset_decision_selection()
	---@type Tile
	if require "engine.table".contains(ARGS, "--dev") then
		CLICKED_TILE_GLOBAL = WORLD.tiles[tile_id]
	end
end

function gam.reset_decision_selection()
	gam.decision_target_primary = nil
	gam.decision_target_secondary = nil
	gam.selected_decision = nil
end

---
function gam.draw()
	if WORLD == nil then
		return
	end
	local ui = require "engine.ui"

	if WORLD.pending_player_event_reaction then
		-- We need to draw the event and return!
		-- Doing it here will prevent rendering of the normal UI
		-- benri da yo ne
		require "game.scenes.game.event-screen".draw(gam)
		return
	end

	-- Reinitialize if needed, for example, after hot-loads
	if gam.planet_mesh == nil then
		gam.init()
	end

	gam.handle_camera_controls()

	local model = cpml.mat4.identity()
	local view = cpml.mat4.identity()
	view:look_at(gam.camera_position, origin_point, up_direction)
	local projection = cpml.mat4.from_perspective(45, love.graphics.getWidth() / love.graphics.getHeight(), 0.01, 10)

	-- Screen point to ray maths!
	-- First, get the mouse position in a [0, 1] space
	local mp_x, mp_y = ui.mouse_position()
	local sd_x, sd_y = ui.get_reference_screen_dimensions()
	local mpfx = mp_x / sd_x
	local mpfy = mp_y / sd_y
	local vp = projection * view
	local inv_vp = cpml.mat4.identity()
	inv_vp:invert(vp)
	local cp = inv_vp * cpml.vec3.new(
		2 * mpfx - 1,
		2 * mpfy - 1,
		0
	)
	--print("===")
	local coll_point, dist = cpml.intersect.ray_sphere({
		position = gam.camera_position,
		direction = (cp - gam.camera_position):normalize()
	}, {
		position = origin_point,
		radius = 1.0
	})
	local click_detected = false
	local new_clicked_tile = gam.clicked_tile_id
	if coll_point then
		if ui.is_mouse_released(1) then
			new_clicked_tile = tile.cart_to_index(coll_point.x, coll_point.y, coll_point.z)
			click_detected = true
		end
	else

	end

	love.graphics.setCanvas({ gam.game_canvas, depth = true })
	love.graphics.setShader(gam.planet_shader)
	gam.planet_shader:send('model', 'column', model)
	gam.planet_shader:send('view', 'column', view)
	gam.planet_shader:send('projection', 'column', projection)
	if gam.planet_shader:hasUniform("tile_colors") then
		gam.planet_shader:send('tile_colors', gam.tile_color_texture)
	end
	if gam.planet_shader:hasUniform("world_size") then
		gam.planet_shader:send('world_size', WORLD.world_size)
	end
	if gam.planet_shader:hasUniform("clicked_tile") then
		gam.planet_shader:send('clicked_tile', gam.clicked_tile_id - 1) -- shaders use 0-indexed arrays!
	end
	if gam.planet_shader:hasUniform("camera_distance_from_sphere") then
		gam.planet_shader:send("camera_distance_from_sphere", gam.camera_position:len() - 1)
	end
	if gam.planet_shader:hasUniform("time") then
		gam.planet_shader:send("time", love.timer.getTime())
	end
	if gam.planet_shader:hasUniform("tile_provinces") then
		if gam.tile_province_texture == nil then
			gam.recalculate_province_map()
		end
		gam.planet_shader:send('tile_provinces', gam.tile_province_texture)
	end
	love.graphics.setDepthMode("lequal", true)
	love.graphics.clear()
	love.graphics.draw(gam.planet_mesh)
	love.graphics.setShader()
	love.graphics.setCanvas()
	love.graphics.draw(gam.game_canvas)


	-- ##########
	-- ### UI ###
	-- ##########
	local ut = require "game.ui-utils"

	local fs = ui.fullscreen()

	if gam.camera_lock then
		ui.text_panel("Camera locked! Press F8 to unlock it!",
			fs:subrect(0, 75, 300, ut.BASE_HEIGHT, "center", "up")
		)
	end

	local bottom_right = fs:subrect(0, 0, 0, 0, "right", "down")
	local bottom_right_main_layout = ui.layout_builder()
		:vertical(true)
		:position(bottom_right.x, bottom_right.y)
		:flipped()
		:build()
	local _ = bottom_right_main_layout:next(ut.BASE_HEIGHT, ut.BASE_HEIGHT) -- skip!

	-- Bottom bar
	local bottom_bar = ui.layout_builder()
		:horizontal(true)
		:position(bottom_right.x, bottom_right.y)
		:flipped()
		:build()
	if ui.icon_button(
		ASSETS.icons["exit-door.png"],
		bottom_bar:next(ut.BASE_HEIGHT, ut.BASE_HEIGHT),
		"Quit"
	) then
		---@type World|nil
		WORLD = nil -- drop the world so that it gets garbage collected..
		local manager = require "game.scene-manager"
		manager.transition("main-menu")
		return
	end
	if ui.icon_button(
		ASSETS.icons["save.png"],
		bottom_bar:next(ut.BASE_HEIGHT, ut.BASE_HEIGHT),
		"Save"
	) then
		world.save("quicksave.binbeaver")
		gam.refresh_map_mode()
	end
	if ui.icon_button(
		ASSETS.icons["load.png"],
		bottom_bar:next(ut.BASE_HEIGHT, ut.BASE_HEIGHT),
		"Load"
	) then
		world.load("quicksave.binbeaver")
		gam.refresh_map_mode()
	end
	if ui.icon_button(
		ASSETS.icons["treasure-map.png"],
		bottom_bar:next(ut.BASE_HEIGHT, ut.BASE_HEIGHT),
		"Export map"
	) then
		local to_save = require "game.minimap".make_minimap_image_data(1600, 800)
		to_save:encode("png", gam.map_mode .. ".png")
	end
	if WORLD.player_realm then
		if ui.icon_button(ASSETS.icons["magnifying-glass.png"], bottom_bar:next(ut.BASE_HEIGHT, ut.BASE_HEIGHT),
			"Change country") then
			WORLD.player_realm = nil
			gam.refresh_map_mode()
		end
	end
	-- Minimap
	require "game.minimap".draw(
		gam.minimap,
		gam.camera_position,
		bottom_right_main_layout:next(300, 150)
	)
	-- Map mode tab
	local mouse_in_bottom_right = ui.trigger(ui.fullscreen():subrect(
		0, 0, 300, ut.BASE_HEIGHT * 2 + 150, "right", 'down'
	))
	local map_mode_bar = bottom_right_main_layout:next(300, ut.BASE_HEIGHT)
	local map_mode_bar_layout = ui.layout_builder()
		:horizontal()
		:position(map_mode_bar.x, map_mode_bar.y)
		:build()
	if ui.icon_button(
		ASSETS.icons["plain-arrow.png"],
		map_mode_bar_layout:next(ut.BASE_HEIGHT, ut.BASE_HEIGHT),
		"Show all map modes"
	) then
		gam.show_map_mode_panel = true
	end
	if ui.icon_button(
		ASSETS.icons[gam.map_mode_data['realms'][2]],
		map_mode_bar_layout:next(ut.BASE_HEIGHT, ut.BASE_HEIGHT), gam.map_mode_data['realms'][3]) then
		gam.update_map_mode("realms")
	end
	if ui.icon_button(
		ASSETS.icons[gam.map_mode_data['elevation'][2]],
		map_mode_bar_layout:next(ut.BASE_HEIGHT, ut.BASE_HEIGHT), gam.map_mode_data['elevation'][3]) then
		gam.update_map_mode("elevation")
	end
	if ui.icon_button(
		ASSETS.icons[gam.map_mode_data['biomes'][2]],
		map_mode_bar_layout:next(ut.BASE_HEIGHT, ut.BASE_HEIGHT), gam.map_mode_data['biomes'][3]) then
		gam.update_map_mode("biomes")
	end
	if ui.icon_button(
		ASSETS.icons[gam.map_mode_data['koppen'][2]],
		map_mode_bar_layout:next(ut.BASE_HEIGHT, ut.BASE_HEIGHT), gam.map_mode_data['koppen'][3]) then
		gam.update_map_mode("koppen")
	end
	-- Map modes tab
	if gam.show_map_mode_panel then
		local ttab = require "engine.table"
		local mm_panel_height = ut.BASE_HEIGHT * (1 + 10)
		local panel = bottom_right_main_layout:next(300, mm_panel_height)
		if ui.trigger(panel) then
			mouse_in_bottom_right = true
		end
		ui.panel(panel)

		-- bottom right for closing the panel
		if ui.icon_button(ASSETS.icons["cancel.png"], panel:subrect(
			0, 0, ut.BASE_HEIGHT, ut.BASE_HEIGHT, "right", "up"
		)) then
			gam.show_map_mode_panel = false
		end
		-- buttons for map mode tabs
		local top_panels = {
			panel:subrect(0 * ut.BASE_HEIGHT, 0, ut.BASE_HEIGHT, ut.BASE_HEIGHT, "left", "up"),
			panel:subrect(1 * ut.BASE_HEIGHT, 0, ut.BASE_HEIGHT, ut.BASE_HEIGHT, "left", "up"),
			panel:subrect(2 * ut.BASE_HEIGHT, 0, ut.BASE_HEIGHT, ut.BASE_HEIGHT, "left", "up"),
			panel:subrect(3 * ut.BASE_HEIGHT, 0, ut.BASE_HEIGHT, ut.BASE_HEIGHT, "left", "up"),
			panel:subrect(4 * ut.BASE_HEIGHT, 0, ut.BASE_HEIGHT, ut.BASE_HEIGHT, "left", "up"),
			panel:subrect(5 * ut.BASE_HEIGHT, 0, ut.BASE_HEIGHT, ut.BASE_HEIGHT, "left", "up"),
			panel:subrect(6 * ut.BASE_HEIGHT, 0, ut.BASE_HEIGHT, ut.BASE_HEIGHT, "left", "up"),
			panel:subrect(7 * ut.BASE_HEIGHT, 0, ut.BASE_HEIGHT, ut.BASE_HEIGHT, "left", "up"),
		}
		ui.tooltip("All", top_panels[1])
		if gam.map_mode_selected_tab == 'all' then
			ui.centered_text("ALL", top_panels[1])
		else
			if ui.text_button("ALL", top_panels[1]) then
				gam.map_mode_selected_tab = 'all'
			end
		end
		ui.tooltip("Political", top_panels[2])
		if gam.map_mode_selected_tab == 'political' then
			ui.centered_text("POL", top_panels[2])
		else
			if ui.text_button("POL", top_panels[2]) then
				gam.map_mode_selected_tab = 'political'
			end
		end
		ui.tooltip("Demographic", top_panels[3])
		if gam.map_mode_selected_tab == 'demographic' then
			ui.centered_text("DEM", top_panels[3])
		else
			if ui.text_button("DEM", top_panels[3]) then
				gam.map_mode_selected_tab = 'demographic'
			end
		end
		ui.tooltip("Economic", top_panels[4])
		if gam.map_mode_selected_tab == 'economic' then
			ui.centered_text("ECN", top_panels[4])
		else
			if ui.text_button("ECN", top_panels[4]) then
				gam.map_mode_selected_tab = 'economic'
			end
		end
		ui.tooltip("Debug", top_panels[7])
		if gam.map_mode_selected_tab == 'debug' then
			ui.centered_text("DEB", top_panels[7])
		else
			if ui.text_button("DEB", top_panels[7]) then
				gam.map_mode_selected_tab = 'debug'
			end
		end

		local scrollview_rect = panel:subrect(0, 0, 300, mm_panel_height - ut.BASE_HEIGHT, "right", 'down')
		local mms = gam.map_mode_tabs[gam.map_mode_selected_tab]
		gam.map_mode_slider = ui.scrollview(
			scrollview_rect,
			function(i, rect)
				local mm_key = mms[i]
				local mm_data = gam.map_mode_data[mm_key]
				if mm_data ~= nil then
					local button_rect = rect:copy()
					button_rect.width = button_rect.height
					if ui.icon_button(ASSETS.icons[
						mm_data[2]
						], button_rect,
						mm_data[3]
					) then
						gam.update_map_mode(mm_key)
					end
					rect.x = rect.x + rect.height
					rect.width = rect.width - rect.height
					ui.text_panel(mm_data[1], rect)
				else
				end
			end,
			ut.BASE_HEIGHT,
			ttab.size(mms),
			ut.BASE_HEIGHT,
			gam.map_mode_slider
		)
	end

	-- Draw the calendar
	mouse_in_bottom_right = ut.calendar(gam) or mouse_in_bottom_right
	-- Draw notifications
	if WORLD.notification_queue:length() > 0 then
		-- "Mask" the mouse interaction
		local notif_panel = fs:subrect(0, ut.BASE_HEIGHT, ut.BASE_HEIGHT * 11, ut.BASE_HEIGHT * 4, "right", 'up')
		if ui.trigger(notif_panel) then
			mouse_in_bottom_right = true
		end

		-- Draw gfx
		ui.panel(notif_panel)
		ui.left_text("Notifications (" .. tostring(WORLD.notification_queue:length()) .. ")",
			notif_panel:subrect(0, 0, ut.BASE_HEIGHT * 8, ut.BASE_HEIGHT, "left", 'up'))
		notif_panel.y = notif_panel.y + ut.BASE_HEIGHT
		notif_panel:shrink(5)
		ui.text(WORLD.notification_queue:peek(), notif_panel, "left", 'up')
		notif_panel:shrink(-5)
		notif_panel.y = notif_panel.y - ut.BASE_HEIGHT
		local button_rect = notif_panel:subrect(0, 0, ut.BASE_HEIGHT, ut.BASE_HEIGHT, "right", 'up')
		-- Interaction buttons
		if ui.icon_button(ASSETS.icons['circle.png'], button_rect, "Close all notifications") then
			WORLD.notification_queue:clear()
		end
		button_rect.x = button_rect.x - ut.BASE_HEIGHT
		if ui.icon_button(ASSETS.icons['cancel.png'], button_rect, "Close the notification") then
			WORLD.notification_queue:dequeue()
		end
	end

	-- Draw the top bar
	require "game.scenes.game.top-bar".draw(gam)

	-- Debugging screen thingy in top left
	local tt = require "engine.table"
	if tt.contains(ARGS, "--dev") == true then
		gam.debug_ui()
	end

	-- At the end, handle tile clicks.
	-- Make sure you add triggers for detecting clicks over UI!
	if click_detected then
		local click_success = false
		if gam.inspector == nil then
			click_success = true
		elseif gam.inspector == "tile" then
			click_success = require "game.scenes.game.tile-inspector".mask()
		elseif gam.inspector == "realm" then
			click_success = require "game.scenes.game.realm-inspector".mask()
		elseif gam.inspector == "building" then
			click_success = require "game.scenes.game.building-inspector".mask()
		elseif gam.inspector == "war" then
			click_success = require "game.scenes.game.war-inspector".mask()
		end

		if click_success and not mouse_in_bottom_right and (require "game.scenes.game.top-bar".mask(gam)) then
			gam.click_tile(new_clicked_tile)
			gam.on_tile_click()
			local skip_frame = false
			if gam.inspector == nil then
				skip_frame = true
			end
			if gam.inspector == "realm" then
				if WORLD.tiles[new_clicked_tile].province.realm ~= nil then
					if gam.selected_realm == WORLD.tiles[new_clicked_tile].province.realm then
						-- If we double click a realm, change the inspector to tile
						gam.inspector = "tile"
					else
						gam.selected_realm = WORLD.tiles[new_clicked_tile].province.realm
					end
				end
			else
				gam.inspector = "tile"
			end
			if skip_frame then
				return
			end
		end
	end

	-- ##################
	-- ### INSPECTORS ###
	-- ##################
	local tile_data_viewable = true
	if WORLD.tiles[gam.clicked_tile_id] ~= nil then
		if WORLD.player_realm ~= nil then
			local pro = WORLD.tiles[gam.clicked_tile_id].province
			if WORLD.player_realm.known_provinces[pro] == nil then
				tile_data_viewable = false
			end
		end
	end

	if tile_data_viewable then
		if gam.inspector == "tile" then
			require "game.scenes.game.tile-inspector".draw(gam)
		elseif gam.inspector == "realm" then
			require "game.scenes.game.realm-inspector".draw(gam)
		elseif gam.inspector == "building" then
			require "game.scenes.game.building-inspector".draw(gam)
		elseif gam.inspector == "war" then
			require "game.scenes.game.war-inspector".draw(gam)
		end
	end

	if ui.is_key_pressed('escape') then
		gam.inspector = nil
	end
end

-- #################
-- ### MAP MODES ###
-- #################
gam.map_mode_data = {}
gam.map_mode_tabs = {}
gam.map_mode_selected_tab = "all"
gam.map_mode_tabs.all = {}
gam.map_mode_tabs.debug = {}
require "game.scenes.game.map-modes".set_up_map_modes(gam)

---Given a tile coordinate, returns x/y coordinates on a texture to write!
---@param tile Tile
function gam.tile_id_to_color_coords(tile)
	local tile_id = tile.tile_id
	local ws = WORLD.world_size
	local tile_utils = require "game.entities.tile"

	local x, y, f = tile_utils.index_to_coords(tile_id)

	local fx = 0
	local fy = 0
	if f == 0 then
		-- nothing to do!
	elseif f == 1 then
		fx = ws
	elseif f == 2 then
		fx = 2 * ws
	elseif f == 3 then
		fy = ws
	elseif f == 4 then
		fy = ws
		fx = ws
	elseif f == 5 then
		fy = ws
		fx = 2 * ws
	else
		error("Invalid face: " .. tostring(f))
	end

	return x + fx, y + fy
end

---Changes the map mode to a new one
---@param new_map_mode string Valid map mode ID
function gam.update_map_mode(new_map_mode)
	gam.map_mode = new_map_mode
	gam.refresh_map_mode()
	CACHED_MAP_MODE = new_map_mode
end

function gam.recalculate_province_map()
	local dim = WORLD.world_size * 3
	gam.tile_province_image_data = gam.tile_province_image_data or love.image.newImageData(dim, dim, "rgba8")
	for _, tile in pairs(WORLD.tiles) do
		local x, y = gam.tile_id_to_color_coords(tile)
		if tile.province then
			local r = tile.province.r
			local g = tile.province.g
			local b = tile.province.b
			gam.tile_province_image_data:setPixel(x, y, r, g, b, 1)
		end
	end
	gam.tile_province_texture = love.graphics.newImage(gam.tile_province_image_data, {
		mipmaps = false,
		linear = true
	})
	gam.tile_province_texture:setFilter("nearest", "nearest")
end

---Refreshes the map mode
function gam.refresh_map_mode()
	local tim = love.timer.getTime()

	print(gam.map_mode)
	local dat = gam.map_mode_data[gam.map_mode]
	local func = dat[4]
	func(gam.clicked_tile_id) -- set "real color" on tiles
	-- Apply the color
	for _, tile in pairs(WORLD.tiles) do
		local can_set = true
		if WORLD.player_realm then
			can_set = false
			if WORLD.player_realm.known_provinces[tile.province] then
				can_set = true
			end
		end
		local x, y = gam.tile_id_to_color_coords(tile)
		if can_set then
			local r = tile.real_r
			local g = tile.real_g
			local b = tile.real_b
			gam.tile_color_image_data:setPixel(x, y, r, g, b, 1)
		else
			gam.tile_color_image_data:setPixel(x, y, 0.15, 0.15, 0.15, -1)
		end
	end
	-- Update the texture
	gam.tile_color_texture = love.graphics.newImage(gam.tile_color_image_data)
	gam.tile_color_texture:setFilter("nearest", "nearest")
	-- Update the minimap
	gam.minimap = require "game.minimap".make_minimap()

	local time = love.timer.getTime() - tim
	print("Map mode update time: " .. tostring(time * 1000) .. "ms")
end

return gam
