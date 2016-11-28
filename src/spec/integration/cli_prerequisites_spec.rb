require 'spec_helper'

describe 'cli: deployment prerequisites', type: :integration do
  with_reset_sandbox_before_each

  before { bosh_runner.reset }

  it 'requires target and login' do
    expect(bosh_runner.run('deploy', :failure_expected => true)).to match(/Please choose target first/)
    bosh_runner.run("target #{current_sandbox.director_url}")
    expect(bosh_runner.run('deploy', :failure_expected => true)).to match(/Please log in first/)
  end

  it 'requires deployment to be chosen' do
    target_and_login
    expect(bosh_runner.run('deploy', :failure_expected => true)).to match(/Please choose deployment first/)
  end
end
