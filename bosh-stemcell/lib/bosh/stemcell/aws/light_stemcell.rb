require 'rake/file_utils'
require 'yaml'
require 'common/deep_copy'
require 'bosh/stemcell/aws/region'
require 'bosh/stemcell/aws/ami'

module Bosh::Stemcell::Aws
  class LightStemcell
    def initialize(stemcell, virtualization_type)
      @stemcell = stemcell
      @virtualization_type = virtualization_type
    end

    def write_archive
      stemcell.extract(exclude: 'image') do |extracted_stemcell_dir|
        Dir.chdir(extracted_stemcell_dir) do
          FileUtils.touch('image', verbose: true)

          File.open('stemcell.MF', 'w') do |out|
            Psych.dump(manifest, out)
          end

          Rake::FileUtilsExt.sh("sudo tar cvzf #{path} *")
        end
      end
    end

    def path
      stemcell_name = File.basename(stemcell.path)
      stemcell_name = stemcell_name.gsub("xen", "xen-hvm") if virtualization_type == "hvm"
      File.join(File.dirname(stemcell.path), "light-#{stemcell_name}")
    end

    private

    attr_reader :stemcell, :virtualization_type

    def manifest
      region = Region.new
      ami = Ami.new(stemcell, region, virtualization_type)
      ami_id = ami.publish
      manifest = Bosh::Common::DeepCopy.copy(stemcell.manifest)
      manifest['cloud_properties']['ami'] = { region.name => ami_id }
      manifest
    end
  end
end
