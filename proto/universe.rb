require 'perlin'
require 'gosu'
require 'zlib'
require 'fileutils'
require_relative './monster_id'

MONSTER_CACHE_DIR = "cache/monsters"
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
    if Random.new(new_seed).rand(10) < 5
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
    @noise_generator = Perlin::Generator.new @seed, persistence, octave
    @noise_generator.classic = true
    @width = 200
    @height = 200
    generate_terrain
    generate_monsters
  end

  def generate_monsters
    @monster = MonsterId::Monster.new @seed
    FileUtils.mkdir_p(MONSTER_CACHE_DIR) unless File.exists?(MONSTER_CACHE_DIR)
    monster_image = "#{MONSTER_CACHE_DIR}/m-#{@seed}.png"
    @monster.save(monster_image) unless File.exists? monster_image
  end

  def generate_terrain
    terrain = Hash.new{|h,k| h[k] = {}}
    noise = @noise_generator.chunk2d(0,0,width,height,0.05)
    samples = noise.flatten
    min = samples.min
    max = samples.max
    range = max - min

    deep_sea_level = min + range * 0.3
    sea_level = deep_sea_level + range * 0.2
    mountain_height = sea_level + range * 0.3
    snow_height = mountain_height + range * 0.1

    @terrain = Hash.new{|h,k| h[k] = {}}
    width.times do |x|
      height.times do |y|
        sample = noise[x][y]
        type = 
        if sample > snow_height
          :snow
        elsif sample > mountain_height
          :mountain
        elsif sample > sea_level
          :grass
        elsif sample > deep_sea_level
          :shallow_water
        else
          :water
        end
        @terrain[x][y] = [type, sample]
      end
    end
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
  SCALE = 0.1
  PLANET_CELL_WIDTH = 32*SCALE
  PLANET_CELL_HEIGHT = 32*SCALE
  SYSTEM_CELL_WIDTH = 80 * PLANET_CELL_WIDTH
  SYSTEM_CELL_HEIGHT = 80 * PLANET_CELL_HEIGHT
  def initialize(seed)
    @width = 800
    @height = 608
    super @width, @height, false

    @seed = seed
    @planets = []
    @planet_index = 0

    @terrain_colors = {
      water: Gosu::Color.rgba(0x3482DBCC),
      shallow_water: Gosu::Color.rgba(0x3482DBFF),
      grass: Gosu::Color.rgba(0xA2C341FF),
      mountain: Gosu::Color.rgba(0xB6B7ABFF),
      snow: Gosu::Color.rgba(0xDFE6F6FF),
    }

    generate_universe

    Gosu.enable_undocumented_retrofication
    @font = Gosu::Font.new self, "Arial", 30
    @env_tiles = Gosu::Image.load_tiles(self, "environment.png", 32, 32, true)
  end

  def generate_universe
    @universe = UniverseNode.new(@seed)
    4.times do |j|
      system = @universe.child_at(1,j)
      if system
        4.times do |i|
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
    puts "NO PLANETS!" if @planets.empty?
  end

  def draw
    planet = @planets[@planet_index]
    draw_planet planet if planet
  end

  def draw_planet(planet)
    @planet_terrain_cache ||= {}
    @planet_terrain_cache[planet] ||= record(@width, @height) do
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
          # tile_index = lookup_tile_index(terrain_type)
          c = lookup_color(terrain_type)
          # c.alpha = (value * 175 + 80)
          draw_quad(x, y, c, 
                    x+PLANET_CELL_WIDTH, y, c, 
                    x+PLANET_CELL_WIDTH, y+PLANET_CELL_HEIGHT, c, 
                    x, y+PLANET_CELL_HEIGHT, c, z = 0)
          # @env_tiles[tile_index].draw(x,y,0,SCALE,SCALE)
        end
      end
    end
    @planet_terrain_cache[planet].draw(0, 0, 0)
    monster_image = Gosu::Image.new(self, "#{MONSTER_CACHE_DIR}/m-#{planet.seed}.png", false)
    monster_image.draw(100, 100, 99)
  end

  def lookup_color(terrain_type)
    @terrain_colors[terrain_type]
  end

  def lookup_tile_index(terrain_type)
    # TODO lookup map
    case terrain_type
    when :water
      114
    when :grass
      70
    when :mountain
      96
    when :snow
      149
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
