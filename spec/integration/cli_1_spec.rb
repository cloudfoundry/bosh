require 'spec_helper'

describe 'cli: 1', type: :integration do
  with_reset_sandbox_before_each

  it 'has help message', no_reset: true do
    _, exit_code = bosh_runner.run('help', return_exit_code: true)
    expect(exit_code).to eq(0)
  end

  it 'shows status', no_reset: true do
    expect_output('status', <<-OUT)
     Config
                #{BOSH_CONFIG}

     Director
       not set

     Deployment
       not set
    OUT
  end

  it 'whines on inaccessible target', no_reset: true do
    out = bosh_runner.run('target http://localhost', failure_expected: true)
    expect(out).to match(/cannot access director/i)

    expect_output('target', <<-OUT)
      Target not set
    OUT
  end

  it 'sets correct target' do
    expect_output("target http://localhost:#{current_sandbox.director_port}", <<-OUT)
      Target set to `Test Director'
    OUT

    message = "http://localhost:#{current_sandbox.director_port}"
    expect_output('target', message)
    Dir.chdir('/tmp') do
      expect_output('target', message)
    end
  end

  it 'does not let user use deployment with target anymore (needs uuid)', no_reset: true do
    out = bosh_runner.run('deployment vmforce', failure_expected: true)
    expect(out).to match(regexp('Please upgrade your deployment manifest'))
  end

  it 'remembers deployment when switching targets', no_reset: true do
    bosh_runner.run("target http://localhost:#{current_sandbox.director_port}")
    bosh_runner.run('deployment test2')

    expect_output("target http://localhost:#{current_sandbox.director_port}", <<-OUT)
      Target already set to `Test Director'
    OUT

    expect_output("target http://127.0.0.1:#{current_sandbox.director_port}", <<-OUT)
      Target set to `Test Director'
    OUT

    expect_output('deployment', 'Deployment not set')
    bosh_runner.run("target http://localhost:#{current_sandbox.director_port}")
    out = bosh_runner.run('deployment')
    expect(out).to match(regexp('test2'))
  end

  it 'keeps track of user associated with target' do
    bosh_runner.run("target http://localhost:#{current_sandbox.director_port} foo")
    bosh_runner.run('login admin admin')

    bosh_runner.run("target http://127.0.0.1:#{current_sandbox.director_port} bar")

    bosh_runner.run('login admin admin')
    expect(bosh_runner.run('status')).to match(/user\s+admin/i)

    bosh_runner.run('target foo')
    expect(bosh_runner.run('status')).to match(/user\s+admin/i)
  end

  it 'verifies a sample valid stemcell', no_reset: true do
    stemcell_filename = spec_asset('valid_stemcell.tgz')
    success = regexp("#{stemcell_filename}' is a valid stemcell")
    expect(bosh_runner.run("verify stemcell #{stemcell_filename}")).to match(success)
  end

  it 'points to an error when verifying an invalid stemcell', no_reset: true do
    stemcell_filename = spec_asset('stemcell_invalid_mf.tgz')
    failure = regexp("`#{stemcell_filename}' is not a valid stemcell")
    expect(bosh_runner.run("verify stemcell #{stemcell_filename}", failure_expected: true)).to match(failure)
  end

  it 'verifies a sample valid release', no_reset: true do
    release_filename = spec_asset('valid_release.tgz')
    out = bosh_runner.run("verify release #{release_filename}")
    expect(out).to match(regexp("`#{release_filename}' is a valid release"))
  end

  it 'points to an error on invalid release', no_reset: true do
    release_filename = spec_asset('release_invalid_checksum.tgz')
    out = bosh_runner.run("verify release #{release_filename}", failure_expected: true)
    expect(out).to match(regexp("`#{release_filename}' is not a valid release"))
  end

  it 'requires login when talking to director', no_reset: true do
    expect(bosh_runner.run('properties', failure_expected: true)).to match(/please choose target first/i)
    bosh_runner.run("target http://localhost:#{current_sandbox.director_port}")
    expect(bosh_runner.run('properties', failure_expected: true)).to match(/please log in first/i)
  end

  it 'can log in as a user, create another user and delete created user' do
    bosh_runner.run("target http://localhost:#{current_sandbox.director_port}")
    bosh_runner.run('login admin admin')
    expect(bosh_runner.run('create user john john-pass')).to match(/User `john' has been created/i)

    expect(bosh_runner.run('login john john-pass')).to match(/Logged in as `john'/i)
    expect(bosh_runner.run('create user jane jane-pass')).to match(/user `jane' has been created/i)
    bosh_runner.run('logout')

    expect(bosh_runner.run('login jane jane-pass')).to match(/Logged in as `jane'/i)
    expect(bosh_runner.run('delete user john')).to match(/User `john' has been deleted/i)
    bosh_runner.run('logout')

    expect(bosh_runner.run('login john john-pass', failure_expected: true)).to match(/Cannot log in as `john'/i)
    expect(bosh_runner.run('login jane jane-pass')).to match(/Logged in as `jane'/i)
  end

  it 'cannot log in if password is invalid' do
    bosh_runner.run("target http://localhost:#{current_sandbox.director_port}")
    bosh_runner.run('login admin admin')
    bosh_runner.run('create user jane pass')
    bosh_runner.run('logout')
    expect_output('login jane foo', <<-OUT)
      Cannot log in as `jane'
    OUT
  end

  it 'returns just uuid when `status --uuid` is called' do
    bosh_runner.run("target http://localhost:#{current_sandbox.director_port}")
    expect_output('status --uuid', <<-OUT)
#{Bosh::Dev::Sandbox::Main::DIRECTOR_UUID}
    OUT
  end
end
