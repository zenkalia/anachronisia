require './map'
require './sprite'
require './sound'

class Missile
  include Sprite
  include Directable
  attr_accessor :angle
  attr_accessor :damage
  attr_accessor :speed
  attr_accessor :owner
  attr_accessor :dead
  TEX_WIDTH  = 64
  TEX_HEIGHT = 64

  def initialize(window, map, x, y)
    @window = window
    @map = map
    @x = x
    @y = y
    @angle = 0
    @slices = (1..8).map{|n| SpritePool::get(window, "missiles/#{clean_name}/#{n}.png", TEX_HEIGHT)}
    @dead_slices = (1..6).map{|n| SpritePool::get(window, "missiles/#{clean_name}/death#{n}.png", TEX_HEIGHT)}
    @last_draw_time = Time.now.to_f
    @dead = false
    @damage = 40
    @owner = nil
  end

  def clean_name
    self.class.to_s.downcase
  end

  def slices
    if @dead
      @map.missiles.delete(self) if @dead >= @dead_slices.count-1
      return @dead_slices[@dead] || @dead_slices.last
    end
    pa = @window.player.angle
    a = @angle
    @slices[((a+180+pa+22.5)%360/45).to_i]
  end

  def step_size
    1
  end

  def interact(player)
    if !@dead and (y-player.y).abs <= 60 and (x-player.x).abs <= 60 and @owner != player
      @dead = 0
      player.take_damage_from(self, @damage)
    end
    if @dead
      @dead += 1
    else
      @map.players.each do |p|
        if (y-p.y).abs <= 60 and (x-p.x).abs <= 60 and @owner != p
          @dead = 0
          p.take_damage_from(self, @damage)
        end
      end
      @dead = 0 unless move_exact(dx,dy, @map)
    end
  end
end

class Rocket < Missile
  def initialize(window, map, x, y, owner = nil)
    super(window, map, x, y)
    @damage = 80
    @owner = owner
  end
end
