module Bosh
  module Cli

    class Stemcell
      include Validation
      
      def initialize(tarball_path)
        @stemcell_file = File.expand_path(tarball_path, Dir.pwd)
      end

      def upload(api_client)
        return :invalid unless valid?
        api_client.upload_and_track("/stemcells", "application/x-compressed", @stemcell_file)
      end

      def perform_validation
        tmp_dir = Dir.mktmpdir

        step("File exists and readable", "Cannot find stemcell file #{@stemcell_file}", :fatal) do
          File.exists?(@stemcell_file) && File.readable?(@stemcell_file)
        end

        step("Extract tarball", "Cannot extract tarball #{@stemcell_file}", :fatal) do
          `tar -C #{tmp_dir} -xzf #{@stemcell_file} &> /dev/null`
          $?.exitstatus == 0
        end

        manifest_file = File.expand_path("stemcell.MF", tmp_dir) 

        step("Manifest exists", "Cannot find stemcell manifest", :fatal) do
          File.exists?(manifest_file)
        end

        manifest = YAML.load_file(manifest_file)

        step("Stemcell properties", "Manifest should contain valid name, version and cloud properties") do
          manifest.is_a?(Hash) && manifest.has_key?("name") && manifest.has_key?("version") &&
            manifest.has_key?("cloud_properties") &&
            manifest["name"].is_a?(String) && manifest["version"].is_a?(Integer) &&
            manifest["cloud_properties"].is_a?(Hash)
        end

        step("Stemcell image file", "Stemcell image file is missing") do
          File.exists?(File.expand_path("image", tmp_dir))
        end
      ensure
        FileUtils.rm_rf(tmp_dir)
      end        
    end

  end
end
