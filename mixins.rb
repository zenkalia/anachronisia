module Damageable
  attr_accessor :health

  def dead?
    @health <= 0
  end

  def take_damage_from(player)
    @health -= 5
    #@health -= player.weapon.damage
  end
end

module Directable
  attr_accessor :x
  attr_accessor :y
  attr_accessor :angle

  def angle_in_radians
    @angle * Math::PI / 180
  end

  def dx
    # x = r cos(theta)
    step_size * Math.cos(self.angle_in_radians)
  end

  def dy
    # y = r sin(theta)
    step_size * Math.sin(self.angle_in_radians)
  end

  def dx_left
    step_size * Math.cos(self.angle_in_radians + Math::PI/2)
  end

  def dy_left
    step_size * Math.sin(self.angle_in_radians + Math::PI/2)
  end

  def move(dx, dy, map)
    vert_hit = map.hit?(@x, @y + 4*dy)
    hor_hit = map.hit?(@x + 4*dx, @y)
    return if vert_hit and hor_hit and map.hit?(@x + 4*dx, @y + 4*dy)
    @x += dx unless hor_hit
    @y += dy unless vert_hit
  end

  def move_exact(dx, dy, map)
    return false if map.hit?(@x + 4*dx, @y + 4*dy)
    @x += dx
    @y += dy
  end
end
