require 'spec_helper'

describe 'cli: deployment prerequisites', type: :integration do
  with_reset_sandbox_before_each

  before { bosh_runner.reset }

  it 'requires deployment path to be provided' do
    expect(bosh_runner.run('deploy', failure_expected: true)).to match(/the required argument `PATH` was not provided/)
  end
end
