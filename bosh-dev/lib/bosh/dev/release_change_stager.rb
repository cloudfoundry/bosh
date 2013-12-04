require 'tempfile'

require 'bosh/core/shell'
require 'bosh/dev/uri_provider'

module Bosh::Dev
  class ReleaseChangeStager
    def initialize(work_tree, build_number, upload_adapter)
      @build_number = build_number
      @upload_adapter = upload_adapter
      @work_tree = work_tree
    end

    def stage
      patch_file = Tempfile.new("#{@build_number}-final-release")
      shell = Bosh::Core::Shell.new

      git_dir = "#{@work_tree}/.git"
      shell.run("git --work-tree=#{@work_tree} --git-dir=#{git_dir} add -A :/")
      shell.run("git --work-tree=#{@work_tree} --git-dir=#{git_dir} diff --staged > #{patch_file.path}")

      @upload_adapter.upload(bucket_name: Bosh::Dev::UriProvider::RELEASE_PATCHES_BUCKET,
                             key: "#{@build_number}-final-release.patch",
                             body: patch_file,
                             public: true)
    end
  end
end
