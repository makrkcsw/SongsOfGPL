local pla = {}

function pla.get_shader()
	local vs = [[
		attribute float Face;
		varying float FaceValue;

		uniform mat4 model;
		uniform mat4 view;
		uniform mat4 projection;

		vec4 position(mat4 _, vec4 vertex_position)
		{
			FaceValue = Face;
			return projection * view * model * vertex_position;
		}
	]]
	local fs = [[
		uniform float world_size;
		uniform sampler2D tile_colors;
		uniform sampler2D tile_provinces;
		uniform float clicked_tile;
		uniform float camera_distance_from_sphere;
		uniform float time;
		varying float FaceValue;

		vec2 get_face_offset(float face_value) {
			// 0 1 2
			// 3 4 5
			// - - -
			vec2 base_step_x = vec2(1, 0) / 3;
			vec2 base_step_y = vec2(0, 1) / 3;
			vec2 face_offset = vec2(0, 0);
			if (abs(face_value - 1.0) < 0.01) {
				face_offset += base_step_x;
			} else if (abs(face_value - 2.0) < 0.01) {
				face_offset += base_step_x * 2;
			} else if (abs(face_value - 3.0) < 0.01) {
				face_offset += base_step_y;
			} else if (abs(face_value - 4.0) < 0.01) {
				face_offset += base_step_y;
				face_offset += base_step_x;
			} else if (abs(face_value - 5.0) < 0.01) {
				face_offset += base_step_y;
				face_offset += base_step_x * 2;
			}
			return face_offset;
		}

		float max3(vec4 a) {
			return max(a.r, max(a.g, a.b));
		}

		vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord)
		{
			float y = floor(texcoord.y * world_size);
			float x = floor(texcoord.x * world_size);
			float tile_id = x + y * world_size + FaceValue * world_size * world_size;
			// This variable stores uv coordinates of *a single tile*
			vec2 tile_uv = vec2((texcoord.x * world_size) - x, (texcoord.y * world_size) - y);

			float clicked_face = floor(clicked_tile / world_size / world_size);
			float remainder = clicked_tile - clicked_face * world_size * world_size;
			float clicked_y = floor(remainder / world_size);
			float clicked_x = remainder - clicked_y * world_size + 1; // these +1s are needed for reasons I dont understand. Maybe some weird love2d thing compiling glsl as if its 1 indexed like lua?
			clicked_y += 1;
			clicked_x -= 1;
			clicked_y /= world_size;
			clicked_x /= world_size;
			vec2 clickedcoords = vec2(clicked_x, clicked_y);

			if (camera_distance_from_sphere < 0.35) {
				// Clicked tile!
				if (abs(tile_id - clicked_tile) < 0.05) {
					float d = sin(time) * 0.025;
					if (abs(tile_uv.x - 0.5) > 0.43 + d || abs(tile_uv.y - 0.5) > 0.43 + d) {
						return vec4(0.85, 0.4, 0.2, 1);
					}
				}
				// Tile borders!
				//if (abs(tile_uv.x - 0.5) > 0.47 || abs(tile_uv.y - 0.5) > 0.47) {
				//	return vec4(0.4, 0.4, 0.4, 1);
				//}
			}
			vec2 up = texcoord / 3;
			vec2 down = texcoord / 3;
			vec2 left = texcoord / 3;
			vec2 right = texcoord / 3;
			vec2 clicked = clickedcoords / 3;
			up.y -= 1 / world_size / 3;
			down.y += 1 / world_size / 3;
			left.x += 1.0 / world_size / 3;
			right.x -= 1.0 / world_size / 3;
			up += get_face_offset(FaceValue);
			down += get_face_offset(FaceValue);
			left += get_face_offset(FaceValue);
			right += get_face_offset(FaceValue);
			clicked += get_face_offset(clicked_face);

			vec2 face_offset = get_face_offset(FaceValue) + texcoord / 3;
			vec4 texcolor = Texel(tile_colors, face_offset);
			if (texcolor.a < 0.5) {
				// this tile is covered by fog of war -- ignore province and river information!
				texcolor.a = 1.0;
			} else {
				// since this tile isn't under fog of war, we can render further details on it.
				// Province borders!
				vec4 my_bord = Texel(tile_provinces, face_offset);
				vec4 clicked_bord = Texel(tile_provinces, clicked);
				vec4 up_bord = Texel(tile_provinces, up);
				vec4 down_bord = Texel(tile_provinces, down);
				vec4 left_bord = Texel(tile_provinces, left);
				vec4 right_bord = Texel(tile_provinces, right);

				float province_border_thickness = 0.15;
				vec4 province_border_color = vec4(0.4, 0.4, 0.4, 1);
				if (max3(abs(my_bord - clicked_bord)) < 0.0001) {
					province_border_color = vec4(0.85, 0.4, 0.2, 1);
				}
				if (max3(abs(my_bord - up_bord)) > 0.01) {
					if (tile_uv.y < province_border_thickness) {
						return province_border_color;
					}
				}
				if (max3(abs(my_bord - down_bord)) > 0.01) {
					if (tile_uv.y > 1 - province_border_thickness) {
						return province_border_color;
					}
				}
				if (max3(abs(my_bord - left_bord)) > 0.01) {
					if (tile_uv.x > 1 - province_border_thickness) {
						return province_border_color;
					}
				}
				if (max3(abs(my_bord - right_bord)) > 0.01) {
					if (tile_uv.x < province_border_thickness) {
						return province_border_color;
					}
				}
			}
			return texcolor * color;
		}
	]]

	return love.graphics.newShader(fs, vs)
end

return pla
