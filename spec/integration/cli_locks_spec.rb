require 'spec_helper'

describe 'cli: locks', type: :integration do
  with_reset_sandbox_before_each

  context 'when a deployment is in progress' do
    before do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['update']['canary_watch_time'] = 6000
      deploy_from_scratch(manifest_hash: manifest_hash, no_track: true)
    end

    it 'lists a deployment lock' do
      output = bosh_runner.run_until_succeeds('locks', number_of_retries: 30)
      expect(output).to match(/\s*\|\s*deployment\s*\|\s*simple\s*\|/)
    end
  end

  context 'when nothing is in progress' do
    it 'returns no locks' do
      target_and_login
      expect_output('locks', 'No locks')
    end
  end
end
