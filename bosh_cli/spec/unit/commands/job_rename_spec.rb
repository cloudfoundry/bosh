# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::Command::Base do
  describe Bosh::Cli::Command::JobRename do
    it "should rename the job" do
      mock_director = double(Object)
      mock_director.should_receive(:rename_job).and_return([:done, ""])
      Bosh::Cli::Client::Director.should_receive(:new).and_return(mock_director)

      job_rename = Bosh::Cli::Command::JobRename.new
      job_rename.stub(:confirmed?).and_return(true)
      job_rename.stub(:auth_required)
      job_rename.stub(:prepare_deployment_manifest).and_return(old_manifest_yaml)
      job_rename.stub(:sanity_check_job_rename)
      job_rename.rename("old_name", "new_name")
    end

    it "should raise exception on additional changes to manifest" do
      mock_director = double(Object)
      mock_director.stub(:get_deployment) { { "manifest" => old_manifest_yaml } }
      Bosh::Cli::Client::Director.should_receive(:new).and_return(mock_director)

      job_rename = Bosh::Cli::Command::JobRename.new

      lambda {
        job_rename.sanity_check_job_rename(
          new_extra_changes_manifest, "old_job", "new_job")
      }.should raise_error(Bosh::Cli::CliError, /cannot have any other changes/)
    end

    it "should raise exception if new manifest removed some properties" do
      mock_director = double(Object)
      mock_director.stub(:get_deployment) { { "manifest" => old_manifest_yaml } }
      Bosh::Cli::Client::Director.should_receive(:new).and_return(mock_director)

      job_rename = Bosh::Cli::Command::JobRename.new

      lambda {
        job_rename.sanity_check_job_rename(new_manifest_with_some_deletions, "old_job", "new_job")
      }.should raise_error(Bosh::Cli::CliError, /cannot have any other changes/)
    end

    it "should raise exception if deployment is not updated with new job name" do
      job_rename = Bosh::Cli::Command::JobRename.new

      lambda {
        job_rename.sanity_check_job_rename(new_missing_new_job, "old_job", "new_job")
      }.should raise_error(Bosh::Cli::CliError, /include the new job/)
    end

    it "should raise exception if old job name does not exist in manifest" do
      mock_director = double(Object)
      mock_director.stub(:get_deployment) { { "manifest" => old_manifest_yaml } }
      Bosh::Cli::Client::Director.should_receive(:new).and_return(mock_director)

      job_rename = Bosh::Cli::Command::JobRename.new

      lambda {
        job_rename.sanity_check_job_rename(new_extra_changes_manifest, "non_existent_job", "new_job")
      }.should raise_error(Bosh::Cli::CliError, /non existent job/)
    end

    it "should raise exception if 2 jobs are changed in manifest" do
      mock_director = double(Object)
      mock_director.stub(:get_deployment) { { "manifest" => old_manifest_yaml } }
      Bosh::Cli::Client::Director.should_receive(:new).and_return(mock_director)

      job_rename = Bosh::Cli::Command::JobRename.new

      lambda {
        job_rename.sanity_check_job_rename(new_extra_job_rename_manifest, "old_job", "new_job")
      }.should raise_error(Bosh::Cli::CliError, /Cannot rename more than one job/)
    end

    def old_manifest_yaml
      File.read(spec_asset("manifests/old_manifest.yml"))
    end

    def new_manifest_with_some_deletions
      File.read(spec_asset("manifests/new_manifest_with_some_deletions.yml"))
    end

    def new_manifest_yaml
      File.read(spec_asset("manifests/new_manifest.yml"))
    end

    def new_extra_changes_manifest
      File.read(spec_asset("manifests/new_extra_changes_manifest.yml"))
    end

    def new_extra_job_rename_manifest
      File.read(spec_asset("manifests/new_extra_job_rename_manifest.yml"))
    end

    def new_missing_new_job
      File.read(spec_asset("manifests/new_manifest_missing_new_job.yml"))
    end
  end
end
