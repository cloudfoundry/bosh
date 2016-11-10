require_relative '../spec_helper'

describe 'cli: env', type: :integration do
  with_reset_sandbox_before_each

  before { bosh_runner.reset }

  it 'outputs status' do
    out = bosh_runner.run('env')
    expect(out).to include("Using environment '#{current_sandbox.director_url}'")
    expect(out).to include("Succeeded")
  end
end
