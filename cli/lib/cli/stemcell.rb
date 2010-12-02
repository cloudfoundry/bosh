module Bosh
  module Cli

    class Stemcell
      include Validation
      
      def initialize(tarball_path)
        @stemcell_file = File.expand_path(tarball_path, Dir.pwd)
      end

      #TODO: this is very similar to Release#upload, can be refactored to module
      def upload(api_client)
        return [ false, "Stemcell is invalid, please fix and verify it before uploading" ] unless valid?

        status, body, headers = api_client.post("/stemcells", "application/x-compressed", File.read(@stemcell_file))
        location = headers["Location"]

        scheduled = status == 302

        if scheduled
          if location !~ /^.+(\d+)\/?$/ # Doesn't look like we received URI
            return [ false, "Stemcell uploaded but director doesn't support stemcell creation progress tracking"]
          end

          poll_result = api_client.poll_job_status(location) do |polls, status|
            yield(polls, status) if block_given?
          end

          case poll_result
          when :done: [ true, "Stemcell successfully uploaded and updated" ]
          when :timeout: [ false, "Uploaded but timed out while tracking creation status" ]
          when :error: [ false, "Uploaded but received an error while tracking creation status" ]
          end
        else
          [ false, "Cannot upload stemcell: #{status} #{body}" ]
        end
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
      end        
    end

  end
end
