require 'gosu'

class GameWindow < Gosu::Window
  def button_down(id)
    puts id.to_s
    close if id == Gosu::KbEscape
  end
end

game_window = GameWindow.new(80, 60, false, 10)
game_window.show
