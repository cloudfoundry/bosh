require 'spec_helper'

describe 'cli: locks', type: :integration do
  include Bosh::Spec::BlockingDeployHelper
  with_reset_sandbox_before_each

  context 'when a deployment is in progress' do
    it 'lists a deployment lock' do
      prepare_for_deploy

      with_blocking_deploy do
        output = bosh_runner.run_until_succeeds('locks', number_of_retries: 30)
        expect(output).to match(/\s*\|\s*deployment\s*\|\s*blocking\s*\|/)
      end
    end
  end
end
