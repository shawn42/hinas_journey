require 'perlin'
require 'gosu'

class Numeric
  def percent
    self / 100.0
  end
end

class Camera
  attr_accessor :x, :y
  def initialize(x,y)
    @x = x
    @y = y
  end
end

class World
  attr_accessor :width, :height, :terrain, :chunk_size
  attr_reader :octave, :persistence
  def initialize(seed, chunk_size=50)
    puts "generating world for seed #{seed}..."
    @seed = seed
    @rng = Random.new(@seed)
    @width = chunk_size
    @height = chunk_size
    @chunk_size = chunk_size

    @persistence = 0.25
    @persistence = 1.34
    @octave = 3
    update_generator

    generate_chunk
  end

  def persistence=(persistence)
    @persistence = persistence
    # @persistence = rand(0.001..2.0)
    puts "new persistence value #{@persistence}"
    update_generator
  end

  def octave=(octave)
    @octave = [octave, 1].max
    update_generator
  end

  def update_generator
    puts "new generator: seed: #{@seed}, persistence: #{@persistence}, octave: #{@octave}"
    @noise_generator = Perlin::Generator.new @seed, @persistence, @octave, classic: true
  end

  def has_chunk?(x,y)
    @terrain && @terrain.has_key?(x) && @terrain[x].has_key?(y)
  end

  def generate_chunk(chunk_x=0,chunk_y=0)
    @terrain ||= {}
    @terrain[chunk_x] ||= {}
    chunk_terrain = Hash.new{|h,k| h[k] = {}}
    @terrain[chunk_x][chunk_y] = chunk_terrain

    interval = 0.08 #chunk_size/600.0
    x = chunk_x*chunk_size*interval
    y = chunk_y*chunk_size*interval
    puts "generating #{x},#{y} => #{chunk_size},#{chunk_size}"
    noise = @noise_generator.chunk(x,y,chunk_size,chunk_size,interval)#0.08)


    puts "[#{chunk_x},#{chunk_y}] => noise row size: #{noise.size}x#{noise.first.size} vs chunksize: #{chunk_size}"

    samples = noise.flatten
    deep_sea_level = -0.7
    sea_level = -0.3
    grass_height = 0.2
    mountain_height = 1.5
    snow_height = 2

    width.times do |x|
      height.times do |y|
        sample = noise[x][y]
        chunk_terrain[x][y] =
          if sample > snow_height
            :snow
          elsif sample > mountain_height
            :mountain
          elsif sample > grass_height
            :grass
          elsif sample > sea_level
            :sand
          elsif sample > deep_sea_level
            :shallow_water
          else
            :water
          end
      end
    end
  end
end

class MyGame < Gosu::Window
  CELL_WIDTH = 32
  CELL_HEIGHT = 32
  def initialize(seed)
    @width = 800
    @height = 608
    super @width, @height, false
    Gosu.enable_undocumented_retrofication

    @camera = Camera.new @width / 2, @height / 2

    @terrain_colors = {
      water:         Gosu::Color.rgba(0x3648D6FF),
      shallow_water: Gosu::Color.rgba(0x367BD6FF),
      sand:          Gosu::Color.rgba(0x96895DFF),
      grass:         Gosu::Color.rgba(0x229941FF),
      mountain:      Gosu::Color.rgba(0x79898FFF),
      snow:          Gosu::Color.rgba(0xD3E9F2FF),
    }
    @camera_color = Gosu::Color.rgba(0xFF0000FF)

    # @font = Gosu::Font.new self, "Arial", 30
    @env_tiles = Gosu::Image.load_tiles(self, "environment.png", 32, 32, true)
    @typed_tiles = {
      water:         @env_tiles[16*11+12],
      shallow_water: @env_tiles[16*7 +3],
      sand:          @env_tiles[16*11+13],
      grass:         @env_tiles[16*7 +1],
      mountain:      @env_tiles[16*6 +0],
      snow:          @env_tiles[16*7 +0],
    }

    generate_world seed
  end

  def generate_world(seed)
    @world = World.new seed
  end

  def regenerate_world
    @world.terrain = nil
  end

  def update
    generate_new_chunks
    destroy_old_chunks
  end

  def generate_new_chunks
    chunk_x = @camera.x / (@world.chunk_size * CELL_WIDTH)
    chunk_y = @camera.y / (@world.chunk_size * CELL_HEIGHT)

    unless @world.has_chunk? chunk_x, chunk_y
      @world.generate_chunk chunk_x, chunk_y
    end
  end

  def destroy_old_chunks
  end

  def draw
    trans_x = (@camera.x - @width / 2)
    trans_y = (@camera.y - @height / 2)

    translate(-trans_x, -trans_y) do
      # render only the chunk the camera is in atm
      cam_chunk_x = @camera.x / (@world.chunk_size * CELL_WIDTH)
      cam_chunk_y = @camera.y / (@world.chunk_size * CELL_HEIGHT)

      (cam_chunk_x-1..cam_chunk_x+1).each do |chunk_x|
        (cam_chunk_y-1..cam_chunk_y+1).each do |chunk_y|

          if @world.has_chunk? chunk_x, chunk_y
            chunk_terrain = @world.terrain[chunk_x][chunk_y]
            chunk_x_off = chunk_x * @world.chunk_size * CELL_WIDTH
            chunk_y_off = chunk_y * @world.chunk_size * CELL_HEIGHT
            @world.chunk_size.times do |px|
              @world.chunk_size.times do |py|
                x = px*CELL_WIDTH + chunk_x_off
                y = py*CELL_HEIGHT + chunk_y_off
                terrain_type = chunk_terrain[px][py] 
                # c = lookup_color(terrain_type)
                # draw_quad(x, y, c, 
                #           x+CELL_WIDTH, y, c, 
                #           x+CELL_WIDTH, y+CELL_HEIGHT, c, 
                #           x, y+CELL_HEIGHT, c, z = 0)
                @typed_tiles[terrain_type].draw(x,y,0)
              end
            end
          end
        end
      end
      x = @camera.x
      y = @camera.y
      c = @camera_color
      draw_quad(x, y, c,
                x+10, y, c, 
                x+10, y+10, c, 
                x, y+10, c, z = 1)
    end
    # end
    # @terrain_cache.draw(0, 0, 0)
  end

  def lookup_color(terrain_type)
    @terrain_colors[terrain_type]
  end

  def button_down(id)
    exit if id == Gosu::KbEscape
    camera_jump = 32
    if id == Gosu::KbLeft
      @world.octave -= 1
      regenerate_world
    elsif id == Gosu::KbRight
      @world.octave += 1
      regenerate_world
    elsif id == Gosu::KbUp
      @world.persistence += 0.25
      regenerate_world
    elsif id == Gosu::KbDown
      @world.persistence -= 0.25
      regenerate_world
    elsif id == Gosu::KbSpace
      generate_world (rand*100_000).round
    elsif id == Gosu::KbH
      @camera.x -= camera_jump
    elsif id == Gosu::KbL
      @camera.x += camera_jump
    elsif id == Gosu::KbJ
      @camera.y += camera_jump
    elsif id == Gosu::KbK
      @camera.y -= camera_jump
    elsif id == Gosu::KbC
      puts "CAM: [#{@camera.x},#{@camera.y}]"
    end

    # regenerate_world
  end
end

seed = (ARGV[0] || 123).to_i
MyGame.new(seed).show
