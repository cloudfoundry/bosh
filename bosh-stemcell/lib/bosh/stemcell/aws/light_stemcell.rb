require 'rake/file_utils'
require 'yaml'
require 'common/deep_copy'
require 'bosh/stemcell/aws/ami_collection'
require 'bosh/stemcell/aws/region'

module Bosh::Stemcell::Aws
  HVM_VIRTUALIZATION = 'hvm'

  class LightStemcell
    def initialize(stemcell, virtualization_type, regions=Region::REGIONS)
      @stemcell = stemcell
      @virtualization_type = virtualization_type
      @regions = regions
    end

    def write_archive
      @stemcell.extract(exclude: 'image') do |extracted_stemcell_dir|
        Dir.chdir(extracted_stemcell_dir) do
          FileUtils.touch('image', verbose: true)
          File.write('stemcell.MF', Psych.dump(manifest))
          Rake::FileUtilsExt.sh("sudo tar cvzf #{path} *")
        end
      end
    end

    def path
      stemcell_name = adjust_hvm_name(File.basename(@stemcell.path))
      File.join(File.dirname(@stemcell.path), "light-#{stemcell_name}")
    end

    private

    # this method has heavy side effects
    def manifest
      manifest = Bosh::Common::DeepCopy.copy(@stemcell.manifest)
      manifest['name'] = adjust_hvm_name(manifest['name'])
      manifest['cloud_properties']['name'] = adjust_hvm_name(manifest['cloud_properties']['name'])

      ami_collection = AmiCollection.new(@stemcell, @regions, @virtualization_type)

      # Light stemcell contains AMIs for all regions
      # so that CPI can pick one based on its configuration
      manifest['cloud_properties']['ami'] = ami_collection.publish
      manifest
    end

    def adjust_hvm_name(name)
      @virtualization_type == HVM_VIRTUALIZATION ? name.gsub("xen", "xen-hvm") : name
    end
  end
end
