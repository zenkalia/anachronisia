require './config'
require './sprite'
require './door'

class Map
  Infinity = 1.0 / 0
  TEX_WIDTH  = 64
  TEX_HEIGHT = 64
  GRID_WIDTH_HEIGHT = 64
  HALF_GRID_WIDTH_HEIGHT = GRID_WIDTH_HEIGHT / 2
  MIN_HALF_GRID_WIDTH_HEIGHT = -HALF_GRID_WIDTH_HEIGHT

  attr_accessor :matrix
  attr_reader   :window
  attr_reader   :textures
  attr_accessor :props
  attr_accessor :players
  attr_accessor :items
  attr_accessor :missles
  #attr_accessor :sprites
  attr_accessor :doors
  attr_reader   :width
  attr_reader   :height

  attr_reader :player_x_init
  attr_reader :player_y_init
  attr_reader :player_angle_init

  class Adder
    def initialize(map)
      @map = map
    end

    def prop(klass, x, y, *args, &block)
      prop = klass.new(@map.window, x * GRID_WIDTH_HEIGHT, y * GRID_WIDTH_HEIGHT, *args, &block)
      @map.props << prop
      prop
    end

    def item(klass, x, y, *args, &block)
      item = klass.new(@map.window, @map, x * GRID_WIDTH_HEIGHT, y * GRID_WIDTH_HEIGHT, *args, &block)
      @map.items << item
      item
    end

    def player(klass, x, y, *args, &block)
      player = klass.new(@map.window, @map, x * GRID_WIDTH_HEIGHT, y * GRID_WIDTH_HEIGHT, *args, &block)
      @map.players << player
      player
    end

    def missle(klass, x, y, *args, &block)
      missle = klass.new(@map.window, @map, x * GRID_WIDTH_HEIGHT, y * GRID_WIDTH_HEIGHT, *args, &block)
      @map.missles << missle
      missle
    end
  end

  # @require for i in 0...matrix_row_column.size:
  #   matrix_row_column[i].size == matrix_row_column[i+1].size
  def initialize(matrix_row_column, texture_files, player_x_init, player_y_init, player_angle_init, window)
    @matrix = matrix_row_column
    @width  = matrix_row_column[0].size
    @height = matrix_row_column.size

    @player_x_init     = player_x_init
    @player_y_init     = player_y_init
    @player_angle_init = player_angle_init

    @window = window
    @doors  = []

    @height.times do
      column = [nil] * @width
      @doors << column
    end

    row = 0
    while(row < @height)
      col = 0
      while(col < @width)
        if @matrix[row][col] == -1
          @doors[row][col] = Door.new
        end
        col += 1
      end
      row += 1
    end

    @textures = [nil]
    texture_files.each {|tex_file|
      pair = {}

      tex_file.each_pair {|tex_type, tex_path|
        pair[tex_type] = SpritePool::get(window, tex_path)
      }

      @textures << pair
    }
    @items   = []
    @players = []
    @props   = []
    @missles = []
  end

  def add
    yield(Adder.new(self))
  end

  def sprites
    @items + @players + @props + @missles #it could be interesting to spawn the map with some missles floating around...
  end

  def find_nearest_intersection(start_x, start_y, angle)
    hor_x, hor_y = find_horizontal_intersection(start_x, start_y, angle)
    ver_x, ver_y = find_vertical_intersection(start_x, start_y, angle)

    hor_r = Math.sqrt( (hor_x - start_x) ** 2 + (hor_y - start_y) ** 2 )
    ver_r = Math.sqrt( (ver_x - start_x) ** 2 + (ver_y - start_y) ** 2 )

    if hor_r < ver_r
      return :horizontal, hor_r, hor_x, hor_y
    else
      return :vertical, ver_r, ver_x, ver_y
    end
  end

  def find_horizontal_intersection(start_x, start_y, angle)
    # When the angle is horizontal, we will never find a horizontal intersection.
    # After all, the ray would then be considered parallel to any possible horizontal wall.
    return Infinity, Infinity if angle == 0 || angle == 180

    grid_y = (start_y / GRID_WIDTH_HEIGHT).to_i

    if(angle > 0 && angle < 180)
      # Ray facing upwards
      ay = (grid_y * GRID_WIDTH_HEIGHT) - 1
      #ay = 0 if ay < 0
    else
      # Ray facing downwards
      ay = ( grid_y + 1 ) * GRID_WIDTH_HEIGHT
      #ay = grid_y * GRID_WIDTH_HEIGHT if not on_map?(*Map.matrixify(ay, start_x))
    end

    ax = start_x + (start_y - ay) / Math.tan(angle * Math::PI / 180)

    #if not on_map?(*Map.matrixify(ay, ax))
    #  [Infinity, Infinity]
    #end

    #if(ax < 0 || ax >= RbConfig::WINDOW_WIDTH || ay < 0 || ay >= RbConfig::WINDOW_HEIGHT)
    #  [Infinity, Infinity]
    #end

    if(!hit?(ax, ay, angle, :horizontal))
      # Extend the ray
      return find_horizontal_intersection(ax, ay, angle)
    else

      column, row = Map.matrixify(ax, ay)

      if door?(row, column)
        half_grid = GRID_WIDTH_HEIGHT / 2
        dy = (angle > 0 && angle < 180) ? half_grid * -1 : half_grid

        door_offset = half_grid / Math::tan(angle * Math::PI / 180).abs
        door_offset *= -1 if angle > 90 && angle < 270

        return ax + door_offset, ay + dy
      else
        return ax, ay
      end
    end
  end

  def find_vertical_intersection(start_x, start_y, angle)
    if angle == 90 || angle == 270
      [Infinity, Infinity]
    else
      grid_x = (start_x / GRID_WIDTH_HEIGHT).to_i

      if(angle > 90 && angle < 270)
        # Ray facing left
        bx = (grid_x * GRID_WIDTH_HEIGHT) - 1
      else
        # Ray facing right
        bx = (grid_x + 1) * GRID_WIDTH_HEIGHT
      end

      by = start_y + (start_x - bx) * Math.tan(angle * Math::PI / 180)

      # If the casted ray gets out of the playfield, emit infinity.
      #if(bx < 0 || bx >= RbConfig::WINDOW_WIDTH || by < 0 || by >= RbConfig::WINDOW_HEIGHT)
      #  [Infinity, Infinity]
      #else

      #if not on_map?(*Map.matrixify(by, bx))
      #  [Infinity, Infinity]
      #end

        if(!hit?(bx, by, angle, :vertical))
          #Extend the ray
          find_vertical_intersection(bx, by, angle)
        else
          column, row = Map.matrixify(bx,by)

          if door?(row, column)
            dx = (angle > 90 && angle < 270) ? MIN_HALF_GRID_WIDTH_HEIGHT : HALF_GRID_WIDTH_HEIGHT

            door_offset = HALF_GRID_WIDTH_HEIGHT * Math::tan(angle * Math::PI / 180).abs
            door_offset *= -1 if angle > 0 && angle < 180

            [bx + dx, by + door_offset]
          else
            [bx, by]
          end
        end
      #end
    end
  end

  def texture_for(type, x, y, angle)
    column = (x / GRID_WIDTH_HEIGHT).to_i
    row    = (y / GRID_WIDTH_HEIGHT).to_i

    texture_id = @matrix[row][column]
    texture    = @textures[texture_id]

    if type == :horizontal && angle > 0 && angle < 180
      if door?(row, column)
        texture[:south][(x - @doors[row][column].pos) % TEX_WIDTH]
      else
        if texture_id == 0
          #puts "#{type} -- #{x} -- #{y} -- #{angle}"
          return @textures[-1][:south][x % TEX_WIDTH]
        end
        texture[:south][x % TEX_WIDTH]
      end
    elsif type == :horizontal && angle > 180
      if door?(row, column)
        texture[:north][(x - @doors[row][column].pos) % TEX_WIDTH]
      else
        if texture_id == 0
          #puts "North: #{type} -- #{x} -- #{y} -- #{angle}"
          return @textures[-1][:north][x % TEX_WIDTH]
        end

        texture[:north][(TEX_WIDTH - x) % TEX_WIDTH]
      end
    elsif type == :vertical && angle > 90 && angle < 270
      if door?(row, column)
        texture[:west][(y - @doors[row][column].pos) % TEX_HEIGHT]
      else
        if texture_id == 0
          #puts "North: #{type} -- #{x} -- #{y} -- #{angle}"
          return @textures[-1][:north][y % TEX_WIDTH]
        end

        texture[:west][(TEX_HEIGHT - y) % TEX_HEIGHT]
      end
    elsif type == :vertical && angle < 90 || angle > 270
      if door?(row, column)
        texture[:east][(y - @doors[row][column].pos) % TEX_HEIGHT]
      else
        if texture_id == 0
          #puts "East: #{type} -- #{x} -- #{y} -- #{angle}"
          return @textures[-1][:east][y % TEX_WIDTH]
        end

        texture[:east][y % TEX_HEIGHT]
      end
    end
  end

  def walkable?(row, column)
    on_map?(row, column) && (@matrix[row][column] == 0 || (door?(row, column) && @doors[row][column].open?))
  end

  def hit?(x, y, angle = nil, type = nil)
    column, row = Map.matrixify(x,y)

    if(angle && (type == :horizontal || type == :vertical) && door?(row, column))
      offset = (type == :horizontal) ? x : y
      offset_door = 0

      dx = (angle > 90 && angle < 270) ? MIN_HALF_GRID_WIDTH_HEIGHT : HALF_GRID_WIDTH_HEIGHT

      if type == :vertical
        offset_door = dx * Math::tan(angle * Math::PI / 180) * -1
      else
        offset_door = dx / Math::tan(angle * Math::PI / 180).abs
      end

      offset_on_door = offset + offset_door
      offset_on_door %= GRID_WIDTH_HEIGHT

      if type == :horizontal
        @doors[row][column].pos <= offset_on_door
      elsif type == :vertical
        @doors[row][column].pos <= offset_on_door
      else
        !self.walkable?(row, column)
      end
    else
      !self.walkable?(row, column)
    end
  end

  def door?(row, column)
    on_map?(row, column) && @matrix[row][column] == -1
  end

  def get_door(row, column, angle)
    if door?(row + 1, column) && (angle > (270 - Player::HALF_FOV)) && (angle < (270 + Player::HALF_FOV))
      return @doors[row + 1][column]
    elsif door?(row - 1, column) && (angle > (90 - Player::HALF_FOV)) && (angle < (90 + Player::HALF_FOV))
      return @doors[row - 1][column]
    elsif door?(row, column + 1) && ( (angle > (360 - Player::HALF_FOV)) || (angle < Player::HALF_FOV) )
      return @doors[row][column + 1]
    elsif door?(row, column - 1) && (angle > (180 - Player::HALF_FOV)) && (angle < (180 + Player::HALF_FOV))
      return @doors[row][column - 1]
    end

    return nil
  end

  def on_map?(row, column)
    if row < 0 or column < 0
      false
    else
      row < self.width && column < self.height
    end
  end

  def self.matrixify(x, y)
    [(x / GRID_WIDTH_HEIGHT).to_i, (y / GRID_WIDTH_HEIGHT).to_i]
  end
end



class MapPool
  @@maps = []

  def self.get(window, n = 0)
    n = n.to_i
    if @@maps[n].nil?
      klass = eval("Level#{n}")

      @@maps[n] = klass.create(window)
    end

    @@maps[n]
  end
end
