require 'system/spec_helper'

describe 'with release, stemcell and failed deployment' do
  let(:deployment_manifest_bad) do
    use_failing_job
    with_deployment
  end

  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
  end

  before do
    load_deployment_spec
    use_canaries(1)
    use_pool_size(2)
    use_job_instances(2)
  end

  after do
    bosh("delete deployment #{deployment_name}")
    deployment_manifest_bad.delete
  end

  context 'A brand new deployment' do
    it 'should stop the deployment if the canary fails' do
      bosh_safe("deployment #{deployment_manifest_bad.to_path}").should succeed
      failed_deployment_result = bosh('deploy', on_error: :return)

      # possibly check for:
      # Error 400007: `batlight/0' is not running after update
      failed_deployment_result.should_not succeed

      events(get_task_id(failed_deployment_result.output, 'error')).each do |event|
        event['task'].should_not match(/^batlight\/1/) if event['stage'] == 'Updating job'
      end
    end
  end

  context 'A deployment already exists' do
    it 'should stop the deployment if the canary fails' do
      deployment_manifest_good = with_deployment
      bosh_safe("deployment #{deployment_manifest_good.to_path}").should succeed
      bosh_safe('deploy').should succeed

      bosh_safe("deployment #{deployment_manifest_bad.to_path}").should succeed

      # possibly check for:
      # Error 400007: `batlight/0' is not running after update
      failed_deployment_result = bosh_safe('deploy')
      failed_deployment_result.should_not succeed

      events(get_task_id(failed_deployment_result.output, 'error')).each do |event|
        event['task'].should_not match(/^batlight\/1/) if event['stage'] == 'Updating job'
      end
    end
  end
end
