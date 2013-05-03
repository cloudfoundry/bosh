require 'spec_helper'

describe 'Bosh::Spec::IntegrationTest::CliUsage property management' do
  include IntegrationExampleGroup

  describe 'property management' do

    it 'can get/set/delete deployment properties' do
      release_filename = spec_asset('valid_release.tgz')
      deployment_manifest = yaml_file(
        'minimal', Bosh::Spec::Deployments.minimal_manifest)

      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh('login admin admin')
      run_bosh("upload release #{release_filename}")

      run_bosh('deploy')

      run_bosh('set property foo bar').should =~ regexp(
        "Property `foo' set to `bar'")
      run_bosh('get property foo').should =~ regexp(
        "Property `foo' value is `bar'")
      run_bosh('set property foo baz').should =~ regexp(
        "Property `foo' set to `baz'")
      run_bosh('unset property foo').should =~ regexp(
        "Property `foo' has been unset")

      run_bosh('set property nats.user admin')
      run_bosh('set property nats.password pass')

      props = run_bosh('properties --terse')
      props.should =~ regexp("nats.user\tadmin")
      props.should =~ regexp("nats.password\tpass")
    end

  end
end
