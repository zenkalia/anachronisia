class Generator
  def self.make_map
    @map = Array.new(64) { Array.new(64, 1) }
    rooms = []
    doors = []
    rooms << [32,32,4,4] if make_rect_room(32,32,4,4)

    5000.times do
      add_to_room = rooms.sample
      height = rand(10)+3
      width = rand(10)+3
      t = door_for(add_to_room)
      next unless t
      direction, door = t
      x=y=0

      case(direction)
      when :right
        x = door[0] + 1
        y = door[1] - rand(height)
      when :bot
        x = door[0] - rand(width)
        y = door[1] + 1
      when :top
        x = door[0] - rand(width)
        y = door[1] - height - 1
      when :left
        x = door[0] - width - 1
        y = door[1] - rand(height)
      end

      if make_rect_room(x,y,width,height)
        rooms << [x,y,width,height]
        doors << door
        @map[door[1]][door[0]] = -1
        if @map[door[1]-1][door[0]] == 1 and @map[door[1]+1][door[0]] == 1
          @map[door[1]-1][door[0]] = 2
          @map[door[1]+1][door[0]] = 2
        else
          @map[door[1]][door[0]-1] = 3
          @map[door[1]][door[0]+1] = 3
        end
      end
    end
    dump
    @map
  end

  def self.make_bsp(n = 3)
    @map = Array.new(64) { Array.new(64, 1) }
    a = BSP.new(0,0,63,63)
    a.split(n)

    def self.make_bsp_rooms(bsp)
      return unless bsp
      make_rect_room(bsp.x+2, bsp.y+2, bsp.dx-4, bsp.dy-4) unless bsp.a
      make_bsp_rooms(bsp.a)
      make_bsp_rooms(bsp.b)
    end
    make_bsp_rooms(a)
    dump
    @map
  end

  def self.dump(name='lol.csv')
    require 'csv'
    CSV.open(name, 'wb') { |csv| @map.each { |r| csv << r } }
  end

  def self.make_rect_room(start_x, start_y,dx,dy)
    return false if start_x+1 > 62 or start_x < 1
    return false if start_y+1 > 62 or start_y < 1
    return false if start_x+dx+1 > 62 or start_x+dx < 1
    return false if start_y+dy+1 > 62 or start_y+dy < 1
    for x in ((start_x-1)..(start_x+dx+1))
      for y in ((start_y-1)..(start_y+dy+1))
        return false if @map[y][x] == 0
      end
    end
    for x in (start_x..(start_x+dx))
      for y in (start_y..(start_y+dy))
        @map[y][x] = 0
      end
    end
  end

  def self.door_for(room)
    sides = [:top, :bot, :left, :right]

    x = y = 0
    side = sides.sample

    case side
    when :left
      x = room[0]-1
      y = room[1]+1+rand(room[3])
    when :right
      x = room[0]+1+room[2]
      y = room[1]+1+rand(room[3])
    when :bot
      x = room[0]+1+rand(room[2])
      y = room[1]+1+room[3]
    when :top
      x = room[0]+1+rand(room[2])
      y = room[1]-1
    end
    return false if @map[y][x+1] == -1 or @map[y][x-1] == -1 or @map [y-1][x] == -1 or @map[y+1][x] == -1
    [side, [x,y]]
  end
end

class BSP
  attr_accessor :x
  attr_accessor :y
  attr_accessor :dx
  attr_accessor :dy
  attr_accessor :a
  attr_accessor :b
  attr_accessor :dad
  attr_accessor :split_type
  def initialize (x,y,dx,dy,dad=nil)
    @x = x
    @y = y
    @dx = dx
    @dy = dy
    @dad = dad
  end

  def split(n=1)
    return if n == 0 or dx <= 4 or dy <= 4
    if @dad and @dad.split_type = :horiz
      self.split_vert
    else
      self.split_horiz
    end
    a.split(n-1)
    b.split(n-1)
  end

  def split_horiz
    y = rand(@dy)
    @a = self.class.new(@x,@y,@dx,y,self)
    @b = self.class.new(@x,@y+y,@dx,@dy-y,self)
    @split_type = :horiz
  end

  def split_vert
    x = rand(@dx)
    @a = self.class.new(@x,@y,x,@dy,self)
    @b = self.class.new(@x+x,@y,@dx-x,@dy,self)
    @split_type = :vert
  end
end
