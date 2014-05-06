require 'chunky_png'
require 'digest'

module MonsterId

  class Monster
    SIZE = 120

    def initialize(seed, size=nil)
      @rng = Random.new(Digest::MD5.hexdigest(seed.to_s).to_i(16))

      # throw the dice for body parts
      parts = {
        legs:  @rng.rand(5),
        hair:  @rng.rand(5),
        arms:  @rng.rand(5),
        body:  @rng.rand(15),
        eyes:  @rng.rand(15),
        mouth: @rng.rand(10),
      }

      @image = ChunkyPNG::Image.new SIZE, SIZE, ChunkyPNG::Color::TRANSPARENT

      parts.each do |name, number|
        path = File.join File.dirname(__FILE__), 'parts', "#{name}_#{number + 1}.png"
        part = ChunkyPNG::Image.from_file path

        if name == :body
          # random body color
          w, h = part.width, part.height
          r, g, b = @rng.rand(215) + 20, @rng.rand(215) + 20, @rng.rand(215) + 20
          body_color = r * 256 * 256 * 256 + g * 256 * 256 + b * 256 + 255
          part.pixels.each_with_index do |color, i|
            unless color == 0 || color == 255
              part[i % w, (i / w).to_i] = body_color
            end
          end
        end

        @image.compose!(part, 0, 0)
      end

      @image.resample_bilinear!(size, size) unless size == nil or size == SIZE
    end

    def to_s
      @image.to_datastream.to_s
    end

    def inspect
      ''
    end

    def to_data_uri
      'data:image/png;base64,' + Base64.encode64(@image.to_s).gsub(/\n/, '')
    end

    def save(path)
      @image.save(path)
    end
  end

end

