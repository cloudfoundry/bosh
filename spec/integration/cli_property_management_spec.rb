require 'spec_helper'

describe 'cli: property management', type: :integration do
  with_reset_sandbox_before_each

  it 'can get/set/unset deployment properties' do
    manifest = Bosh::Spec::Deployments.simple_manifest
    manifest['jobs'] = []
    deploy_from_scratch(manifest_hash: manifest)

    expect(bosh_runner.run('set property foo bar')).to match /Property `foo' set to `bar'/
    expect(bosh_runner.run('get property foo')).to match /Property `foo' value is `bar'/
    expect(bosh_runner.run('set property foo baz')).to match /Property `foo' set to `baz'/
    expect(bosh_runner.run('unset property foo')).to match /Property `foo' has been unset/
    expect(bosh_runner.run('get property foo', failure_expected: true)).to match /Error 110003: Property `foo' not found/
    expect(bosh_runner.run('unset property foo', failure_expected: true)).to match /Error 110003: Property `foo' not found/

    bosh_runner.run('set property nats.user admin')
    bosh_runner.run('set property nats.password pass')

    props = bosh_runner.run('properties --terse')
    expect(props).to match /nats.user\tadmin/
    expect(props).to match /nats.password\tpass/
  end
end
