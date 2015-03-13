require 'spec_helper'

describe 'cli: status', type: :integration do
  with_reset_sandbox_before_each

  it 'has help message', no_reset: true do
    _, exit_code = bosh_runner.run('help', return_exit_code: true)
    expect(exit_code).to eq(0)
  end

  it 'shows status', no_reset: true do
    expect_output('status', <<-OUT)
     Config
                #{ClientSandbox.bosh_config}

     Director
       not set

     Deployment
       not set
    OUT
  end

  it 'returns just uuid when `status --uuid` is called' do
    bosh_runner.run("target #{current_sandbox.director_url}")
    expect_output('status --uuid', <<-OUT)
#{Bosh::Dev::Sandbox::DirectorService::DIRECTOR_UUID}
    OUT
  end
end
