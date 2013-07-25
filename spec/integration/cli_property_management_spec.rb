require 'spec_helper'

describe 'Bosh::Spec::IntegrationTest::CliUsage property management' do
  include IntegrationExampleGroup

  describe 'property management' do

    it 'can get/set/unset deployment properties' do
      release_filename = spec_asset('valid_release.tgz')
      deployment_manifest = yaml_file(
        'minimal', Bosh::Spec::Deployments.minimal_manifest)

      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh('login admin admin')
      run_bosh("upload release #{release_filename}")

      run_bosh('deploy')
      expect(run_bosh('set property foo bar')).to match /Property `foo' set to `bar'/
      expect(run_bosh('get property foo')).to match /Property `foo' value is `bar'/
      expect(run_bosh('set property foo baz')).to match /Property `foo' set to `baz'/
      expect(run_bosh('unset property foo')).to match /Property `foo' has been unset/
      expect(run_bosh('get property foo', nil, failure_expected: true)).to match /Error 110003: Property `foo' not found/
      expect(run_bosh('unset property foo', nil, failure_expected: true)).to match /Error 110003: Property `foo' not found/

      run_bosh('set property nats.user admin')
      run_bosh('set property nats.password pass')

      props = run_bosh('properties --terse')
      expect(props).to match /nats.user\tadmin/
      expect(props).to match /nats.password\tpass/
    end

  end
end
