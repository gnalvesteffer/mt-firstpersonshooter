--Helpers------------------------------------------

local function round(num, numDecimalPlaces)
  local mult = 10 ^ (numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

local function clamp(num, lower, upper)
  return math.max(lower, math.min(upper, num))
end

local function get_player_2d_velocity_magnitude(player)
  local velocity = player:get_player_velocity()
  return math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);
end

local function get_player_3d_velocity_magnitude(player)
  local velocity = player:get_player_velocity()
  return math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z);
end

--Core---------------------------------------------

first_person_shooter = {}
first_person_shooter.tick_rate = 60
first_person_shooter.last_update_time = 0
first_person_shooter.maximum_speed_smoothing_samples = 3
first_person_shooter.players_metadata = {}
first_person_shooter.registered_weapons = {}
first_person_shooter.projectiles = {}

first_person_shooter.get_weapon_metadata = function(weapon_name)
  return first_person_shooter.registered_weapons[weapon_name]
end

first_person_shooter.weapon_state_animation_data_calculators = {
  ["idle"] = function(player_metadata, weapon_metadata)
    local weapon_state_animation = weapon_metadata.animations[player_metadata.weapon_state]
    local frame_number = math.floor((player_metadata.weapon_state_time * weapon_metadata.animation_framerate % weapon_state_animation.total_frames) + 1)
    return {
      weapon_state_animation = weapon_state_animation,
      frame_number = frame_number,
    }
  end,
  ["aim_idle"] = function(player_metadata, weapon_metadata)
    local weapon_state_animation = weapon_metadata.animations[player_metadata.weapon_state]
    local frame_number = math.floor((player_metadata.weapon_state_time * weapon_metadata.animation_framerate % weapon_state_animation.total_frames) + 1)
    return {
      weapon_state_animation = weapon_state_animation,
      frame_number = frame_number,
    }
  end,
  ["aim_transition"] = function(player_metadata, weapon_metadata)
    local weapon_state_animation = weapon_metadata.animations[player_metadata.weapon_state]
    local frame_number = clamp(
        math.floor((player_metadata.weapon_state_time * weapon_metadata.animation_framerate) + 1),
        1,
        weapon_state_animation.total_frames
    )
    return {
      weapon_state_animation = weapon_state_animation,
      frame_number = frame_number,
    }
  end,
  ["aim_transition_reverse"] = function(player_metadata, weapon_metadata)
    local weapon_state_animation = weapon_metadata.animations["aim_transition"]
    local frame_number = clamp(
        math.floor(weapon_state_animation.total_frames - (player_metadata.weapon_state_time * weapon_metadata.animation_framerate) + 1),
        1,
        weapon_state_animation.total_frames
    )
    return {
      weapon_state_animation = weapon_state_animation,
      frame_number = frame_number,
    }
  end,
  ["fire"] = function(player_metadata, weapon_metadata)
    local weapon_state_animation = weapon_metadata.animations[player_metadata.weapon_state]
    local frame_number = clamp(
        math.floor((player_metadata.weapon_state_time * weapon_metadata.animation_framerate) + 1),
        1,
        weapon_state_animation.total_frames
    )
    return {
      weapon_state_animation = weapon_state_animation,
      frame_number = frame_number,
    }
  end,
  ["aim_fire"] = function(player_metadata, weapon_metadata)
    local weapon_state_animation = weapon_metadata.animations[player_metadata.weapon_state]
    local frame_number = clamp(
        math.floor((player_metadata.weapon_state_time * weapon_metadata.animation_framerate) + 1),
        1,
        weapon_state_animation.total_frames
    )
    return {
      weapon_state_animation = weapon_state_animation,
      frame_number = frame_number,
    }
  end,
  ["reload"] = function(player_metadata, weapon_metadata)
    local weapon_state_animation = weapon_metadata.animations[player_metadata.weapon_state]
    local frame_number = clamp(
        math.floor((player_metadata.weapon_state_time * weapon_metadata.animation_framerate) + 1),
        1,
        weapon_state_animation.total_frames
    )
    return {
      weapon_state_animation = weapon_state_animation,
      frame_number = frame_number,
    }
  end,
}

first_person_shooter.get_player_weapon_animation_data = function(player_metadata, weapon_metadata)
  return first_person_shooter.weapon_state_animation_data_calculators[player_metadata.weapon_state](player_metadata, weapon_metadata)
end

first_person_shooter.register_weapon = function(name, weapon_definition)
  first_person_shooter.registered_weapons[name] = weapon_definition
  minetest.register_tool(name, {
    description = weapon_definition.description,
    inventory_image = weapon_definition.icon,
    stack_max = 1,
    range = 0,
    liquids_pointable = false,
    on_use = function(itemstack, player, pointed_thing)

    end,
    on_secondary_use = function(itemstack, player, pointed_thing)
      local player_metadata = first_person_shooter.players_metadata[player:get_player_name()]
      if player_metadata.weapon_state == "idle" then
        player_metadata:set_weapon_state("aim_transition")
      else
        player_metadata:set_weapon_state("aim_transition_reverse")
      end
    end,
  })
end

first_person_shooter.spawn_particles = function(position, particle_definition)
  particle_definition = particle_definition or {}
  minetest.add_particlespawner({
    amount = particle_definition.amount or 15,
    time = particle_definition.time or 0.3,
    minpos = particle_definition.minpos or vector.subtract(position, { x = -0.1, y = -0.1, z = -0.1 }),
    maxpos = particle_definition.maxpos or vector.add(position, { x = 0.1, y = 0.1, z = 0.1 }),
    minvel = particle_definition.minvel or { x = -1, y = 1, z = -1 },
    maxvel = particle_definition.maxvel or { x = 1, y = 5, z = 1 },
    minacc = particle_definition.minacc or { x = -2, y = -2, z = -2 },
    maxacc = particle_definition.maxacc or { x = 2, y = -2, z = 2 },
    minexptime = particle_definition.minexptime or 0.1,
    maxexptime = particle_definition.maxexptime or 0.75,
    minsize = particle_definition.minsize or 1,
    maxsize = particle_definition.maxsize or 2,
    collisiondetection = particle_definition.collisiondetection or false,
    texture = particle_definition.texture or "default_hit.png",
  })
end

-- borrowed and modified from "shooter" mod by stu.
first_person_shooter.play_node_sound = function(node, pos)
  local item = minetest.registered_items[node.name]
  if item then
    if item.sounds then
      local spec = item.sounds.dug
      if spec then
        spec.pos = pos
        minetest.sound_play(spec.name, spec)
      end
    end
  end
end

-- borrowed and modified from "shooter" mod by stu.
first_person_shooter.on_node_hit = function(node_position, hit_info)
  local node = minetest.get_node(node_position)
  if not node then
    return
  end
  local item = minetest.registered_items[node.name]
  if not item then
    return
  end
  if item.groups then
    local node_metadata = minetest.get_meta(node_position)
    local current_node_health = node_metadata:get_int("health")
    if current_node_health == 0 then
      current_node_health = 3 -- ToDo: look up default values based-on node type
    end
    local new_node_health = math.max(current_node_health - 1, 0) -- ToDo: reduce node health by projectile damage
    node_metadata:set_int("health", new_node_health)
    if new_node_health == 0 then
      minetest.remove_node(node_position)
    end
    minetest.check_for_falling(node_position)
    first_person_shooter.play_node_sound(node, node_position)
    if item.tiles then
      if item.tiles[1] then
        first_person_shooter.spawn_particles(
            node_position,
            {
              texture = item.tiles[1],
              amount = 10,
              time = 0.05,
              minvel = vector.add(vector.multiply(hit_info.muzzle_direction, hit_info.weapon_metadata.muzzle_velocity * -0.001), { x = -1, y = -1, z = -1 }),
              maxvel = vector.add(vector.multiply(hit_info.muzzle_direction, hit_info.weapon_metadata.muzzle_velocity * -0.05), { x = 1, y = 1, z = 1 }),
              minexptime = 0.05,
              maxexptime = 0.5,
              minsize = 0.25,
              maxsize = 2,
            })
      end
    end
    --local object = minetest.add_item(position, item)
    --if object then
    --  object:set_velocity({
    --    x = math.random(-1, 1),
    --    y = 4,
    --    z = math.random(-1, 1)
    --  })
    --end
  end
end

first_person_shooter.spawn_projectile = function()
  local projectile = {}
  first_person_shooter.projectiles.insert(projectile)
  return projectile
end

first_person_shooter.on_weapon_fire = function(player_metadata)
  local weapon_metadata = player_metadata:get_weapon_metadata()
  if not weapon_metadata then
    return
  end
  minetest.sound_play(
      weapon_metadata.sounds["fire"].sound_name,
      {
        object = player_metadata.player,
        gain = 1.0,
        max_hear_distance = 100,
        loop = false,
      }
  )
  local muzzle_position = player_metadata:get_weapon_muzzle_position()
  local muzzle_direction = player_metadata:get_weapon_muzzle_direction()
  local projectile_raycast = minetest.raycast(muzzle_position, vector.add(muzzle_position, vector.multiply(muzzle_direction, 100)), true, true)
  local hit_object = projectile_raycast:next() or { type = "nothing" }
  if hit_object.type == "node" then
    local hit_node_position = minetest.get_pointed_thing_position(hit_object, false)
    first_person_shooter.on_node_hit(hit_node_position, {
      weapon_metadata = weapon_metadata,
      muzzle_position = muzzle_position,
      muzzle_direction = muzzle_direction,
    })
  end
end

--Register Weapons---------------------------------

first_person_shooter.register_weapon("first_person_shooter:m16a2", {
  description = "M16A2",
  icon = "m16a2_icon.png",
  muzzle_velocity = 100,
  is_automatic_fire = true,
  animation_framerate = 120,
  animations = {
    ["idle"] = {
      texture_prefix = "m16a2_idle",
      total_frames = 1,
    },
    ["aim_idle"] = {
      texture_prefix = "m16a2_aimidle",
      total_frames = 1,
    },
    ["aim_transition"] = {
      texture_prefix = "m16a2_aim",
      total_frames = 11,
    },
    ["fire"] = {
      texture_prefix = "m16a2_fire",
      total_frames = 12,
    },
    ["aim_fire"] = {
      texture_prefix = "m16a2_aimfire",
      total_frames = 12,
    },
    ["reload"] = {
      texture_prefix = "m16a2_idle",
      total_frames = 1,
    },
  },
  sounds = {
    ["fire"] = {
      sound_name = "m16a2_fire",
    }
  },
})

--Player-------------------------------------------

first_person_shooter.initialize_player = function(player)
  local speed_smoothing_samples = {}
  for speed_smoothing_sample_index = 0, first_person_shooter.maximum_speed_smoothing_samples do
    speed_smoothing_samples[speed_smoothing_sample_index] = 0
  end

  first_person_shooter.players_metadata[player:get_player_name()] = {
    player = player,
    life_time = 0,
    weapon_state = "idle",
    weapon_state_time = 0,
    has_requested_to_fire = false,
    has_handled_previous_fire_request = false,
    movement_amount = 0,
    speed_smoothing_samples = speed_smoothing_samples,
    get_average_speed = function(this)
      local speed_sample_sum = 0
      for speed_smoothing_sample_index = 0, first_person_shooter.maximum_speed_smoothing_samples do
        speed_sample_sum = speed_sample_sum + this.speed_smoothing_samples[speed_smoothing_sample_index]
      end
      return math.ceil(speed_sample_sum / first_person_shooter.maximum_speed_smoothing_samples)
    end,
    set_weapon_state = function(this, weapon_state)
      this.weapon_state = weapon_state
      this.weapon_state_time = 0
      first_person_shooter.on_weapon_state_begin(this)
    end,
    get_weapon_metadata = function(this)
      return first_person_shooter.get_weapon_metadata(this.player:get_wielded_item():get_name())
    end,
    get_weapon_muzzle_position = function(this)
      local horizontal_look_direction = this.player:get_look_horizontal() + math.pi / 2
      local vertical_look_direction = this.player:get_look_vertical()
      local player_position = this.player:get_pos()
      return {
        x = player_position.x + math.cos(horizontal_look_direction),
        y = player_position.y + 1 - vertical_look_direction,
        z = player_position.z + math.sin(horizontal_look_direction),
      }
    end,
    get_weapon_muzzle_direction = function(this)
      local aim_compensation = { x = 0, y = -math.pi * 0.03, z = 0 }
      return vector.add(this.player:get_look_dir(), aim_compensation)
    end,
  }
end

first_person_shooter.next_weapon_state = {
  ["idle"] = "idle",
  ["aim_idle"] = "aim_idle",
  ["aim_transition"] = "aim_idle",
  ["aim_transition_reverse"] = "idle",
  ["fire"] = "idle",
  ["aim_fire"] = "aim_idle",
  ["reload"] = "idle",
}

first_person_shooter.weapon_state_begin_handlers = {
  ["idle"] = function(player_metadata)

  end,
  ["aim_idle"] = function(player_metadata)

  end,
  ["aim_transition"] = function(player_metadata)

  end,
  ["aim_transition_reverse"] = function(player_metadata)

  end,
  ["fire"] = function(player_metadata)
    first_person_shooter.on_weapon_fire(player_metadata)
  end,
  ["aim_fire"] = function(player_metadata)
    first_person_shooter.on_weapon_fire(player_metadata)
  end,
  ["reload"] = function(player_metadata)

  end,
}

first_person_shooter.on_weapon_state_begin = function(player_metadata)
  first_person_shooter.weapon_state_begin_handlers[player_metadata.weapon_state](player_metadata)
end

first_person_shooter.on_weapon_state_end = function(player_metadata)
  player_metadata:set_weapon_state(first_person_shooter.next_weapon_state[player_metadata.weapon_state])
end

first_person_shooter.update_players = function(deltaTime)
  for player_name, player_metadata in pairs(first_person_shooter.players_metadata) do
    local weapon_metadata = player_metadata:get_weapon_metadata()
    if not weapon_metadata then
      player_metadata.player:hud_remove(player_metadata.weapon_hud_element)
      player_metadata.player:hud_set_flags({
        hotbar = true,
        healthbar = true,
        crosshair = true,
        wielditem = true,
        breathbar = true,
      })
      return
    else
      player_metadata.player:hud_set_flags({
        hotbar = false,
        healthbar = false,
        crosshair = false,
        wielditem = false,
        breathbar = false,
      })
    end

    -- handle automatic fire
    player_metadata.has_requested_to_fire = player_metadata.player:get_player_control().LMB and player_metadata.has_handled_previous_fire_request or weapon_metadata.is_automatic_fire
    player_metadata.has_handled_previous_fire_request = false
    if player_metadata.has_requested_to_fire then
      if player_metadata.weapon_state == "idle" then
        player_metadata:set_weapon_state("fire")
      else
        if player_metadata.weapon_state == "aim_idle" then
          player_metadata:set_weapon_state("aim_fire")
        end
      end
      player_metadata.has_handled_previous_fire_request = true
    end

    player_metadata.life_time = player_metadata.life_time + deltaTime
    player_metadata.weapon_state_time = player_metadata.weapon_state_time + deltaTime

    local player_velocity_magnitude = get_player_2d_velocity_magnitude(player_metadata.player)
    player_metadata.speed_smoothing_samples[math.floor(player_metadata.life_time * 100 % first_person_shooter.maximum_speed_smoothing_samples)] = player_velocity_magnitude
    local average_speed = player_metadata:get_average_speed()

    if average_speed == 0 then
      player_metadata.movement_amount = player_metadata.movement_amount - deltaTime
    else
      player_metadata.movement_amount = player_metadata.movement_amount + deltaTime
    end
    player_metadata.movement_amount = clamp(player_metadata.movement_amount, 0, 1)

    local breathing_x_offset = math.cos(player_metadata.life_time) * 0.002
    local breathing_y_offset = math.sin(player_metadata.life_time * 1.25) * 0.005
    local movement_x_offset = (math.sin(player_metadata.life_time * average_speed * 1.5) * 0.012) * player_metadata.movement_amount
    local movement_y_offset = (math.sin(player_metadata.life_time * average_speed * 3) * 0.013) * player_metadata.movement_amount

    local animation_data = first_person_shooter.get_player_weapon_animation_data(player_metadata, weapon_metadata)
    player_metadata.player:hud_remove(player_metadata.weapon_hud_element)
    player_metadata.weapon_hud_element = player_metadata.player:hud_add({
      hud_elem_type = "image",
      text = animation_data.weapon_state_animation.texture_prefix .. "." .. animation_data.frame_number .. ".png",
      position = {
        x = 0.5 - breathing_x_offset - movement_x_offset,
        y = 0.55 - breathing_y_offset - movement_y_offset
      },
      scale = { x = -100, y = -100 },
      alignment = { x = 0, y = 0 },
      offset = { x = 0, y = 0 },
      size = { x = 1280, y = 720 },
    })

    local animation_duration = (animation_data.weapon_state_animation.total_frames - 1) / weapon_metadata.animation_framerate
    if player_metadata.weapon_state_time >= animation_duration then
      first_person_shooter.on_weapon_state_end(player_metadata)
    end
  end
end

first_person_shooter.update_projectiles = function(deltaTime)

end

first_person_shooter.update = function(deltaTime)
  first_person_shooter.update_players(deltaTime)
  first_person_shooter.update_projectiles(deltaTime)
  local current_time = minetest.get_server_uptime()
  minetest.after(1 / first_person_shooter.tick_rate, first_person_shooter.update, current_time - first_person_shooter.last_update_time)
  first_person_shooter.last_update_time = current_time
end

minetest.register_on_joinplayer(first_person_shooter.initialize_player)
first_person_shooter.update()