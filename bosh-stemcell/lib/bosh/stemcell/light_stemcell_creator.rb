require 'rake/file_utils'
require 'yaml'
require 'bosh/stemcell/ami'
require 'bosh/stemcell/stemcell'

module Bosh::Stemcell
  module LightStemcellCreator
    extend self

    def create(stemcell)
      Stemcell.new(create_light_aws_stemcell(stemcell))
    end

    def create_light_aws_stemcell(stemcell)
      stemcell.extract(exclude: 'image') do |extracted_stemcell_dir|
        Dir.chdir(extracted_stemcell_dir) do
          FileUtils.touch('image', verbose: true)

          File.open('stemcell.MF', 'w') do |out|
            Psych.dump(new_manifest(stemcell), out)
          end

          Rake::FileUtilsExt.sh("sudo tar cvzf #{light_stemcell_path(stemcell)} *")
        end
      end
      light_stemcell_path(stemcell)
    end

    def light_stemcell_path(stemcell)
      File.join(File.dirname(stemcell.path), light_stemcell_name(stemcell))
    end

    def light_stemcell_name(stemcell)
      "light-#{File.basename(stemcell.path)}"
    end

    def new_manifest(stemcell)
      ami = Bosh::Stemcell::Ami.new(stemcell)
      ami_id = ami.publish
      stemcell.manifest['cloud_properties']['ami'] = { ami.region => ami_id }
      stemcell.manifest
    end
  end
end
