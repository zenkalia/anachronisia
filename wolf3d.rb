#!/usr/bin/env ruby
require 'rubygems'
require 'gosu'
require 'rbconfig'

require './config'
require './mixins'
require './gamepad'
require './map'
require './sound'
require './weapon'
require './player'
require './ai_player'
require './sprite'
require './door'
require './image_pool'
require './missile'

require './level'

module ZOrder
  CEIL = 0
  FLOOR = 1
  LEVEL      = 2
  SPRITES    = 3
  WEAPON     = 9999
  HUD        = 10000
  SCREEN_FLASH    = HUD + 3
  TEXT_BACKGROUND = HUD + 4
  TEXT            = HUD + 5
  FADE_OUT_OVERLAY = HUD + 6
end

class GameWindow < Gosu::Window
  Infinity = 1.0 / 0
  SCREEN_FLASH_MAX_ALPHA = 100
  SCREEN_FLASH_STEP      = 5
  POWERDOWN_SCREEN_FLASH_COLOR = Gosu::Color.new(SCREEN_FLASH_MAX_ALPHA, 255, 0, 0)
  POWERUP_SCREEN_FLASH_COLOR   = Gosu::Color.new(SCREEN_FLASH_MAX_ALPHA, 141, 198, 63)
  TEXT_BACKGROUND_COLOR        = Gosu::Color.new(160, 0, 0, 0)
  TEXT_BACKGROUND_PADDING      = 6
  TEXT_VERTICAL_SPACING        = 1
  MIN_TEXT_APPEARENCE_TIME     = 3
  FADE_OUT_OVERLAY_COLOR       = Gosu::Color.new(0, 0, 0, 0)
  BOSS_PRESENTATION_BACKGROUND_COLOR = Gosu::Color.new(255, 0, 61, 204)
  BOSS_PRESENTATION_CYAN_LINE_COLOR  = Gosu::Color.new(255, 0, 186, 251)
  BOSS_PRESENTATION_WHITE_LINE_COLOR = Gosu::Color.new(255, 255, 255, 255)
  BOSS_PRESENTATION_TITLE_FONT = "Myriad Pro"
  BOSS_PRESENTATION_TITLE_FONT_SIZE = 35
  BOSS_PRESENTATION_FONT       = "Myriad Pro"
  BOSS_PRESENTATION_FONT_SIZE  = 45

  TOP  = 0
  LEFT = 0
  RIGHT = RbConfig::WINDOW_WIDTH - 1
  BOTTOM = RbConfig::WINDOW_HEIGHT - 1

  attr_accessor :player
  attr_accessor :map

  def initialize(config = {})
    super(RbConfig::WINDOW_WIDTH, RbConfig::WINDOW_HEIGHT, config[:fullscreen])
    self.caption = 'Rubystein 3d by Phusion CS Company'

    @controls = Gamepad::Win
    @controls = Gamepad::Mac if RbConfig::CONFIG['host_os'] =~ /mac|darwin/

    @map = MapPool.get(self, 0)

    @player = Player.new(self)
    @player.x = @map.player_x_init
    @player.y = @map.player_y_init
    @player.angle = @map.player_angle_init

    @wall_perp_distances   = [0]   #* RbConfig::WINDOW_WIDTH
    @drawn_sprite_x        = [nil] #* RbConfig::WINDOW_WIDTH

    @hud = Gosu::Image::new(self, 'hud.png', true)
    @hud_numbers = SpritePool.get(self, 'numbers.png', 32, 16)
    @floor  = Gosu::Image::new(self, 'floor.png', true)
    @ceil  = Gosu::Image::new(self, 'ceil.png', true)
    self.background_song = nil  # Play default background song.
    @fire_sound = Gosu::Sample.new(self, 'fire.ogg')
    @door_open_sound = Gosu::Sample.new(self, 'dooropen.ogg')
    @door_close_sound = Gosu::Sample.new(self, 'doorclose.ogg')

    # Screenflashing counters
    @powerup_screen_flash   = 0
    @powerdown_screen_flash = 0

    @hud_portret = SpritePool::get(self, 'sean_connery.png', 60, 60)

    @mode = :normal

    @ai_schedule_index = 0
    @last_row = nil
    @last_col = nil
  end

  def background_song=(filename)
    @bg_song.stop if @bg_song
    @bg_song = Gosu::Song.new(self, filename || 'getthem.ogg')
    @bg_song.volume = 0.25
    @bg_song.play(true)
  end

  def update
    case @mode
    when :normal, :fading_out
      update_fade_out_progress
      old_player_health = @player.health
      if @mode != :fading_out
        process_movement_input
        invoke_players
        invoke_items
        invoke_missiles
        invoke_doors
        invoke_weapon
      end
      determine_screen_flash(old_player_health)

      row, col = Map.matrixify(@player.y, @player.x)
      if @last_row != row || @last_col != col
        #puts "#{col},#{row}"
        @last_row = row
        @last_col = col
      end

      @player.update
    else
      abort "Invalid mode '#{@mode}'"
    end
  end

  def draw
    case @mode
    when :normal, :fading_out
      draw_scene
      draw_sprites
      draw_weapon
      draw_hud
      draw_screen_flash
      draw_text
      draw_fade_out_overlay

    else
      abort "Invalid mode '#{@mode}'"
    end
  end

  def show_text(text)
    @active_text = text
    @active_text_timeout = 0.6 + (text.size * 0.15)
    @active_text_timeout = MIN_TEXT_APPEARENCE_TIME if @active_text_timeout < MIN_TEXT_APPEARENCE_TIME
    @active_text_timeout = Time.now + @active_text_timeout
  end

  def fade_out(&when_done)
    @mode = :fading_out
    @fade_out = {
      :start_time => Time.now,
      :duration   => 1,
      :progress   => 0,
      :alpha      => 0,
      :when_done  => when_done
    }
  end

  private

  def determine_screen_flash(old_health)
    if old_health < @player.health
      # Power-up
      @powerup_screen_flash   = 100
      @powerdown_screen_flash = 0
    elsif old_health > @player.health
      # Power-down
      @powerdown_screen_flash = 100
      @powerup_screen_flash   = 0
    end
  end

  def update_fade_out_progress
    if @fade_out
      @fade_out[:progress] = (Time.now - @fade_out[:start_time]) / @fade_out[:duration]
      @fade_out[:alpha] = (255.0 * @fade_out[:progress]).to_i
      if @fade_out[:progress] > 1
        @mode == :normal
        when_done = @fade_out[:when_done]
        @fade_out = nil
        when_done.call
      end
    end
  end

  def invoke_weapon
    return unless @player.weapon.kind_of? Weapon
    @player.weapon.wait -= 1 if @player.weapon.wait > 0
  end

  # Invoke AI players' AI. Maximum of AI_INVOCATIONS_PER_LOOP AI invocations per call.
  def invoke_players
    if @ai_schedule_index > @map.players.size - 1
      @ai_schedule_index = 0
    end

    if !@map.players.empty?
      if @map.players.size > RbConfig::AI_INVOCATIONS_PER_LOOP
        max_num_invoked = RbConfig::AI_INVOCATIONS_PER_LOOP
      else
        max_num_invoked = @map.players.size
      end
      num_invoked = 0
      i = 0
      real_index_of_last_invoked_ai_player = 0

      while i < @map.players.size && num_invoked < max_num_invoked
        real_index = (@ai_schedule_index + i) % @map.players.size
        ai_player = @map.players[real_index]

        dx = @player.x - ai_player.x
        dy = @player.y - ai_player.y

        # Only invoke the AI if the player is sufficiently close to the
        # main character.
        square_distance_to_main_character = dx * dx + dy * dy

        if square_distance_to_main_character < (ai_player.sight * Map::GRID_WIDTH_HEIGHT) ** 2
          ai_player.interact(@player)
          real_index_of_last_invoked_ai_player = real_index
          num_invoked += 1
        end

        i += 1
      end

      @ai_schedule_index = (real_index_of_last_invoked_ai_player + 1) % @map.players.size
    end
  end

  def invoke_items
    @map.items.each { |item|
      item.interact(@player)
    }
  end

  def invoke_missiles
    @map.missiles.each do |m|
      m.interact(@player)
    end
  end

  def invoke_doors
    current_time = Time.now.to_i

    @map.doors.each_with_index { |doors_row, doors_row_index|
      doors_row.each_with_index { |door, doors_column_index|
        if not door.nil?
          door.interact

          row, column = Map.matrixify(@player.y, @player.x)

          d_row    = row - doors_row_index
          d_column = column - doors_column_index
          r_2 = (d_row * d_row) + (d_column * d_column)
          r_2 = (Door::FULL_VOLUME_WITHIN_GRID_BLOCKS * Door::FULL_VOLUME_WITHIN_GRID_BLOCKS) if r_2 == 0

          door_close_sound_volume = (Door::FULL_VOLUME_WITHIN_GRID_BLOCKS * Door::FULL_VOLUME_WITHIN_GRID_BLOCKS) / r_2
          door_close_sound_volume = 1.0 if door_close_sound_volume > 1.0

          if door.open? && !door.obstructed?(@map, @player) && (current_time - door.opened_at) >= Door::STAYS_SECONDS_OPEN
            @door_close_sound.play(door_close_sound_volume) if door_close_sound_volume > 0
            door.close!
          end
        end
      }
    }
  end

  def process_movement_input
    @player.turn_left  if button_down? Gosu::KbJ or button_down? @controls::LEFT
    @player.turn_right if button_down? Gosu::KbL or button_down? @controls::RIGHT
    @player.move_forward(@map)  if button_down? Gosu::KbI or button_down? @controls::UP
    @player.move_backward(@map) if button_down? Gosu::KbK or button_down? @controls::DOWN
    @player.move_left(@map) if button_down? Gosu::KbU or button_down? @controls::L
    @player.move_right(@map) if button_down? Gosu::KbO or button_down? @controls::R

    #if (button_down? Gosu::KbC or button_down? Gosu::GpButton14) and @player.jumping == false
      #@player.jumping = :up
      #@player.crouching = false
    #end
    #if (button_down? Gosu::KbX or button_down? Gosu::GpButton12) and @player.jumping == false
      #@player.crouching = :down if @player.crouching == false or @player.crouching == nil
      #@player.crouching = :up if @player.crouching == true
    #end

    if button_down? Gosu::Kb8
      @map.add do |add|
        r = add.missile(Rocket, @player.x / Map::GRID_WIDTH_HEIGHT, @player.y / Map::GRID_WIDTH_HEIGHT)
        r.angle = -@player.angle
        r.owner = @player
      end
    end

    if button_down? Gosu::KbSpace or button_down? @controls::B
      column, row = Map.matrixify(@player.x, @player.y)
      door = @map.get_door(row, column, @player.angle)

      unless door.nil?
        if door.open?
          @door_close_sound.play
          door.close!
        elsif door.closed?
          @door_open_sound.play
          door.open!
        end
        return
      end
    end

    if button_down? Gosu::KbD or button_down? @controls::X and @player.weapon.can_fire?
      sprite_in_crosshair = @drawn_sprite_x[RbConfig::WINDOW_WIDTH/2]

      if sprite_in_crosshair && sprite_in_crosshair.respond_to?(:take_damage_from) && sprite_in_crosshair.respond_to?(:dead?) && !sprite_in_crosshair.dead?
        sprite_in_crosshair.take_damage_from(@player, @player.weapon.damage)
      end

      @fired_weapon = true
      @player.weapon.fire
    else
      @fired_weapon = false
    end
  end

  def button_down(id)
    @player.prev_item if id ==  Gosu::Kb1 or id == @controls::SELECT
    @player.next_item if id == Gosu::Kb2 or id == @controls::START
    if id == Gosu::KbEscape
      @bg_song.stop if @bg_song
      close
    end
    if id == Gosu::KbS or id == @controls::A
      @player.running = true
    end
  end

  def button_up(id)
    if id == Gosu::KbS or id == @controls::A
      @player.running = false
    end
  end

  def draw_sprites
    @drawn_sprite_x.clear
    #@sprite_in_crosshair = nil

    @map.sprites.each { |sprite|
      dx = (sprite.x - @player.x)
      # Correct the angle by mirroring it in x. This is necessary seeing as our grid system increases in y when we "go down"
      dy = (sprite.y - @player.y) * -1

      distance = Math.sqrt( dx ** 2 + dy ** 2 )

      sprite_angle = (Math::atan2(dy, dx) * 180 / Math::PI) - @player.angle
      # Correct the angle by mirroring it in x. This is necessary seeing as our grid system increases in y when we "go down"
      sprite_angle *= -1

      perp_distance = ( distance * Math.cos( sprite_angle * Math::PI / 180 ))#.abs
      next if perp_distance <= 0 # Behind us... no point in drawing this.

      sprite.z_order = ZOrder::SPRITES + ( 1 / (perp_distance / Map::GRID_WIDTH_HEIGHT))
      sprite_pixel_factor = ( Player::DISTANCE_TO_PROJECTION / perp_distance )
      sprite_size = sprite_pixel_factor * Sprite::TEX_WIDTH

      x = ( Math.tan(sprite_angle * Math::PI / 180) * Player::DISTANCE_TO_PROJECTION + (RbConfig::WINDOW_WIDTH - sprite_size) / 2).to_i
      next if x + sprite_size.to_i < 0 or x >= RbConfig::WINDOW_WIDTH # Out of our screen resolution

      y = (RbConfig::WINDOW_HEIGHT - sprite_size) * (1-@player.height)

      i = 0
      slices = sprite.slices

      while(i < Sprite::TEX_WIDTH && (i * sprite_pixel_factor) < sprite_size)
        slice = x + i * sprite_pixel_factor
        slice_idx = slice.to_i

        if slice >= 0 && slice < RbConfig::WINDOW_WIDTH && perp_distance < @wall_perp_distances[slice_idx]
          slices[i].draw(slice, y, sprite.z_order, sprite_pixel_factor, sprite_pixel_factor, 0xffffffff)
          drawn_slice_idx = slice_idx

          if sprite.respond_to?(:dead?) && !sprite.dead?
            old_sprite = @drawn_sprite_x[drawn_slice_idx]
            old_sprite_is_alive_and_in_front_of_sprite = old_sprite && old_sprite.z_order > sprite.z_order && old_sprite.respond_to?(:dead?) && !old_sprite.dead?

            if not old_sprite_is_alive_and_in_front_of_sprite
              while(drawn_slice_idx < (slice + sprite_pixel_factor))
                # Fill up all the @drawn_sprite_x buffer with current sprite till the next sprite_pixel_factor
                @drawn_sprite_x[drawn_slice_idx] = sprite
                drawn_slice_idx += 1
              end
            end
          end
        end

        i += 1
      end
    }

  end

  def draw_scene
    @ceil.draw(0, 0, ZOrder::CEIL)
    @floor.draw(0, (1-@player.height)*RbConfig::WINDOW_HEIGHT, ZOrder::FLOOR)

    # Raytracing logics
    ray_angle         = (@player.angle + (Player::FOV / 2)) % 360
    ray_angle_delta   = Player::RAY_ANGLE_DELTA

    slice = 0
    while slice < RbConfig::WINDOW_WIDTH

      type, distance, map_x, map_y = @map.find_nearest_intersection(@player.x, @player.y, ray_angle)

      # Correct spherical distortion
      # corrected_distance here is the perpendicular distance between the player and wall.
      corrected_angle = ray_angle - @player.angle
      corrected_distance = distance * Math::cos(corrected_angle * Math::PI / 180)

      slice_height = ((Map::TEX_HEIGHT / corrected_distance) * Player::DISTANCE_TO_PROJECTION)
      slice_y = (RbConfig::WINDOW_HEIGHT - slice_height) * (1 - @player.height)

      n = 0
      while n < RbConfig::SUB_DIVISION && (slice + n) < RbConfig::WINDOW_WIDTH
        @wall_perp_distances[slice + n] = corrected_distance
        texture = @map.texture_for(type, map_x, map_y, ray_angle)
        texture.draw(slice + n, slice_y, ZOrder::LEVEL, 1, slice_height / Map::TEX_HEIGHT) if texture

        ray_angle = (360 + ray_angle - ray_angle_delta) % 360
        n += 1
      end

      slice += (n == 0) ? 1 : n
    end
  end

  def draw_hud
    # Health
    draw_number(@player.health, 600, 400)
    # Score
    draw_number(@player.score, 600, 350)
  end

  def draw_number(number, x, y = 435)
    n = 1
    while (number == 0 && n == 1) || n <= number
      digit = (number / n).to_i
      digit %= 10

      @hud_numbers[digit].draw(x, y, ZOrder::HUD + 1)

      x -= 16

      n *= 10
    end
  end

  def draw_weapon
    return unless @player.weapon
    if button_down? Gosu::KbUp
      dy = Math.cos(Time.now.to_f * -10) * 7
    elsif button_down? Gosu::KbDown
      dy = Math.cos(Time.now.to_f * 10) * 7
    else
      dy = Math.cos(Time.now.to_f * 5) * 3
    end

    if @fired_weapon
      @player.weapon.fire_sprite.draw(200, 244 + dy, ZOrder::WEAPON)
      @fire_sound.play(0.2)
    else
      @player.weapon.idle_sprite.draw(200, 280 + dy, ZOrder::WEAPON)
    end
  end

  def draw_screen_flash
    if @powerdown_screen_flash > 0 || @powerup_screen_flash > 0
      if @powerdown_screen_flash > 0
        screen_flash_color = POWERDOWN_SCREEN_FLASH_COLOR
        screen_flash_color.alpha = @powerdown_screen_flash
        @powerdown_screen_flash -= SCREEN_FLASH_STEP
      elsif @powerup_screen_flash > 0
        screen_flash_color = POWERUP_SCREEN_FLASH_COLOR
        screen_flash_color.alpha = @powerup_screen_flash
        @powerup_screen_flash -= SCREEN_FLASH_STEP
      end

      draw_quad(
        TOP, LEFT, screen_flash_color, RIGHT, TOP,
        screen_flash_color, RIGHT, BOTTOM, screen_flash_color,
        LEFT, BOTTOM, screen_flash_color, ZOrder::SCREEN_FLASH
      )
    end
  end

  def draw_text
    if @active_text
      if Time.now > @active_text_timeout
        @active_text = nil
        @active_text_timeout = nil
      else
        images  = ImagePool.get_text(self, @active_text)
        y       = 12
        bg_top  = y
        bg_left = bg_right = bg_bottom = nil

        images.each do |image|
          x = (RIGHT - LEFT) / 2 - image.width / 2
          image.draw(x, y, ZOrder::TEXT)
          y += image.height + TEXT_VERTICAL_SPACING

          bg_left = x if bg_left.nil? || x < bg_left
          bg_right = x + image.width if bg_right.nil? || x + image.width > bg_right
        end
        bg_bottom = y - TEXT_VERTICAL_SPACING

        bg_left   -= TEXT_BACKGROUND_PADDING
        bg_right  += TEXT_BACKGROUND_PADDING
        bg_top    -= TEXT_BACKGROUND_PADDING
        bg_bottom += TEXT_BACKGROUND_PADDING

        draw_quad(bg_left, bg_top, TEXT_BACKGROUND_COLOR,
                  bg_right, bg_top, TEXT_BACKGROUND_COLOR,
                  bg_right, bg_bottom, TEXT_BACKGROUND_COLOR,
                  bg_left, bg_bottom, TEXT_BACKGROUND_COLOR,
                  ZOrder::TEXT_BACKGROUND)
      end
    end
  end

  def draw_fade_out_overlay
    if @fade_out
      FADE_OUT_OVERLAY_COLOR.alpha = @fade_out[:alpha]
      draw_quad(LEFT,  TOP, FADE_OUT_OVERLAY_COLOR,
                RIGHT, TOP, FADE_OUT_OVERLAY_COLOR,
                RIGHT, BOTTOM, FADE_OUT_OVERLAY_COLOR,
                LEFT,  BOTTOM, FADE_OUT_OVERLAY_COLOR,
                ZOrder::FADE_OUT_OVERLAY)
    end
  end
end

class ConfigWindow < Gosu::Window
  def initialize
    super(300, 200, false)
  end
  def update
    if button_down? Gosu::KbF
      @fullscreen = true
      close
    end
    if button_down? Gosu::KbW
      @fullscreen = false
      close
    end
    close if button_down? Gosu::KbEscape
  end

  def draw
   # draw_quad(0,0,Gosu::Color::WHITE, 300,0,Gosu::Color::WHITE, 300,200,Gosu::Color::WHITE,0,200,Gosu::Color::WHITE)
    hud = Gosu::Image::new(self, 'hud.png', true)
    f = Gosu::Image.from_text(self, '[F]ullscreen', Gosu::default_font_name, 22, 4, 150, :center)
    w = Gosu::Image.from_text(self, '[W]indowed', Gosu::default_font_name, 22, 4, 150, :center)
    f.draw(0, 100, 0)
    w.draw(150,100, 0)
  end

  def fullscreen?
    @fullscreen
  end
end

Dir.chdir 'assets'

config_window = ConfigWindow.new
config_window.show

exit if config_window.fullscreen? == nil

game_window = GameWindow.new(fullscreen: config_window.fullscreen?)
if ARGV[0] == '--profile'
  require 'ruby-prof'
  result = RubyProf.profile do
    game_window.show
  end
  File.open('profile.html', 'w') do |f|
    RubyProf::GraphHtmlPrinter.new(result).print(f, :min_percent => 5)
  end
else
  game_window.show
end
