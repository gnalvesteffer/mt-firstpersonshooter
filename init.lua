--Helpers------------------------------------------

local function round(num, numDecimalPlaces)
  local mult = 10 ^ (numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

local function clamp(num, lower, upper)
  return math.max(lower, math.min(upper, num))
end

local function cross_product(a, b)
  return {
    x = a.y * b.z - a.z * b.y,
    y = a.z * b.x - a.x * b.z,
    z = a.x * b.y - a.y * b.x
  }
end

local function dot_product(a, b)
  local result = 0
  for i = 1, #a do
    result = result + a[i] * b[i]
  end
  return result
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
first_person_shooter.blood_emission_multiplier = 5
first_person_shooter.players_metadata = {}
first_person_shooter.registered_weapons = {}

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
  return minetest.add_particlespawner({
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

-- adapted from "shooter" mod by stu.
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

first_person_shooter.initial_node_properties_lookup_table = {
  names = {

  },
  groups = {
    ["cracky"] = {
      health = 5,
      penetration_durability = 0.05,
    },
    ["stone"] = {
      health = 100,
      penetration_durability = 1,
    },
    ["crumbly"] = {
      health = 25,
      penetration_durability = 0.25,
    },
    ["sand"] = {
      health = 25,
      penetration_durability = 0.5,
    },
    ["choppy"] = {
      health = 20,
      penetration_durability = 0.3,
    },
    ["wood"] = {
      health = 50,
      penetration_durability = 0.75,
    },
    ["tree"] = {
      health = 150,
      penetration_durability = 0.75,
    },
    ["leaves"] = {
      health = -100,
      penetration_durability = -5,
    },
    ["pane"] = {
      health = -100,
      penetration_durability = -5,
    },
  },
}

first_person_shooter.default_node_properties = {
  health = 0,
  penetration_durability = 0,
}

first_person_shooter.get_node_properties = function(node_name)
  local properties_by_node_name = first_person_shooter.initial_node_properties_lookup_table.names[node_name]
  if properties_by_node_name == nil then
    local node_definition = minetest.registered_nodes[node_name]
    if node_definition == nil then
      return first_person_shooter.default_node_properties
    end
    local aggregate_node_properties = table.copy(first_person_shooter.default_node_properties)
    for group_name, value in pairs(node_definition.groups) do
      local properties_by_group_name = first_person_shooter.initial_node_properties_lookup_table.groups[group_name]
      if properties_by_group_name ~= nil then
        aggregate_node_properties.health = aggregate_node_properties.health + (properties_by_group_name.health * value)
        aggregate_node_properties.penetration_durability = aggregate_node_properties.penetration_durability + (properties_by_group_name.penetration_durability * value)
      end
    end
    return aggregate_node_properties
  end
  return properties_by_node_name
end

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
    local node_properties = first_person_shooter.get_node_properties(node.name)
    if current_node_health == 0 then
      current_node_health = node_properties.health
    end
    local new_node_health = current_node_health
    if hit_info.weapon_metadata.penetration_power >= node_properties.penetration_durability then
      new_node_health = math.max(current_node_health - hit_info.weapon_metadata.penetration_power * hit_info.weapon_metadata.damage, 0)
    end
    node_metadata:set_int("health", new_node_health)

    if new_node_health == 0 then
      minetest.remove_node(node_position)
      minetest.check_for_falling(node_position)
    else
      first_person_shooter.create_bullet_hole(hit_info.hit_position, hit_info.hit_normal, node_position)
    end

    first_person_shooter.play_node_sound(node, node_position)
    if item.tiles and item.tiles[1] then
      first_person_shooter.spawn_particles(
          hit_info.hit_position,
          {
            texture = item.tiles[1],
            amount = 10,
            time = 0.05,
            minvel = vector.add(vector.multiply(hit_info.muzzle_direction, hit_info.weapon_metadata.penetration_power * hit_info.weapon_metadata.damage * -0.05), { x = -1, y = -1, z = -1 }),
            maxvel = vector.add(vector.multiply(hit_info.muzzle_direction, hit_info.weapon_metadata.penetration_power * hit_info.weapon_metadata.damage * -0.2), { x = 1, y = 1, z = 1 }),
            minexptime = 0.05,
            maxexptime = 0.5,
            minsize = 0.25,
            maxsize = 2,
          }
      )
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

first_person_shooter.on_object_hit = function(object, attacker, hit_info)
  object:punch(
      attacker,
      nil,
      {
        full_punch_interval = 1.0,
        damage_groups = { fleshy = hit_info.weapon_metadata.damage },
      },
      nil
  )
  first_person_shooter.emit_blood(
      hit_info.hit_position,
      hit_info.muzzle_direction,
      math.ceil(hit_info.weapon_metadata.damage * hit_info.weapon_metadata.penetration_power) * first_person_shooter.blood_emission_multiplier
  )
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
  local projectile_raycast = minetest.raycast(muzzle_position, vector.add(muzzle_position, vector.multiply(muzzle_direction, weapon_metadata.maximum_range)), true, true)
  local hit_object = projectile_raycast:next() or { type = "nothing" }
  if hit_object.ref == player_metadata.player then
    hit_object = projectile_raycast:next() or { type = "nothing" }
  end
  local hit_info = {
    weapon_metadata = weapon_metadata,
    muzzle_position = muzzle_position,
    muzzle_direction = muzzle_direction,
    hit_position = hit_object.intersection_point,
    hit_normal = hit_object.intersection_normal,
  }
  if hit_object.type == "node" then
    local hit_node_position = minetest.get_pointed_thing_position(hit_object, false)
    first_person_shooter.on_node_hit(hit_node_position, hit_info)
  elseif hit_object.type == "object" then
    first_person_shooter.on_object_hit(hit_object.ref, player_metadata.player, hit_info)
  end
end

minetest.register_entity("first_person_shooter:bullet_hole", {
  initial_properties = {
    visual = "mesh",
    mesh = "plane.obj",
    visual_size = { x = 1, y = 1 },
    textures = { "bullet_hole.png" },
    collisionbox = { 0, 0, 0, 0, 0, 0 },
    pointable = false,
    static_save = false,
  },
  on_activate = function(self, static_data)
    if static_data == "" or static_data == nil then
      return
    end
    static_data = minetest.deserialize(static_data) or {}
    self._attached_node_position = static_data.attached_node_position
    self.object:set_rotation(vector.multiply({ x = static_data.rotation.z, y = static_data.rotation.y, z = static_data.rotation.x }, math.pi / 2))
    self.object:set_armor_groups({ immortal = 1 })
  end,
  on_step = function(self, delta_time)
    self._life_time = self._life_time + delta_time
    local attached_node = minetest.get_node(self._attached_node_position or { x = 0, y = 0, z = 0 })
    if self._life_time >= self._despawn_time or attached_node.name == "air" then
      self.object:remove()
    end
  end,
  _life_time = 0,
  _despawn_time = 30,
})

first_person_shooter.create_bullet_hole = function(position, surface_normal, attached_node_position)
  minetest.add_entity(
      vector.add(position, vector.multiply(surface_normal, 0.01)),
      "first_person_shooter:bullet_hole",
      minetest.serialize({
        attached_node_position = attached_node_position,
        rotation = surface_normal,
      })
  )
end

minetest.register_entity("first_person_shooter:blood_drop", {
  initial_properties = {
    visual = "mesh",
    mesh = "plane.obj",
    visual_size = { x = 0.15, y = 0.15 },
    textures = { "blood_drop.png" },
    collisionbox = { 0, 0, 0, 0, 0, 0 },
    pointable = false,
    static_save = false,
  },
  on_activate = function(self, static_data)
    if static_data == "" or static_data == nil then
      return
    end
    static_data = minetest.deserialize(static_data) or {}
    self._attached_node_position = static_data.attached_node_position
    self.object:set_rotation(vector.multiply({ x = static_data.rotation.z, y = static_data.rotation.y, z = static_data.rotation.x }, math.pi / 2))
    self.object:set_armor_groups({ immortal = 1 })
  end,
  on_step = function(self, delta_time)
    self._life_time = self._life_time + delta_time
    local attached_node = minetest.get_node(self._attached_node_position or { x = 0, y = 0, z = 0 })
    if self._life_time >= self._despawn_time or attached_node.name == "air" then
      self.object:remove()
    end
  end,
  _life_time = 0,
  _despawn_time = 30,
})

first_person_shooter.emit_blood = function(position, direction, amount)
  for blood_drop_iteration = 0, amount do
    local random_direction = vector.multiply({ x = 1 - math.random() * 2, y = 1 - math.random() * 2, z = 1 - math.random() * 2 }, math.random() * 0.25)
    local blood_drop_direction = vector.add(direction, random_direction)
    local blood_drop_raycast = minetest.raycast(position, vector.add(position, vector.multiply(blood_drop_direction, 2)), false, false)
    local colliding_object = blood_drop_raycast:next() or { type = "nothing" }
    if colliding_object.type ~= "node" then
      colliding_object = blood_drop_raycast:next() or { type = "nothing" }
    end
    if colliding_object.type == "node" then
      local attached_node_position = minetest.get_pointed_thing_position(colliding_object, false)
      minetest.add_entity(
          vector.add(colliding_object.intersection_point, vector.multiply(colliding_object.intersection_normal, 0.01)),
          "first_person_shooter:blood_drop",
          minetest.serialize({
            attached_node_position = attached_node_position,
            rotation = colliding_object.intersection_normal,
          })
      )
    end
  end
end

--Register Weapons---------------------------------

first_person_shooter.register_weapon("first_person_shooter:m16a2", {
  description = "M16A2",
  icon = "m16a2_icon.png",
  maximum_range = 300,
  penetration_power = 2,
  damage = 10,
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

first_person_shooter.register_weapon("first_person_shooter:m4a1", {
  description = "M4A1",
  icon = "m16a2_icon.png",
  maximum_range = 150,
  penetration_power = 1,
  damage = 7,
  is_automatic_fire = true,
  animation_framerate = 120,
  animations = {
    ["idle"] = {
      texture_prefix = "m4a1_idle",
      total_frames = 1,
    },
    ["aim_idle"] = {
      texture_prefix = "m4a1_aimidle",
      total_frames = 1,
    },
    ["aim_transition"] = {
      texture_prefix = "m4a1_aim",
      total_frames = 11,
    },
    ["fire"] = {
      texture_prefix = "m4a1_fire",
      total_frames = 11,
    },
    ["aim_fire"] = {
      texture_prefix = "m4a1_aimfire",
      total_frames = 11,
    },
    ["reload"] = {
      texture_prefix = "m4a1_reload",
      total_frames = 210,
    },
  },
  sounds = {
    ["fire"] = {
      sound_name = "m4a1_fire",
    }
  },
})

first_person_shooter.register_weapon("first_person_shooter:hk53", {
  description = "HK53",
  icon = "m16a2_icon.png",
  maximum_range = 100,
  penetration_power = 0.2,
  damage = 5,
  is_automatic_fire = true,
  animation_framerate = 120,
  animations = {
    ["idle"] = {
      texture_prefix = "hk53_idle",
      total_frames = 1,
    },
    ["aim_idle"] = {
      texture_prefix = "hk53_aimidle",
      total_frames = 1,
    },
    ["aim_transition"] = {
      texture_prefix = "hk53_aim",
      total_frames = 11,
    },
    ["fire"] = {
      texture_prefix = "hk53_fire",
      total_frames = 13,
    },
    ["aim_fire"] = {
      texture_prefix = "hk53_aimfire",
      total_frames = 13,
    },
    ["reload"] = {
      texture_prefix = "hk53_reload",
      total_frames = 370,
    },
  },
  sounds = {
    ["fire"] = {
      sound_name = "hk53_fire",
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
    is_firing = false,
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
      local player_eye_position = vector.add(this.player:get_pos(), { x = 0, y = this.player:get_properties().eye_height, z = 0 })
      return {
        x = player_eye_position.x,
        y = player_eye_position.y,
        z = player_eye_position.z,
      }
    end,
    get_weapon_muzzle_direction = function(this)
      return vector.multiply(this.player:get_look_dir(), math.pi / 2)
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

    if player_metadata.player:get_player_control().LMB then
      player_metadata.is_firing = not player_metadata.has_fired_last_tick or weapon_metadata.is_automatic_fire
    else
      player_metadata.is_firing = false
      player_metadata.has_fired_last_tick = false
    end
    if player_metadata.is_firing then
      if player_metadata.weapon_state == "idle" then
        player_metadata:set_weapon_state("fire")
      else
        if player_metadata.weapon_state == "aim_idle" then
          player_metadata:set_weapon_state("aim_fire")
        end
      end
      player_metadata.has_fired_last_tick = true
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
        x = 0.5,
        y = 0.5,
      },
      scale = { x = -100, y = -100 },
      alignment = { x = 0, y = 0 },
      offset = { x = 0, y = 0 },
      size = { x = 16, y = 9 },
    })

    local animation_duration = (animation_data.weapon_state_animation.total_frames - 1) / weapon_metadata.animation_framerate
    if player_metadata.weapon_state_time >= animation_duration then
      first_person_shooter.on_weapon_state_end(player_metadata)
    end
  end
end

first_person_shooter.update = function(deltaTime)
  first_person_shooter.update_players(deltaTime)
  local current_time = minetest.get_server_uptime()
  minetest.after(1 / first_person_shooter.tick_rate, first_person_shooter.update, current_time - first_person_shooter.last_update_time)
  first_person_shooter.last_update_time = current_time
end

minetest.register_on_joinplayer(first_person_shooter.initialize_player)
first_person_shooter.update()