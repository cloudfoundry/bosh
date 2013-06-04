module Bosh
  module Helpers
    class LightStemcell
      def initialize(ami)
        @ami = ami
      end

      def publish(ami_id)
        ami.extract_stemcell(exclude: 'image') do |extracted_stemcell_dir, stemcell_properties|
          Dir.chdir(extracted_stemcell_dir) do
            stemcell_properties['cloud_properties']['ami'] = {ami.region => ami_id}

            FileUtils.touch('image')

            File.open('stemcell.MF', 'w') do |out|
              Psych.dump(stemcell_properties, out)
            end

            Rake::FileUtilsExt.sh("tar cvzf #{tgz_path} *")
          end
        end
      end

      private
      attr_reader :ami

      def tgz_path
        File.join(stemcell_dir, tgz_name)
      end

      def stemcell_dir
        File.dirname(ami.stemcell_tgz)
      end

      def tgz_name
        "light-#{File.basename(ami.stemcell_tgz)}"
      end
    end
  end
end
