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

    def stub_config_file_reads(config_path)
      nats_config = YAML.safe_load(File.read(config_path))['nats']
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(nats_config['server_ca_path']).and_return('server_ca_path')
      allow(File).to receive(:read).with(nats_config['client_ca_certificate_path']).and_return('client_ca_certificate_path')
      allow(File).to receive(:read).with(nats_config['client_ca_private_key_path']).and_return('client_ca_private_key_path')
    end
  end
end

RSpec.configure do |config|
  config.include(Support::FileHelpers)
end
