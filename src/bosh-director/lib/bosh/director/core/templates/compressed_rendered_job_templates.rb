require 'tmpdir'
require 'digest/sha1'
require 'bosh/director/core/templates'
require 'bosh/director/core/tar_gzipper'
require 'bosh/director/core/templates/rendered_templates_writer'

module Bosh::Director::Core::Templates
  class CompressedRenderedJobTemplates
    def initialize(path)
      @path = path
    end

    def write(rendered_templates)
      Dir.mktmpdir do |dir|
        writer = RenderedTemplatesWriter.new
        writer.write(rendered_templates, dir)

        tar_gzipper = Bosh::Director::Core::TarGzipper.new
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
