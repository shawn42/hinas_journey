class Numeric
  def percent
    self / 100.0
  end
end

class Camera
  attr_accessor :x, :y
  attr_accessor :light_diameter, :light_color

  def initialize(x,y)
    @x = x
    @y = y
    @light_diameter = 4.0
    @light_color = 0xFFFFFFFF
  end
end

class Torch
  attr_accessor :x, :y
  attr_accessor :light_diameter, :light_color
  def initialize(x,y)
    @x = x
    @y = y
    @light_diameter = 2.0
    @light_color = 0xFFFFFFAA
  end
end

class Player
  attr_accessor :x, :y
  def initialize(x,y)
    @x = x
    @y = y
  end
end

class Tree
  def passable;false;end
  def z;3;end
  def color
    @color ||= Color.rgba 11, 140, 82, 200
  end
end

class CaveEntrance
  def passable;true;end
  def z;3;end
  def color
    @color ||= Color.rgba 20, 20, 20, 200
  end
end

class Wall
  def passable;false;end
  def z;3;end
  def color
    @color ||= Color.rgba 97, 92, 84, 200
  end
end

class Road
  def passable;true;end
  def z;1;end
  def color
    @color ||= Color.rgba 161, 131, 76, 200
  end
end

