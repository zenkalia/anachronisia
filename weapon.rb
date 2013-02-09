class Weapon
  attr_accessor :name, :damage, :idle_sprite, :fire_sprite
end

class PowerOfCode < Weapon
  def initialize(window)
    @name = 'Ruby'
    @internal_name = 'hand'
    @damage = 5
    @idle_sprite = Gosu::Image::new(window, "weapons/#{@internal_name}/idle.png", true)
    @fire_sprite = Gosu::Image::new(window, "weapons/#{@internal_name}/firing.png", true)
  end
end

class Pistol < Weapon
  def initialize(window)
    @name = 'COD4'
    @internal_name = 'gun'
    @damage = 10
    @idle_sprite = Gosu::Image::new(window, "weapons/#{@internal_name}/idle.png", true)
    @fire_sprite = Gosu::Image::new(window, "weapons/#{@internal_name}/firing.png", true)
  end
end
