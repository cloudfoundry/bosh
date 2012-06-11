# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::Command::Base do

  # TODO: this spec is not in line with the rest of them: it's testing command,
  # not the rename behavior. Logic should probably be extracted into JobRenamer
  # or something like that.
  describe Bosh::Cli::Command::JobRename do
    it "should rename the job" do
      mock_director = mock(Object)
      mock_director.should_receive(:rename_job).and_return([:done, ""])
      Bosh::Cli::Director.should_receive(:new).and_return(mock_director)

      job_rename = Bosh::Cli::Command::JobRename.new
      job_rename.stub(:confirmed?).and_return(true)
      job_rename.stub(:auth_required)
      job_rename.stub(:prepare_deployment_manifest).and_return(old_manifest_yaml)
      job_rename.stub(:sanity_check_job_rename)
      job_rename.rename("old_name", "new_name")
    end

    it "should raise exception on additional changes to manifest" do
      mock_director = mock(Object)
      mock_director.stub(:get_deployment) { { "manifest" => old_manifest_yaml } }
      Bosh::Cli::Director.should_receive(:new).and_return(mock_director)

      job_rename = Bosh::Cli::Command::JobRename.new

      lambda {
        job_rename.sanity_check_job_rename(new_extra_changes_manifest, "old_job", "new_job")
      }.should raise_error(Bosh::Cli::CliExit, /cannot have any other changes/)
    end

    it "should raise exception if new manifest removed some properties" do
      mock_director = mock(Object)
      mock_director.stub(:get_deployment) { { "manifest" => old_manifest_yaml } }
      Bosh::Cli::Director.should_receive(:new).and_return(mock_director)

      job_rename = Bosh::Cli::Command::JobRename.new

      lambda {
        job_rename.sanity_check_job_rename(new_manifest_with_some_deletions, "old_job", "new_job")
      }.should raise_error(Bosh::Cli::CliExit, /cannot have any other changes/)
    end

    it "should raise exception if deployment is not updated with new job name" do
      job_rename = Bosh::Cli::Command::JobRename.new

      lambda {
        job_rename.sanity_check_job_rename(new_missing_new_job, "old_job", "new_job")
      }.should raise_error(Bosh::Cli::CliExit, /include the new job/)
    end

    it "should raise exception if old job name does not exist in manifest" do
      mock_director = mock(Object)
      mock_director.stub(:get_deployment) { { "manifest" => old_manifest_yaml } }
      Bosh::Cli::Director.should_receive(:new).and_return(mock_director)

      job_rename = Bosh::Cli::Command::JobRename.new

      lambda {
        job_rename.sanity_check_job_rename(new_extra_changes_manifest, "non_existent_job", "new_job")
      }.should raise_error(Bosh::Cli::CliExit, /non existent job/)
    end

    it "should raise exception if 2 jobs are changed in manifest" do
      mock_director = mock(Object)
      mock_director.stub(:get_deployment) { { "manifest" => old_manifest_yaml } }
      Bosh::Cli::Director.should_receive(:new).and_return(mock_director)

      job_rename = Bosh::Cli::Command::JobRename.new

      lambda {
        job_rename.sanity_check_job_rename(new_extra_job_rename_manifest, "old_job", "new_job")
      }.should raise_error(Bosh::Cli::CliExit, /Cannot rename more than one job/)
    end

    def old_manifest_yaml
      <<-eos
      ---
      name: test
      resource_pools:
      - name: rp
      networks:
      - name: default
      jobs:
      - name: job1
        template: xyz
        networks:
        - name: default
      - name: old_job
        template: xyz
        networks:
        - name: default
      eos
    end

    def new_manifest_with_some_deletions
      <<-eos
      ---
      name: test
      resource_pools:
      - name: rp
      networks:
      - name: default
      jobs:
      - name: job1
        networks:
        - name: default
      - name: new_job
        template: xyz
        networks:
        - name: default
      eos
    end

    def new_manifest_yaml
      <<-eos
      ---
      name: test
      networks:
      - name: default
      resource_pools:
      - name: rp
      jobs:
      - name: job1
        template: xyz
        networks:
        - name: default
      - name: new_job
        template: xyz
        networks:
        - name: default
      eos
    end

    def new_extra_changes_manifest
      <<-eos
      ---
      name: test
      networks:
      - name: default
      resource_pools:
      - name: rp
      jobs:
      - name: job1
        template: xyz
        networks:
        - name: default
      - name: new_job
        template: changed_templated_causing_failure
        networks:
        - name: default
      eos
    end

    def new_extra_job_rename_manifest
      <<-eos
      ---
      name: test
      networks:
      - name: default
      resource_pools:
      - name: rp
      jobs:
      - name: new_job1
        template: xyz
        networks:
        - name: default
      - name: new_job
        template: changed_templated_causing_failure
        networks:
        - name: default
      eos
    end

    def new_missing_new_job
      <<-eos
      ---
      name: test
      networks:
      - name: default
      resource_pools:
      - name: rp
      jobs:
      - name: job1
        template: xyz
        networks:
        - name: default
      - name: old_job
        template: xyz
        networks:
        - name: default
      eos
    end
  end
end
