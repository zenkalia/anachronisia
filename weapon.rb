class Weapon
  attr_accessor :name, :damage, :idle_sprite, :fire_sprite, :wait

  def initialize(window)
    @wait = 0
  end

  def can_fire?
    @wait == 0
  end

  def fire
    @wait = @cooldown
  end
end

class PowerOfCode < Weapon
  def initialize(window)
    super
    @name = 'Ruby'
    @internal_name = 'hand'
    @damage = 5
    @idle_sprite = Gosu::Image::new(window, "weapons/#{@internal_name}/idle.png", true)
    @fire_sprite = Gosu::Image::new(window, "weapons/#{@internal_name}/firing.png", true)
    @cooldown = 0
  end
end

class Pistol < Weapon
  def initialize(window)
    super
    @name = 'COD4'
    @internal_name = 'gun'
    @damage = 10
    @idle_sprite = Gosu::Image::new(window, "weapons/#{@internal_name}/idle.png", true)
    @fire_sprite = Gosu::Image::new(window, "weapons/#{@internal_name}/firing.png", true)
    @cooldown = 3
  end
end
