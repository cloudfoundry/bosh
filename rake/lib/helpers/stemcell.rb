require 'rake'
require 'yaml'
require_relative 'ami'

module Bosh
  module Helpers
    class Stemcell
      def self.from_jenkins_build(infrastructure, type, build)
        new(Dir.glob("/mnt/stemcells/#{infrastructure}-#{type}/work/work/*-stemcell-*-#{build.number}.tgz").first)
      end

      attr_reader :path

      def initialize(path)
        @path = path
        validate_stemcell
      end

      def create_light_stemcell
        raise "Stemcell is already a light-stemcell" if is_light?
        Stemcell.new(create_light_aws_stemcell) if infrastructure == 'aws'
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

      def is_light?
        infrastructure == 'aws' && cloud_properties.has_key?('ami')
      end

      def extract(tar_options={}, &block)
        Dir.mktmpdir do |tmp_dir|
          tar_cmd = "tar xzf #{path} --directory #{tmp_dir}"
          tar_cmd << " --exclude=#{tar_options[:exclude]}" if tar_options.has_key?(:exclude)

          Rake::FileUtilsExt.sh(tar_cmd)

          block.call(tmp_dir, manifest)
        end
      end

      private

      def cloud_properties
        manifest.fetch('cloud_properties')
      end

      def create_light_aws_stemcell
        ami = Ami.new(self)
        ami_id = ami.publish
        extract(exclude: 'image') do |extracted_stemcell_dir, stemcell_manifest|
          Dir.chdir(extracted_stemcell_dir) do
            stemcell_manifest['cloud_properties']['ami'] = {ami.region => ami_id}

            FileUtils.touch('image')

            File.open('stemcell.MF', 'w') do |out|
              Psych.dump(stemcell_manifest, out)
            end

            Rake::FileUtilsExt.sh("tar cvzf #{light_stemcell_path} *")
          end
        end
        light_stemcell_path
      end

      def light_stemcell_name
        "light-#{File.basename(path)}"
      end

      def light_stemcell_path
        File.join(File.dirname(path), light_stemcell_name)
      end

      def validate_stemcell
        raise "Cannot find file `#{path}'" unless File.exists?(path)
      end
    end
  end
end
