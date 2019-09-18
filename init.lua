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
      local player_metadata = first_person_shooter.players_metadata[player:get_player_name()]
      if player_metadata.weapon_state == "idle" then
        player_metadata:set_weapon_state("fire")
      else
        if player_metadata.weapon_state == "aim_idle" then
          player_metadata:set_weapon_state("aim_fire")
        end
      end
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
end

--Register Weapons---------------------------------

first_person_shooter.register_weapon("first_person_shooter:m1_garand", {
  description = "M1 Garand",
  icon = "m1_garand_icon.png",
  animation_framerate = 60,
  animations = {
    ["idle"] = {
      texture_prefix = "m1_garand_idle",
      total_frames = 1,
    },
    ["aim_idle"] = {
      texture_prefix = "m1_garand_aimidle",
      total_frames = 1,
    },
    ["aim_transition"] = {
      texture_prefix = "m1_garand_aim",
      total_frames = 7,
    },
    ["fire"] = {
      texture_prefix = "m1_garand_fire",
      total_frames = 12,
    },
    ["aim_fire"] = {
      texture_prefix = "m1_garand_aimfire",
      total_frames = 12,
    },
    ["reload"] = {
      texture_prefix = "m1_garand_reload",
      total_frames = 83,
    },
  },
  sounds = {
    ["fire"] = {
      sound_name = "m1_garand_fire",
    }
  },
})

first_person_shooter.register_weapon("first_person_shooter:m1911", {
  description = "M1911",
  icon = "m1911_icon.png",
  animation_framerate = 60,
  animations = {
    ["idle"] = {
      texture_prefix = "m1911_idle",
      total_frames = 1,
    },
    ["aim_idle"] = {
      texture_prefix = "m1911_aimidle",
      total_frames = 1,
    },
    ["aim_transition"] = {
      texture_prefix = "m1911_aim",
      total_frames = 7,
    },
    ["fire"] = {
      texture_prefix = "m1911_fir",
      total_frames = 10,
    },
    ["aim_fire"] = {
      texture_prefix = "m1911_aimfir",
      total_frames = 11,
    },
    ["reload"] = {
      texture_prefix = "m1911_reload",
      total_frames = 51,
    },
  },
  sounds = {
    ["fire"] = {
      sound_name = "m1911_fire",
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
      text = animation_data.weapon_state_animation.texture_prefix .. animation_data.frame_number .. ".png",
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