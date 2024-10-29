require 'spec_helper'

describe 'cli: env', type: :integration do
  with_reset_sandbox_before_each

  before { bosh_runner.reset }

  it 'outputs status' do
    out = bosh_runner.run('env')
    expect(out).to include("Using environment '#{current_sandbox.director_url}'")
    expect(out).to match(/^Name\s*TestDirector\s*/)
    expect(out).to match(/^UUID\s*deadbeef\s*/)
    expect(out).to match(/^Version\s*0\.0\.0 .*/)
    expect(out).to match(%r{^Director Stemcell\s*\S*/\S*\s*})
    expect(out).to match(/^CPI\s*test-cpi\s*/)
    expect(out).to match(/^User\s*test\s*/)
    features = []
    features << 'config_server: disabled'
    features << 'local_dns: disabled'
    features << 'snapshots: enabled'
    features_regex = /Features\s*#{features.join('\s*')}/m

    expect(out).to match(features_regex)
    expect(out).to include('Succeeded')
  end
end
