require './weapon'

class Player
  include Damageable
  include Directable
  STEP_SIZE = 12
  ANGLE_SPEED = 6
  FOV = 60.0 # Field of View
  HALF_FOV = FOV / 2
  DISTANCE_TO_PROJECTION = (RbConfig::WINDOW_WIDTH / 2) / Math.tan((FOV / 2) * Math::PI / 180)
  RAY_ANGLE_DELTA = (FOV / RbConfig::WINDOW_WIDTH)

  attr_accessor :x
  attr_accessor :y
  attr_accessor :height
  attr_accessor :angle
  attr_accessor :health
  attr_accessor :weapon
  attr_accessor :window
  attr_accessor :score
  attr_accessor :max_health
  attr_accessor :running
  attr_accessor :crouching
  attr_accessor :jumping
  attr_accessor :weapon

  def initialize(window)
    @x = 0.0
    @y = 0.0
    @angle  = 0.0
    @health = 100
    @window = window
    @score  = 0
    @max_health = 100
    @running = false
    @crouched = false
    @jumping = false
    @height = 0.5
    @weapon = PowerOfCode.new(window)
  end

  def update
    if @jumping
      @height = @height + (1-@height)/5 if @jumping == :up
      @height = @height - (1-@height)/5 if @jumping == :down
      @jumping = :down if @jumping == :up and @height > 0.8
      if @jumping == :down and @height <= 0.5
        @jumping = false
        @height = 0.5
      end
    end
    if @crouching
      @height = @height - 0.08 if @crouching == :down
      @height = @height + 0.08 if @crouching == :up
      if @crouching == :down and @height <= 0.3
        @height = 0.3
        @crouching = true
      end
      if @crouching == :up and @height >= 0.5
        @height = 0.5
        @crouching = false
      end
    end

  end

  def angle_speed
    self.running ? ANGLE_SPEED * 1.5 : ANGLE_SPEED
  end

  def turn_left
    @angle = (@angle + angle_speed) % 360
  end

  def turn_right
    @angle = (@angle - angle_speed) % 360
  end

  def step_size
    return STEP_SIZE * 0.5 if self.crouching
    self.running ? STEP_SIZE * 1.5 : STEP_SIZE
  end

  def move_forward(map)
    move(dx, -dy, map)
  end

  def move_backward(map)
    move(-dx, dy, map)
  end

  def move_left(map)
    move(dx_left, -dy_left, map)
  end

  def move_right(map)
    move(-dx_left, dy_left, map)
  end

  def health_percent
    @health * 100.0 / @max_health
  end

  def take_damage_from(player, damage)
    return if @health <= 0
    @health -= damage
    @health = 0 if @health < 0
  end
end
