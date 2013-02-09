require './map'

class Door
  attr_accessor :pos
  attr_reader   :state
  attr_reader   :opened_at
  OPEN_CLOSE_STEP = 8
  STAYS_SECONDS_OPEN = 4
  FULL_VOLUME_WITHIN_GRID_BLOCKS = 5.0

  def initialize
    @state = :closed
    @pos   = 0
    @opened_at = 0
  end

  def open!
    if self.closed?
      @state = :opening
      @opened_at = Time.now.to_i
    end
    
    if !self.open? && @state == :opening
      @pos += OPEN_CLOSE_STEP
    end
  end
  
  def open?
    return @pos == Map::GRID_WIDTH_HEIGHT
  end
  
  def close!
    if self.open?
      @state = :closing
    end
    
    if !self.closed? && @state == :closing
      @pos -= OPEN_CLOSE_STEP
    end
  end
  
  def closed?
    return @pos == 0
  end
  
  def interact
    if @state == :opening
      self.open!
    elsif @state == :closing
      self.close!
    end
  end

  def obstructed?(map, player)
    row, column = Map.matrixify(player.y, player.x)
    return true if map.doors[row][column] == self
    map.players.each do |p|
      row, column = Map.matrixify(p.y, p.x)
      return true if map.doors[row][column] == self
    end
    false
  end
end
