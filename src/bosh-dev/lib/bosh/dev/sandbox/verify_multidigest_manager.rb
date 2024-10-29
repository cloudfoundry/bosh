require 'bosh/dev/sandbox/artifact_installer'

module Bosh::Dev::Sandbox
  class VerifyMultidigestManager
    def self.install
      installer.install
    end

    def self.executable_path
      installer.executable_path
    end

    def self.installer
      @installer ||=
        ArtifactInstaller.new(
          File.join('tmp', 'verify-multidigest'),
          'verify-multidigest',
          {
            version: '0.0.156',
            darwin_sha256: '4450a58db4c3df9a522299525ab70eaf2aee94f74fc2404bc28dea1068c094d6',
            linux_sha256: 'f72a33761540d010c136d020038e764d04ddc9a1ee71ffd2367304f18ba550d3',
            bucket_name: 'verify-multidigest',
          }
        )
    end

    private_class_method :installer
  end
end
