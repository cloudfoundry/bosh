require "spec_helper"

describe "with release, stemcell and failed deployment" do

  let(:deployment_manifest) { with_deployment }
  let(:failed_deployment_result) do
    bosh("deployment #{deployment_manifest.to_path}").should succeed
    bosh("deploy", :on_error => :return)
  end

  before(:all) do
    requirement stemcell
    requirement release

    load_deployment_spec
    use_canaries(1)
    use_pool_size(2)
    use_job_instances(2)
    use_failing_job
  end

  after(:all) do
    bosh("delete deployment #{spec.fetch('properties', {}).fetch('name', 'bat')}")
    deployment_manifest.delete
    cleanup release
    cleanup stemcell
  end

  it "should use a canary" do
    # possibly check for:
    # Error 400007: `batlight/0' is not running after update
    failed_deployment_result.should_not succeed

    events(get_task_id(failed_deployment_result.output, "error")).each do |event|
      if event["stage"] == "Updating job"
        event["task"].should_not match %r{^batlight/1}
      end
    end
  end
end