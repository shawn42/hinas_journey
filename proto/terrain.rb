require 'perlin'
require 'gosu'
CELL_SIZE = 32

require 'zlib'
def crc32(*stuff)
  Zlib::crc32(stuff.join)
end

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

class Player
  attr_accessor :x, :y
  def initialize(x,y)
    @x = x
    @y = y
  end
end

class Tree
end

class World
  attr_accessor :width, :height, :terrain, :chunk_size, :objects
  attr_reader :octave, :persistence
  def initialize(seed, chunk_size=50)
    puts "generating world for seed #{seed}..."
    @seed = seed
    @width = chunk_size
    @height = chunk_size
    @chunk_size = chunk_size

    @persistence = 1.34 + 0.25
    @octave = 1
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
    @multiplier_noise_generator = Perlin::Generator.new @seed, @persistence, @octave, classic: true
    @noise_generator = Perlin::Generator.new @seed, @persistence, @octave+2, classic: true
  end

  def has_chunk?(x,y)
    @terrain && @terrain.has_key?(x) && @terrain[x].has_key?(y)
  end

  def tile_for_world_coord(x,y)
    chunk_x = x / CELL_SIZE / chunk_size
    chunk_y = y / CELL_SIZE / chunk_size
    chunk_size_in_pixels = CELL_SIZE * chunk_size
    chunk_hash = @terrain[chunk_x][chunk_y]
    chunk_hash[(x-chunk_x*chunk_size_in_pixels)/CELL_SIZE][(y-chunk_y*chunk_size_in_pixels)/CELL_SIZE]
  end

  def generate_chunk(chunk_x=0,chunk_y=0)
    local_seed = crc32(@seed, chunk_x, chunk_y)
    rng = Random.new local_seed

    @terrain ||= {}
    @terrain[chunk_x] ||= {}
    chunk_terrain = Hash.new{|h,k| h[k] = {}}
    @terrain[chunk_x][chunk_y] = chunk_terrain

    @objects ||= {}
    @objects[chunk_x] ||= {}
    chunk_objects = Hash.new{|h,k| h[k] = {}}
    @objects[chunk_x][chunk_y] = chunk_objects

    interval = 0.08 #chunk_size/600.0
    x = chunk_x*chunk_size*interval
    y = chunk_y*chunk_size*interval
    puts "generating #{x},#{y} => #{chunk_size},#{chunk_size}"
    noise = @noise_generator.chunk(x,y,chunk_size,chunk_size,interval)#0.08)
    multiplier_noise = @multiplier_noise_generator.chunk(x,y,chunk_size,chunk_size,interval)#0.08)


    puts "[#{chunk_x},#{chunk_y}] => noise row size: #{noise.size}x#{noise.first.size} vs chunksize: #{chunk_size}"
    deep_sea_level = -0.7
    sea_level = -0.3
    grass_height = 0.2
    mountain_height = 1.5
    snow_height = 2

    deep_sea_level = -0.7
    sea_level = -0.3
    grass_height = 0.2
    mountain_height = 1.5
    snow_height = 2

    width.times do |x|
      height.times do |y|
        multiplier = [(multiplier_noise[x][y] + 1), 0].max / 2.5
        sample = noise[x][y] * multiplier
        if sample > snow_height
          type = :snow
        elsif sample > mountain_height
          type = :mountain
        elsif sample > grass_height
          type = :grass
          if rng.rand < 0.01
            # puts "TREE AT: #{chunk_x*chunk_size*CELL_SIZE+x},#{chunk_y*chunk_size*CELL_SIZE+y}"
            chunk_objects[x][y] ||= []
            chunk_objects[x][y] << Tree.new
          end
        elsif sample > sea_level
          type = :sand
        elsif sample > deep_sea_level
          type = :shallow_water
        else
          type = :water
        end
        chunk_terrain[x][y] = type
      end
    end
  end
end

class MyGame < Gosu::Window
  include Gosu
  def initialize(seed)
    @width = 800
    @height = 608
    super @width, @height, false
    Gosu.enable_undocumented_retrofication

    @player = Player.new @width / 2, @height / 2

    @camera = Camera.new @width / 2, @height / 2


    @terrain_colors = {
      water:         Color.rgba(0x3648D6FF),
      shallow_water: Color.rgba(0x367BD6FF),
      sand:          Color.rgba(0x96895DFF),
      grass:         Color.rgba(0x229941FF),
      mountain:      Color.rgba(0x79898FFF),
      snow:          Color.rgba(0xD3E9F2FF),
    }
    @camera_color = Color.rgba(0xFF0000FF)

    # @font = Font.new self, "Arial", 30
    @env_tiles = Image.load_tiles(self, "environment.png", 32, 32, true)
    @hero_tiles = Image.load_tiles(self, "heroes.png", -16, -1, true)
    @hero = @hero_tiles.first
    @typed_tiles = {
      water:         @env_tiles[16*11+12],
      shallow_water: @env_tiles[16*7 +3],
      sand:          @env_tiles[16*11+13],
      grass:         @env_tiles[16*7 +1],
      mountain:      @env_tiles[16*6 +0],
      snow:          @env_tiles[16*7 +0],
    }

    generate_world seed

    until player_position_valid?
      @player.x += CELL_SIZE
      update
    end
  end

  def player_position_valid?
    !BLOCK_TILES.include?(@world.tile_for_world_coord(@player.x,@player.y))
  end

  def generate_world(seed)
    @world = World.new seed
  end

  def regenerate_world
    @world.terrain = nil
  end

  def update
    chunk_x = @camera.x / (@world.chunk_size * CELL_SIZE)
    chunk_y = @camera.y / (@world.chunk_size * CELL_SIZE)

    generate_new_chunks chunk_x, chunk_y
    destroy_old_chunks chunk_x, chunk_y
    move_player
    update_camera
  end

  def update_camera
    @camera.x = @player.x
    @camera.y = @player.y
  end

  def move_player
    speed = 15
    @player.x -= speed if button_down?(KbA) && player_can_move?(-speed,0)
    @player.x += speed if button_down?(KbD) && player_can_move?(speed,0)
    @player.y -= speed if button_down?(KbW) && player_can_move?(0,-speed)
    @player.y += speed if button_down?(KbS) && player_can_move?(0,speed)
  end

  BLOCK_TILES = [:water, :mountain, :snow]
  def player_can_move?(x_delta, y_delta)
    # return true if BLOCK_TILES.include?(@world.tile_for_world_coord(@player.x,@player.y))
    if x_delta < 0
      !BLOCK_TILES.include?(@world.tile_for_world_coord(@player.x-8+x_delta,@player.y-8)) &&
        !BLOCK_TILES.include?(@world.tile_for_world_coord(@player.x-8+x_delta,@player.y+8))
    elsif x_delta > 0
      !BLOCK_TILES.include?(@world.tile_for_world_coord(@player.x+8+x_delta,@player.y-8)) &&
        !BLOCK_TILES.include?(@world.tile_for_world_coord(@player.x+8+x_delta,@player.y+8))
    else
      if y_delta < 0
        !BLOCK_TILES.include?(@world.tile_for_world_coord(@player.x-8, @player.y-8+y_delta)) &&
          !BLOCK_TILES.include?(@world.tile_for_world_coord(@player.x+8, @player.y-8+y_delta))
      elsif y_delta > 0
        !BLOCK_TILES.include?(@world.tile_for_world_coord(@player.x-8, @player.y+8+y_delta)) &&
          !BLOCK_TILES.include?(@world.tile_for_world_coord(@player.x+8, @player.y+8+y_delta))
      end
    end
  end

  def generate_new_chunks(chunk_x, chunk_y)
    (chunk_x-1..chunk_x+1).each do |cx|
      (chunk_y-1..chunk_y+1).each do |cy|
        unless @world.has_chunk? cx, cy
          @world.generate_chunk cx, cy
        end
      end
    end
  end

  def count_chunks
    count = 0
    @world.terrain.each do |x,row|
      count += row.size
    end
    count
  end

  def destroy_old_chunks(current_chunk_x, current_chunk_y)
    x_chunks_to_nuke = @world.terrain.keys.select{|chunk_x| chunk_x < (current_chunk_x - 1) || chunk_x > (current_chunk_x + 1)}
    x_chunks_to_nuke.each {|x| @world.terrain.delete x }
    @world.terrain.each do |x, row|
      y_chunks_to_nuke = row.keys.select{|chunk_y| chunk_y < (current_chunk_y - 1) || chunk_y > (current_chunk_y + 1)}
      y_chunks_to_nuke.each {|y| row.delete y }
    end

    x_chunks_to_nuke = @world.objects.keys.select{|chunk_x| chunk_x < (current_chunk_x - 1) || chunk_x > (current_chunk_x + 1)}
    x_chunks_to_nuke.each {|x| @world.objects.delete x }
    @world.objects.each do |x, row|
      y_chunks_to_nuke = row.keys.select{|chunk_y| chunk_y < (current_chunk_y - 1) || chunk_y > (current_chunk_y + 1)}
      y_chunks_to_nuke.each {|y| row.delete y }
    end
  end

  def draw
    trans_x = (@camera.x - @width / 2)
    trans_y = (@camera.y - @height / 2)

    translate(-trans_x, -trans_y) do
      cam_chunk_x = @camera.x / (@world.chunk_size * CELL_SIZE)
      cam_chunk_y = @camera.y / (@world.chunk_size * CELL_SIZE)

      (cam_chunk_x-1..cam_chunk_x+1).each do |chunk_x|
        (cam_chunk_y-1..cam_chunk_y+1).each do |chunk_y|

          if @world.has_chunk? chunk_x, chunk_y
            chunk_x_off = chunk_x * @world.chunk_size * CELL_SIZE
            chunk_y_off = chunk_y * @world.chunk_size * CELL_SIZE

            chunk_terrain = @world.terrain[chunk_x][chunk_y]
            chunk_objects = @world.objects[chunk_x][chunk_y]

            @world.chunk_size.times do |px|
              @world.chunk_size.times do |py|
                x = px*CELL_SIZE + chunk_x_off
                y = py*CELL_SIZE + chunk_y_off
                terrain_type = chunk_terrain[px][py] 
                # c = lookup_color(terrain_type)
                # draw_quad(x, y, c, 
                #           x+CELL_SIZE, y, c, 
                #           x+CELL_SIZE, y+CELL_SIZE, c, 
                #           x, y+CELL_SIZE, c, z = 0)
                @typed_tiles[terrain_type].draw(x,y,0)
                objects = chunk_objects[px][py] 
                if objects
                  objects.each do |obj|
                  
                    c = Color::GREEN
                    draw_quad(x, y, c, 
                              x+10, y, c, 
                              x+10, y+10, c, 
                              x, y+10, c, z = 3)
                  end
                end

              end
            end

          end
        end
      end
      x = @camera.x
      y = @camera.y
      c = @camera_color
      draw_quad(x, y, c,
                x+1, y, c, 
                x+1, y+1, c, 
                x, y+1, c, z = 2)
      @hero.draw_rot(@player.x,@player.y,1,0)
    end
    # end
    # @terrain_cache.draw(0, 0, 0)
  end

  def lookup_color(terrain_type)
    @terrain_colors[terrain_type]
  end

  def button_down(id)
    exit if id == KbEscape
    camera_jump = 32
    if id == KbLeft
      @world.octave -= 1
      regenerate_world
    elsif id == KbRight
      @world.octave += 1
      regenerate_world
    elsif id == KbUp
      @world.persistence += 0.25
      regenerate_world
    elsif id == KbDown
      @world.persistence -= 0.25
      regenerate_world
    elsif id == KbSpace
      generate_world (rand*100_000).round

    elsif id == KbH
      @camera.x -= camera_jump
    elsif id == KbL
      @camera.x += camera_jump
    elsif id == KbJ
      @camera.y += camera_jump
    elsif id == KbK
      @camera.y -= camera_jump
    elsif id == KbQ
      $debug = !$debug
    end

    # regenerate_world
  end
end

seed = (ARGV[0] || 123).to_i
MyGame.new(seed).show
