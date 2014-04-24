require 'perlin'
require 'gosu'
require 'zlib'

def crc32(*stuff)
  Zlib::crc32(stuff.join)
end

def random_name(rng)
  length = rng.rand(5..12)
  ([*('a'..'z')]-%w(0 1 I O)).sample(length, random: rng).join.capitalize
end

class Node
  attr_accessor :parent, :seed, :children, :rng, :x, :y, :name
  def initialize(seed, parent=nil, x=nil, y=nil)
    @seed = seed
    @rng = Random.new(@seed)

    @parent = parent
    @children = Hash.new{|h,k| h[k] = {}}
    @x = x
    @y = y
    @name = random_name(@rng)
  end

  def child_at(x,y)
    new_seed = crc32(@seed, x, y)
    if Random.new(new_seed).rand(10) < 11
      @children[x][y] ||= build_child(new_seed, x, y)
    else
      nil
    end
  end

  def build_child(seed, x,y)
    child_type.new(seed, self, x, y)
  end

  def child_type; Node; end

  def print(depth=0)
    padding = " "*depth
    puts "#{padding}#{self.class.name.chomp("Node")} #{@name}"
    children.each do |x, row|
      row.each do |y, child|
        child.print depth+1
      end
    end
  end
end
class UniverseNode < Node
  def child_type; SolarSystemNode; end
end
class SolarSystemNode < Node
  def child_type; PlanetNode; end
end
class PlanetNode < Node
  attr_accessor :has_rings, :width, :height, :terrain
  def initialize(seed, parent=nil, x=nil, y=nil)
    super
    @has_rings = @rng.rand < 0.25

    persistence = 0.25
    octave = 1
    @noise = Perlin::Generator.new @seed, persistence, octave
    @noise.classic = true
    @width = 100
    @height = 100
    generate_terrain
  end

  def generate_terrain
    terrain = Hash.new{|h,k| h[k] = {}}
    min = 2
    max = -2 
    samples = []
    noise = @noise.chunk2d(0,0,width,height,0.05)
    width.times do |x|
      height.times do |y|
        # sample = @noise.run2d x*0.02, y*0.02
        sample = noise[x][y]
        max = sample if sample > max
        min = sample if sample < min
        samples << sample
        terrain[x][y] = sample
      end
    end

    sea_level = samples.inject(&:+)/samples.size - 0.1
    mountain_height = sea_level + rand(0.5..0.9)
    snow_height = mountain_height + rand(0.2..0.4)
    puts "sea level: #{sea_level}"
    puts "mountain level: #{mountain_height}"

    @terrain = Hash.new{|h,k| h[k] = {}}
    width.times do |x|
      height.times do |y|
        sample = terrain[x][y]
        type = 
        if sample > snow_height
          :snow
        elsif sample > mountain_height
          :mountain
        elsif sample > sea_level
          :grass
        else
          :water
        end
        @terrain[x][y] = [type, sample]
      end
    end
    puts "min: #{min} max: #{max}"
  end

  def print(depth=0)
    super
    if @has_rings
      padding = " "*depth
      puts "#{padding} has rings!"
      puts @terrain.inspect
    end
  end
end

class MyGame < Gosu::Window
  PLANET_CELL_WIDTH = 4
  PLANET_CELL_HEIGHT = 4
  SYSTEM_CELL_WIDTH = 80 * PLANET_CELL_WIDTH
  SYSTEM_CELL_HEIGHT = 80 * PLANET_CELL_HEIGHT
  def initialize(seed)
    @width = 800
    @height = 608
    super @width, @height, false

    @seed = seed
    @planets = []
    @planet_index = 0

    generate_universe

    @font = Gosu::Font.new self, "Arial", 30
  end

  def generate_universe
    @universe = UniverseNode.new(@seed)
    5.times do |j|
      system = @universe.child_at(1,j)
      if system
        5.times do |i|
          system.child_at(0,i)
        end
      end
    end
    @universe.children.each do |ux, urow|
      urow.each do |uy, system|
        if system
          system.children.each do |sx, srow|
            srow.each do |sy, planet|
              @planets << planet if planet
            end
          end
        end
      end
    end
  end

  def draw
    planet = @planets[@planet_index]
    draw_planet planet if planet
  end

  def draw_planet(planet)
    planet.width.times do |px|
      planet.height.times do |py|
        universe = planet.parent.parent
        system = planet.parent
        @font.draw "#{universe.name}", 450, 10, 1
        @font.draw "[#{system.x},#{system.y}] #{system.name}", 450, 40, 1
        @font.draw "[#{planet.x},#{planet.y}] #{planet.name}", 450, 70, 1
        x = px*PLANET_CELL_WIDTH
        y = py*PLANET_CELL_HEIGHT
        # a = planet.terrain[px][py] * 155 + 100
        # c = Gosu::Color.rgba(a,a,a,255)
        terrain_type, value = planet.terrain[px][py] 
        c = lookup_color(terrain_type)
        # c = Gosu::Color.rgba(c.red,c.green,c.blue,255)
        c.alpha = (value * 175 + 80)
        draw_quad(x, y, c, 
                  x+PLANET_CELL_WIDTH, y, c, 
                  x+PLANET_CELL_WIDTH, y+PLANET_CELL_HEIGHT, c, 
                  x, y+PLANET_CELL_HEIGHT, c, z = 0)
      end
    end
  end

  def lookup_color(terrain_type)
    case terrain_type
    when :water
      Gosu::Color::BLUE 
    when :grass
      Gosu::Color::GREEN
    when :mountain
      Gosu::Color::GRAY
    when :snow
      Gosu::Color::WHITE
    end
  end

  def button_down(id)
    exit if id == Gosu::KbEscape
    if id == Gosu::KbUp
      @planet_index += 1 
      @planet_index %= @planets.size
    end
    if id == Gosu::KbDown
      @planet_index -= 1 
      @planet_index = @planets.size-1 if @planet_index < 0
    end
  end
end

seed = (ARGV[0] || 123).to_i
MyGame.new(seed).show
