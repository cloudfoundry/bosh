require_relative '../spec_helper'

describe 'cli: env', type: :integration do
  with_reset_sandbox_before_each

  before { bosh_runner.reset }

  it 'outputs status' do
    out = bosh_runner.run('env')
    expect(out).to include("Using environment 'https://127.0.0.1:61004'")
    expect(out).to include("Succeeded")
  end
end
