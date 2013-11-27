require 'bosh/core/shell'
require 'bosh/dev/uri_provider'

module Bosh::Dev
  class ReleaseChanges
    def initialize(build_number, upload_adapter, download_adapter)
      @build_number = build_number
      @upload_adapter = upload_adapter
      @download_adapter = download_adapter
    end

    def stage
      patch_file = Tempfile.new("#{@build_number}-final-release")
      shell = Bosh::Core::Shell.new

      shell.run('git add -A :/')
      shell.run("git diff --staged > #{patch_file.path}")

      @upload_adapter.upload(bucket_name: Bosh::Dev::UriProvider::RELEASE_PATCHES_BUCKET,
                             key: "#{@build_number}-final-release.patch",
                             body: patch_file,
                             public: true)
    end

    def promote
      patch_uri = Bosh::Dev::UriProvider.release_patches_uri('tmp/build_patches', "#{@build_number}-final-release.patch")
      patch_file = Tempfile.new('1234-final-release')
      @download_adapter.download(patch_uri, patch_file.path)

      shell = Bosh::Core::Shell.new

      shell.run("git apply #{patch_file.path}")
      shell.run("git commit -m 'Adding final release for build #{@build_number}'")
    end
  end
end
