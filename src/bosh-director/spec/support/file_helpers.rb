module Support
  module FileHelpers
    class DeploymentDirectory
      attr_reader :path, :artifacts_dir, :tarballs

      def initialize
        @path = Dir.mktmpdir('deployment-path')
      end

      def add_file(filepath, contents = nil)
        full_path = File.join(path, filepath)
        FileUtils.mkdir_p(File.dirname(full_path))

        if contents
          File.open(full_path, 'w') { |f| f.write(contents) }
        else
          FileUtils.touch(full_path)
        end

        full_path
      end
    end

    def configure_fake_config_files(config_path)
      FakeFS::FileSystem.clone(config_path)
      FileUtils.mkdir_p('/path/to')
      File.write('/path/to/server_ca_path','server_ca_path')
      File.write('/path/to/client_ca_certificate_path','client_ca_certificate_path')
      File.write('/path/to/client_ca_private_key_path','client_ca_private_key_path')
    end
  end
end

RSpec.configure do |config|
  config.include(Support::FileHelpers)
end
