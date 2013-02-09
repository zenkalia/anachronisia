require './map'
require './sprite'
require './sound'

class Missle
  include Sprite
  include Directable
  attr_accessor :angle
  attr_accessor :damage
  attr_accessor :speed
  TEX_WIDTH  = 64
  TEX_HEIGHT = 64

  def initialize(window, map, x, y)
    @window = window
    @map = map
    @x = x
    @y = y
    @angle = 0
    @slices = (1..8).map{|n| SpritePool::get(window, "missles/#{clean_name}/#{n}.png", TEX_HEIGHT)}
    @dead_slices = (1..6).map{|n| SpritePool::get(window, "missles/#{clean_name}/death#{n}.png", TEX_HEIGHT)}
    @last_draw_time = Time.now.to_f
    @dead = false
  end

  def clean_name
    self.class.to_s.downcase
  end

  def slices
    if @dead
      @map.missles.delete(self) if @dead == @dead_slices.count-1
      return @dead_slices[@dead]
    end
    pa = @window.player.angle
    a = @angle
    @slices[((a+180+pa+22.5)%360/45).to_i]
  end

  def step_size
    1
  end

  def interact(player)
    if @dead
      @dead += 1
    else
      @dead = 0 unless move_exact(dx,dy, @map)
    end
  end
end

class Rocket < Missle
end
