module Bosh::Agent

  class Template

    class TemplateDataError < StandardError; end

    def self.write(&block)
      self.new(block).write
    end

    def initialize(block)
      raise ArgumentError unless block.arity == 1
      @block = block
      @block.call(self)
      raise TemplateDataError if @template_data.nil?
    end

    def src(src)
      case
      when src.kind_of?(String)
        unless src.match(%r{\A/})
          template_base_dir = File.dirname(__FILE__)
          template_path = File.join(template_base_dir, src)
        else
          template_path = src
        end
        fh = File.new(template_path)
      when src.kind_of?(IO), src.kind_of?(StringIO)
        fh = src
      end
      @template_data = fh.read
    end

    def dst(path)
      @dst = path
    end

    def render
      template = ERB.new(@template_data, 0, '%<>-')
      template.result(@block.binding)
    end

    def write
      File.open(@dst, 'w') { |fh| fh.write(self.render) }
    end

  end
end
