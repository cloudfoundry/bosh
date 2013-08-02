require 'rake/file_utils'
require 'yaml'
require 'bosh/stemcell/ami'

module Bosh::Stemcell::Aws
  class LightStemcell
    def initialize(stemcell)
      @stemcell = stemcell
    end

    def write_archive
      stemcell.extract(exclude: 'image') do |extracted_stemcell_dir|
        Dir.chdir(extracted_stemcell_dir) do
          FileUtils.touch('image', verbose: true)

          File.open('stemcell.MF', 'w') do |out|
            Psych.dump(new_manifest, out)
          end

          Rake::FileUtilsExt.sh("sudo tar cvzf #{path} *")
        end
      end
    end

    def path
      File.join(File.dirname(stemcell.path), "light-#{File.basename(stemcell.path)}")
    end

    private

    attr_reader :stemcell

    def new_manifest
      ami = Bosh::Stemcell::Ami.new(stemcell)
      ami_id = ami.publish
      stemcell.manifest['cloud_properties']['ami'] = { ami.region => ami_id }
      stemcell.manifest
    end
  end
end
