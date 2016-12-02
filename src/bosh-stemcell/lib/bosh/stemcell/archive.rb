require 'yaml'
require 'rake/file_utils_ext'
require 'bosh/stemcell/aws/region'

module Bosh::Stemcell
  class Archive
    attr_reader :path

    def initialize(path = '')
      @path = path
      validate_stemcell
    end

    def manifest
      @manifest ||= Psych.load(`tar -Oxzf #{path} stemcell.MF`)
    end

    def name
      manifest.fetch('name')
    end

    def infrastructure
      cloud_properties.fetch('infrastructure')
    end

    def version
      cloud_properties.fetch('version')
    end

    def sha1
      sha1 = manifest.fetch('sha1')
      raise 'sha1 must not be nil' unless sha1
      sha1.to_s
    end

    def light?
      infrastructure == 'aws' && has_ami?
    end

    def extract(tar_options = {}, &block)
      Dir.mktmpdir do |tmp_dir|
        tar_cmd = "tar xzf #{path} --directory #{tmp_dir}"
        tar_cmd << " --exclude=#{tar_options[:exclude]}" if tar_options.has_key?(:exclude)

        Rake::FileUtilsExt.sh(tar_cmd)

        block.call(tmp_dir, manifest)
      end
    end

    private

    def has_ami?
      cloud_properties.has_key? 'ami'
    end

    def cloud_properties
      manifest.fetch('cloud_properties')
    end

    def validate_stemcell
      raise "Cannot find file '#{path}'" unless File.exists?(path)
    end
  end
end
