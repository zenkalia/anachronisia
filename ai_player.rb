require './map'
require './sprite'
require './weapon'
require './sound'

module AStar
  Coordinate = Struct.new(:x, :y)

  def line_of_sight(map,start, goal)
    start  = Coordinate.new(start[0], start[1])
    goal   = Coordinate.new(goal[0], goal[1])

    dy = (goal.y.to_f - start.y)/100
    dx = (goal.x.to_f - start.x)/100

    x = start.x
    y = start.y

    100.times do
      return false unless map.walkable?(y.to_i,x.to_i)
      x += dx
      y += dy
    end

    return Coordinate.new((start.x+goal.x)/2, (start.y+goal.y)/2)
  end

  def find_path(map, start, goal)
    line_of_sight(map, start, goal)
  end

  def dist_between(a, b)
    col_a, row_a = Map.matrixify(a.x, a.y)
    col_b, row_b = Map.matrixify(b.x, b.y)

    if col_a == col_b && row_a != row_b
      1.0
    elsif col_a != col_b && row_a == row_b
      1.0
    else
      1.4142135623731 # Sqrt(1**2 + 1**2)
    end
  end

  def neighbor_nodes(map, node)
    node_x, node_y = node.x, node.y
    result = []

    x = node_x - 1
    x_max = node_x + 1
    y_max = node_y + 1
    while(x <= x_max && x < map.width)
      y = node_y - 1

      while(y <= y_max && y < map.height)
        result << Coordinate.new(x, y) unless (x == node_x && y == node_y)
        y += 1
      end

      x += 1
    end

    return result
  end

  def heuristic_estimate_of_distance(start, goal)
    # Manhattan distance
    (goal.x - start.x).abs + (goal.y - start.y).abs
  end

  def reconstruct_path(came_from, current_node)
    #puts "START TRACE"

    while came_from[current_node]
      #puts "#{current_node[0]}, #{current_node[1]}"
      parent = came_from[current_node]

      if came_from[parent].nil?
        # No more parent for this node, return the current_node
        return current_node
      else
        current_node = parent
      end
    end

    #puts "No path found"
  end

  def smallest_f_score(list_of_coordinates, f_score)
    x_min = list_of_coordinates[0]
    f_min = f_score[x_min]

    list_of_coordinates.each {|x|
      if f_score[x] < f_min
        f_min = f_score[x]
        x_min = x
      end
    }

    return x_min
  end
end

class AIPlayer
  include AStar
  include Sprite
  include Damageable

  # Maximum distance (in blocks) that this player can see.
  attr_accessor :sight
  # This enemy must not be closer than the given number of blocks to the main character.
  attr_accessor :min_dinstance
  attr_accessor :last_seen

  def initialize
    @sight = 10
    @min_distance = 2
  end

  def interact(player)
    return if @health <= 0 or @current_status == :dead

    self.current_state = :idle if @current_state == :firing && @firing_left == 0

    start = Coordinate.new(*Map.matrixify(@x, @y))
    goal  = Coordinate.new(*Map.matrixify(player.x, player.y))

    melee = @melee_attack_damage ? melee_attack(player, start, goal) : nil
    ranged_attack(player, start, goal) if @ranged_attack_damage and !melee

    if heuristic_estimate_of_distance(start, goal) > @min_distance
      path  = self.find_path(@map, start, goal)
      if path
        self.step_to_adjacent_squarily(path.y, path.x)
      else
        if @last_seen
          if line_of_sight(@map,start,@last_seen)
            self.step_to_adjacent_squarily(@last_seen.y, @last_seen.x)
          else
            @last_seen = Coordinate.new((@last_seen.x + start.x)/2, (@last_seen.y + start.y)/2)
          end
        end
      end
    end
  end

  def ranged_attack(player, start, goal)
    los = line_of_sight(@map,start,goal)

    @last_seen = goal if los

    if los and @firing_left > 0
      self.fire(player, @ranged_attack_damage) if (@current_anim_seq_id == 0)
      @firing_left -= 1
      return true
    end
    if los and rand > 0.8
      @firing_left = 1 + rand(5)
    end
    false
  end

  def melee_attack(player, start, goal)
    if @firing_left > 0
      if (rand(4) == 0)
        self.fire(player, @melee_attack_damage)
        @firing_left -= 1
        return true
      end
    end
    h = heuristic_estimate_of_distance(start, goal)
    if h <= @min_distance and line_of_sight(@map,start,goal) and rand > 0.5
      @firing_left = 1 + rand(5)
    end
    false
  end
end

class Enemy < AIPlayer
  FIRING_SOUND_BLOCKS = 2.5

  attr_accessor :step_size
  attr_accessor :animation_interval

  def initialize(window, kind_tex_paths, map, x, y, death_sound, firing_sound, kill_score = 100, step_size = 4, animation_interval = 0.2)
    super()
    @window = window
    @x = x
    @y = y
    @slices = {}
    @health ||= 100
    @map = map
    @firing_left = 0
    @kill_score  = kill_score
    @firing_sounds = load_sounds(firing_sound)
    @death_sounds  = load_sounds(death_sound)
    @name       ||= self.class.to_s

    kind_tex_paths.each { |kind, tex_paths|
      @slices[kind] = []
      tex_paths.each { |tex_path|
        @slices[kind] << SpritePool::get(window, tex_path, TEX_HEIGHT)
      }
    }

    @step_size = step_size
    @animation_interval = animation_interval

    self.current_state = :idle
    @last_draw_time = Time.now.to_f
  end

  def take_damage_from(player, damage)
    return if @current_state == :dead
    damage = player.class == Player ? player.weapon.damage : player.damage
    @health -= damage
    if @health > 0
      self.current_state = :damaged
    else
      self.current_state = :dead
      @firing_sound_sample.stop if @firing_sound_sample
      play_random_sound(@death_sounds)
      @window.player.score += @kill_score
    end
  end

  def step_to_adjacent_squarily(target_row, target_column)
    my_column, my_row = Map.matrixify(@x, @y)
    x = my_column
    y = my_row

    if my_column == target_column || my_row == target_row
      type = "orthogonal"
      # Orthogonal
      x = target_column # * Map::GRID_WIDTH_HEIGHT
      y = target_row    # * Map::GRID_WIDTH_HEIGHT
    else
      # Diagonal
      type = "diagonal"
      x = my_column
      y = target_row

      if not @map.walkable?(y, x)
        x = target_column
        y = my_row
      end
    end

    x += 0.5
    y += 0.5

    x *= Map::GRID_WIDTH_HEIGHT
    y *= Map::GRID_WIDTH_HEIGHT

    self.step_to(x, y)
  end

  def step_to(x, y)
    return if @current_state == :dead

    if (@x == x && @y == y)
      self.current_state = :idle
      return
    end

    self.current_state = :walking if self.current_state != :walking &&
      @current_anim_seq_id + 1 == @slices[@current_state].size

    dx = x - @x
    dy = (y - @y) * -1

    angle_rad = Math::atan2(dy, dx) * -1

    @x += @step_size * Math::cos(angle_rad)
    @y += @step_size * Math::sin(angle_rad)
  end

  def current_state
    @current_state
  end

  def current_state=(state)
    @current_state       = state
    @current_anim_seq_id = 0
    if state == :idle || state == :walking || state == :firing
      @repeating_anim = true
    else
      @repeating_anim = false
    end
  end

  def slices
    # Serve up current slice
    now = Time.now.to_f

    if @current_state == :dead && @current_anim_seq_id + 1 == @slices[:dead].size && !@on_death_called
      @on_death_called = true
      on_death if respond_to?(:on_death, true)
    end

    unless ( @current_state == :dead and @current_anim_seq_id + 1 == @slices[:dead].size ) or (@current_state == :idle)
      if now >= @last_draw_time + @animation_interval
        @current_anim_seq_id += 1
        if @repeating_anim
          @current_anim_seq_id = @current_anim_seq_id % @slices[@current_state].size
        else
          if @current_anim_seq_id >= @slices[@current_state].size
            self.current_state = :idle
          end
        end

        @last_draw_time = now
      end
    end

    return @slices[@current_state][@current_anim_seq_id]
  end

  def fire(player, damage)
    return if @current_status == :dead

    if @firing_sound_sample.nil? || !@firing_sound_sample.playing?
      @firing_sound_sample = play_random_sound(@firing_sounds)
    end
    player.take_damage_from(self, damage)

    self.current_state = :firing
  end

  private

  def load_sounds(sounds)
    sounds = [sounds] if !sounds.is_a?(Array)
    sounds.map do |sound_file|
      { :file => sound_file, :sound => SoundPool.get(@window, sound_file) }
    end
  end

  def play_random_sound(sounds)
    sound = sounds[rand(sounds.size)]
    text = SOUND_TO_TEXT[sound[:file]]
    @window.show_text("#{@name}: \"#{text}\"") if text
    sound[:sound].play
  end

  def clean_name
    self.class.to_s.downcase
  end
end

class Guard < Enemy
  def initialize(window, map, x, y, death_sound = nil, firing_sound = nil, kill_score = 100, step_size = 3, animation_interval = 0.2)
    sprites = {
      :idle    => ["enemies/#{clean_name}/idle.png"],
      :walking => (1..4).map{|n| "enemies/#{clean_name}/walking#{n}.png"},
      :firing  => (1..2).map{|n| "enemies/#{clean_name}/firing#{n}.png"},
      :damaged => (1..2).map{|n| "enemies/#{clean_name}/damaged#{n}.png"},
      :dead    => (1..5).map{|n| "enemies/#{clean_name}/dead#{n}.png"},
    }

    sounds  = ['long live php.ogg', 'myphplife.ogg', 'my damn php life.ogg', 'phpforever.ogg'].map{|n| "enemies/#{clean_name}/#{n}"}
    firing_sound ||= sounds[rand(sounds.size - 1)]
    death_sound  ||= sounds[rand(sounds.size - 1)]

    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
    @health = 50
    @ranged_attack_damage = 3
  end
end

class Alien < Enemy
  def initialize(window, map, x, y, death_sound = nil, firing_sound = nil, kill_score = 100, step_size = 6, animation_interval = 0.2)
    sprites = {
      :idle    => ["enemies/#{clean_name}/idle.png"],
      :walking => (1..4).map{|n| "enemies/#{clean_name}/walking#{n}.png"},
      :firing  => (1..2).map{|n| "enemies/#{clean_name}/walking#{n}.png"},
      :damaged => (1..2).map{|n| "enemies/#{clean_name}/walking#{n}.png"},
      :dead    => (1..3).map{|n| "enemies/#{clean_name}/walking#{n}.png"},
    }

    sounds  = ['long live php.ogg', 'myphplife.ogg', 'my damn php life.ogg', 'phpforever.ogg'].map{|n| "enemies/guard/#{n}"}
    firing_sound ||= sounds[rand(sounds.size - 1)]
    death_sound  ||= sounds[rand(sounds.size - 1)]

    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
    @health = 50
    @ranged_attack_damage = 3
  end
end

class Hans < Enemy
  def initialize(window, map, x, y, death_sound = nil, firing_sound = 'machine_gun_burst.ogg', kill_score = 1000, step_size = 3, animation_interval = 0.2)
    sprites = {
      :idle    => ['hans1.bmp'],
      :walking => ['hans1.bmp', 'hans2.bmp', 'hans3.bmp', 'hans4.bmp'],
      :firing  => ['hans5.bmp', 'hans6.bmp', 'hans7.bmp'],
      :damaged => ['hans8.bmp', 'hans9.bmp'],
      :dead    => ['hans9.bmp', 'hans10.bmp', 'hans11.bmp']
    }

    # Special thanks goes out to Julian Raschke (jlnr on #gosu@irc.freenode.net ) of libgosu.org for recording these samples for us.
    death_sounds  = ['mein_spagetthicode.ogg', 'meine_magischen_qpc.ogg', 'meine_sql.ogg', 'meine_sql.ogg']
    death_sound ||= death_sounds[rand(death_sounds.size - 1)]
    @ranged_attack_damage = 5

    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
  end
end

class Dog < Enemy
  def initialize(window, map, x, y, death_sound = 'enemies/dog/dog_cry.ogg', firing_sound = 'enemies/dog/dog_bark.ogg', kill_score = 500, step_size = 7, animation_interval = 0.2)
    sprites = {
      :idle    => ["enemies/#{clean_name}/walking1.png"],
      :walking => (1..4).map{|n| "enemies/#{clean_name}/walking#{n}.png"},
      :firing  => (1..3).map{|n| "enemies/#{clean_name}/firing#{n}.png"},
      :damaged => (1..2).map{|n| "enemies/#{clean_name}/dead#{n}.png"},
      :dead    => (1..4).map{|n| "enemies/#{clean_name}/dead#{n}.png"},
    }

    @name = "Mongrel"
    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
    @health = 100
    @melee_attack_damage = 4
    @min_distance = 1
  end
end

class Creeper < Enemy
  def initialize(window, map, x, y, death_sound = 'enemies/dog/dog_cry.ogg', firing_sound = 'enemies/dog/dog_bark.ogg', kill_score = 500, step_size = 7, animation_interval = 0.2)
    sprites = {
      :idle    => ["enemies/#{clean_name}/walking1.png"],
      :walking => (1..4).map{|n| "enemies/#{clean_name}/walking#{n}.png"},
      :exploding => (1..5).map{|n| "enemies/#{clean_name}/exploding#{n}.png"},
      :damaged => (1..2).map{|n| "enemies/#{clean_name}/damaged#{n}.png"},
      :dead    => (1..4).map{|n| "enemies/#{clean_name}/dead#{n}.png"},
    }

    @name = "Creeper"
    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
    @health = 1000
    @melee_attack_damage = 4
    @min_distance = 1
  end

  def interact(player)
    if @current_state == :exploding and @current_anim_seq_id == @slices[:exploding].count-1
      @map.players.delete(self)
    else
      super(player)
    end
  end

  def fire(player, damage)
    unless @current_state == :exploding
      player.take_damage_from(self, damage)
      self.current_state = :exploding
    end
  end
  def melee_attack(player, start, goal)
    if @firing_left > 0
      self.fire(player, @melee_attack_damage)
      return true
    end
    h = heuristic_estimate_of_distance(start, goal)
    if h <= @min_distance and line_of_sight(@map,start,goal) and rand > 0.5
      @firing_left = 1 + rand(5)
    end
    false
  end
end
