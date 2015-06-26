require "spec_helper"

describe Bosh::Cli::Command::Base do
  describe Bosh::Cli::Command::JobRename do
    before do
      allow(Bosh::Cli::Client::Director).to receive(:new).and_return(director)
    end

    let(:director) { instance_double('Bosh::Cli::Client::Director', get_status: {}) }
    let(:job_rename) { Bosh::Cli::Command::JobRename.new }
    before { job_rename.add_option(:config, config_file) }
    let(:config_file) { Tempfile.new('rename-spec') }
    after { FileUtils.rm_rf(config_file) }

    it "should rename the job" do
      expect(director).to receive(:rename_job).and_return([:done, ""])

      allow(job_rename).to receive(:confirmed?).and_return(true)
      allow(job_rename).to receive(:auth_required)
      allow(job_rename).to receive(:show_current_state)
      manifest = Bosh::Cli::Manifest.new(old_manifest, director)
      manifest.load
      allow(job_rename).to receive(:prepare_deployment_manifest).and_return(manifest)
      allow(job_rename).to receive(:sanity_check_job_rename)
      job_rename.rename("old_name", "new_name")
    end

    it "should raise exception on additional changes to manifest" do
      allow(director).to receive(:get_deployment) { { "manifest" => File.read(old_manifest) } }

      expect {
        job_rename.sanity_check_job_rename(
          new_extra_changes_manifest, "old_job", "new_job")
      }.to raise_error(Bosh::Cli::CliError, /cannot have any other changes/)
    end

    it "should raise exception if new manifest removed some properties" do
      allow(director).to receive(:get_deployment) { { "manifest" => File.read(old_manifest) } }

      expect {
        job_rename.sanity_check_job_rename(new_manifest_with_some_deletions, "old_job", "new_job")
      }.to raise_error(Bosh::Cli::CliError, /cannot have any other changes/)
    end

    it "should raise exception if deployment is not updated with new job name" do
      expect {
        job_rename.sanity_check_job_rename(new_missing_new_job, "old_job", "new_job")
      }.to raise_error(Bosh::Cli::CliError, /include the new job/)
    end

    it "should raise exception if old job name does not exist in manifest" do
      allow(director).to receive(:get_deployment) { { "manifest" => File.read(old_manifest) } }

      expect {
        job_rename.sanity_check_job_rename(new_extra_changes_manifest, "non_existent_job", "new_job")
      }.to raise_error(Bosh::Cli::CliError, /non existent job/)
    end

    it "should raise exception if 2 jobs are changed in manifest" do
      allow(director).to receive(:get_deployment) { { "manifest" => File.read(old_manifest) } }
      expect {
        job_rename.sanity_check_job_rename(new_extra_job_rename_manifest, "old_job", "new_job")
      }.to raise_error(Bosh::Cli::CliError, /Cannot rename more than one job/)
    end

    def old_manifest
      spec_asset("manifests/old_manifest.yml")
    end

    def new_manifest_with_some_deletions
      manifest = Bosh::Cli::Manifest.new(spec_asset("manifests/new_manifest_with_some_deletions.yml"), director)
      manifest.load
      manifest
    end

    def new_manifest_yaml
      File.read(spec_asset("manifests/new_manifest.yml"))
    end

    def new_extra_changes_manifest
      manifest = Bosh::Cli::Manifest.new(spec_asset("manifests/new_extra_changes_manifest.yml"), director)
      manifest.load
      manifest
    end

    def new_extra_job_rename_manifest
      manifest = Bosh::Cli::Manifest.new(spec_asset("manifests/new_extra_job_rename_manifest.yml"), director)
      manifest.load
      manifest
    end

    def new_missing_new_job
      manifest = Bosh::Cli::Manifest.new(spec_asset("manifests/new_manifest_missing_new_job.yml"), director)
      manifest.load
      manifest
    end
  end
end
