require 'integration_support/artifact_installer'

module IntegrationSupport
  class GnatsdManager
    def self.install
      installer.install
    end

    def self.executable_path
      installer.executable_path
    end

    def self.installer
      @installer ||=
        ArtifactInstaller.new(
          File.join('tmp', 'gnatsd'),
          'gnatsd',
          {
            version: '1.3.0-bosh.10',
            darwin_sha256: 'fac87b6b9b46830551f32f22930a61e2162edf025304f0f2ce7282b4350003f7',
            linux_sha256: 'e5362a7c88ed92d4f4263b1b725e901fe29da220c3548e37570793776b5f6d51',
            bucket_name: 'bosh-gnatsd',
          }
        )
    end

    private_class_method :installer
  end
end
