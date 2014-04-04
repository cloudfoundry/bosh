require 'spec_helper'

describe 'cli: locks', type: :integration do
  with_reset_sandbox_before_each

  context 'when a deployment is in progress' do
    before(:each) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['update']['canary_watch_time'] = 6000
      deploy_simple(manifest_hash: manifest_hash, no_track: true)
    end

    it 'lists a deployment lock' do
      sleep 5 # wait for the director to establish a lock on the concurrent deploy

      output = run_bosh('locks')
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
