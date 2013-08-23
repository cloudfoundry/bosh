require 'spec_helper'

describe 'deployment job control' do
  include IntegrationExampleGroup

  before do
    deploy_simple
  end

  it 'restarts a job' do
    expect(run_bosh('restart foobar 0')).to match %r{foobar/0 has been restarted}
  end

  it 'recreates a job' do
    expect(run_bosh('recreate foobar 1')).to match %r{foobar/1 has been recreated}
  end
end