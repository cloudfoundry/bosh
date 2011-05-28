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

    def src(template_src)
      case template_src
      when String
        if template_src.match(%r{\A/})
          template_path = template_src
        else
          template_base_dir = File.dirname(__FILE__)
          template_path = File.join(template_base_dir, template_src)
        end
        fh = File.new(template_path)
      when IO, StringIO
        fh = template_src
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
