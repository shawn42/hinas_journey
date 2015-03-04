require_relative 'things'
class Array
  def x; self[0]; end
  def y; self[1]; end

  def <=>(b)
    super unless size == 2
    if x < b.x
      -1
    elsif x > b.x
      1
    else
      if y < b.y
        -1
      elsif y > b.y
        1
      else
        0
      end
    end
  end
end

class CityPlannerMap
  attr_accessor :w, :h
  TRAVEL_COST_STRAIGHT = 10
  
  def initialize(terrain, objects)
    @w = terrain.size
    @h = terrain.first.size
    @terrain = terrain
    @objects = objects
  end
  
  def size
    [@w,@h]
  end
  
  def blocked?(location, type=nil)
    # puts "blocked? for #{location}"
    tile = @terrain[location.x][location.y]
    if tile != :sand && tile != :grass
      return true
    else
      objects = @objects[location.x][location.y]
      obj_blocks = objects && !objects.all?(&:passable)
      return obj_blocks
    end
  end
  
  def neighbors(location)
    x = location.x
    y = location.y
    [
      [x-1, y],
      [x+1, y],
      [x, y-1],
      [x, y+1]
    ]
  end
  
  def distance(from,to)
    h_straight = ((from.x-to.x).abs + (from.y-to.y).abs)
    return TRAVEL_COST_STRAIGHT * h_straight
  end
  
  def cost(from, to)
    # puts "cost for #{from} => #{to}"
    target_is_road = @objects[to.x][to.y] && @objects[to.x][to.y].any?{|o|o.is_a? Road}
    if from.x == to.x && from.y == to.y
      0
    elsif target_is_road
      0.01 # non zero to make polaris happy
    else
      TRAVEL_COST_STRAIGHT
    end
  end
end
