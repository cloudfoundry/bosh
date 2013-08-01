require 'rake/file_utils'
require 'yaml'

require 'bosh/dev/ami'
require 'bosh/dev/infrastructure'

module Bosh::Dev
  class Stemcell
    DEFAULT_AWS_AMI_REGION = 'us-east-1'

    attr_reader :path

    def initialize(path = '')
      @path = path
      validate_stemcell
    end

    def create_light_stemcell
      raise 'Stemcell is already a light-stemcell' if light?
      Stemcell.new(create_light_aws_stemcell) if infrastructure.name == 'aws'
    end

    def manifest
      @manifest ||= Psych.load(`tar -Oxzf #{path} stemcell.MF`)
    end

    def name
      manifest.fetch('name')
    end

    def infrastructure
      Infrastructure.for(cloud_properties.fetch('infrastructure'))
    end

    def version
      cloud_properties.fetch('version')
    end

    def light?
      infrastructure.name == 'aws' && ami_id
    end

    def ami_id(region = DEFAULT_AWS_AMI_REGION)
      cloud_properties.fetch('ami', {}).fetch(region, nil)
    end

    def extract(tar_options = {}, &block)
      Dir.mktmpdir do |tmp_dir|
        tar_cmd = "tar xzf #{path} --directory #{tmp_dir}"
        tar_cmd << " --exclude=#{tar_options[:exclude]}" if tar_options.has_key?(:exclude)

        Rake::FileUtilsExt.sh(tar_cmd)

        block.call(tmp_dir, manifest)
      end
    end

    def publish_for_pipeline(pipeline)
      pipeline.s3_upload(path, File.join(name, infrastructure.name, filename.filename))
      pipeline.s3_upload(path, File.join(name, infrastructure.name, latest_filename.filename))
    end

    private

    def latest_filename
      StemcellFilename.new(
          version: 'latest',
          infrastructure: infrastructure.name,
          format: format,
          hypervisor: infrastructure.hypervisor
      )
    end

    def filename
      StemcellFilename.new(
          version: version,
          infrastructure: infrastructure.name,
          format: format,
          hypervisor: infrastructure.hypervisor
      )
    end

    def format
      light? ? 'ami' : 'image'
    end

    def cloud_properties
      manifest.fetch('cloud_properties')
    end

    def create_light_aws_stemcell
      ami = Ami.new(self)
      ami_id = ami.publish
      extract(exclude: 'image') do |extracted_stemcell_dir, stemcell_manifest|
        Dir.chdir(extracted_stemcell_dir) do
          stemcell_manifest['cloud_properties']['ami'] = { ami.region => ami_id }

          FileUtils.touch('image', verbose: true)

          File.open('stemcell.MF', 'w') do |out|
            Psych.dump(stemcell_manifest, out)
          end

          Rake::FileUtilsExt.sh("sudo tar cvzf #{light_stemcell_path} *")
        end
      end
      light_stemcell_path
    end

    def light_stemcell_filename
      StemcellFilename.new(
          version: version,
          infrastructure: infrastructure.name,
          format: 'ami',
          hypervisor: infrastructure.hypervisor
      )
    end

    def light_stemcell_path
      File.join(File.dirname(path), light_stemcell_filename.filename)
    end

    def validate_stemcell
      raise "Cannot find file `#{path}'" unless File.exists?(path)
    end
  end
end
