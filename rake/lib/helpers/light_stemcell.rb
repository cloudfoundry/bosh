module Bosh
  module Helpers
    class LightStemcell
      def initialize(ami)
        @ami = ami
      end

      def publish(ami_id)
        ami.extract_stemcell(exclude: 'image') do |tmp_dir, stemcell_properties|
          stemcell_properties["cloud_properties"]["ami"] = { ami.region => ami_id }

          FileUtils.touch("#{tmp_dir}/image")

          File.open("#{tmp_dir}/stemcell.MF", 'w') do |out|
            Psych.dump(stemcell_properties, out)
          end

          light_stemcell_name = File.dirname(ami.stemcell_tgz) + "/light-" + File.basename(ami.stemcell_tgz)
          Dir.chdir(tmp_dir) do
            Rake::FileUtilsExt.sh("tar cvzf #{light_stemcell_name} *")
          end
        end
      end

      private
      attr_reader :ami
    end
  end
end
