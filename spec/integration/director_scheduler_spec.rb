require 'spec_helper'

describe Bosh::Spec::IntegrationTest::DirectorScheduler do
  include IntegrationExampleGroup

  before do
    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')

    run_bosh('reset release', TEST_RELEASE_DIR)
    run_bosh('create release --force', TEST_RELEASE_DIR)
    run_bosh('upload release', TEST_RELEASE_DIR)

    run_bosh("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['persistent_disk'] = 20480
    deployment_manifest = yaml_file('simple', deployment_hash)
    run_bosh("deployment #{deployment_manifest.path}")

    run_bosh('deploy')
  end

  def snapshots
    Dir[File.join(current_sandbox.agent_tmp_path, 'snapshots', '*')]
  end

  it "snapshots a disk on a defined schedule" do
    current_sandbox.start_scheduler

    30.times do
      break unless snapshots.empty?
      sleep 1
    end
    expect(snapshots).to_not be_empty
  end
end