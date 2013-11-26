require 'tmpdir'
require 'digest/sha1'

module Bosh::Director
  class CompressedRenderedJobTemplates
    def initialize(path)
      @path = path
    end

    def write(rendered_templates)
      Dir.mktmpdir do |dir|
        writer = RenderedTemplatesWriter.new
        writer.write(rendered_templates, dir)

        tar_gzipper = TarGzipper.new
        tar_gzipper.compress(dir, %w(.), @path)
      end
    end

    def contents
      File.open(@path, 'r')
    end

    def sha1
      Digest::SHA1.file(@path).hexdigest
    end
  end
end
