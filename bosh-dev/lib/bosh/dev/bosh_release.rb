require 'rake'
require 'bosh/dev/bosh_cli_session'
require 'bosh/core/shell'
require 'bosh/dev/uri_provider'

module Bosh::Dev
  class ReleaseCreator
    def initialize(cli_session)
      @cli_session = cli_session
    end

    def create
      Dir.chdir('release') do
        output = @cli_session.run_bosh("create release --force --final --with-tarball")
        output.scan(/Release tarball\s+\(.+\):\s+(.+)$/).first.first
      end
    end
  end

  class BoshRelease
    def self.build
      bosh_cli_session = BoshCliSession.new
      release_creator = ReleaseCreator.new(bosh_cli_session)
      new(release_creator)
    end

    def initialize(release_creator)
      @release_creator = release_creator
    end

    def tarball_path
      @release_creator.create
    end
  end

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
                            key:"#{@build_number}-final-release.patch",
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
