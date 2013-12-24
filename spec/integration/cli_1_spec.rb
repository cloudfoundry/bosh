require 'spec_helper'

describe Bosh::Spec::IntegrationTest::CliUsage do
  include IntegrationExampleGroup

  it 'has help message', no_reset: true do
    run_bosh('help')
    expect($?).to be_success
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
    out = run_bosh('target http://localhost', failure_expected: true)
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
    out = run_bosh('deployment vmforce', failure_expected: true)
    expect(out).to match(regexp('Please upgrade your deployment manifest'))
  end

  it 'remembers deployment when switching targets', no_reset: true do
    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('deployment test2')

    expect_output("target http://localhost:#{current_sandbox.director_port}", <<-OUT)
      Target already set to `Test Director'
    OUT

    expect_output("target http://127.0.0.1:#{current_sandbox.director_port}", <<-OUT)
      Target set to `Test Director'
    OUT

    expect_output('deployment', 'Deployment not set')
    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    out = run_bosh('deployment')
    expect(out).to match(regexp('test2'))
  end

  it 'keeps track of user associated with target' do
    run_bosh("target http://localhost:#{current_sandbox.director_port} foo")
    run_bosh('login admin admin')

    run_bosh("target http://127.0.0.1:#{current_sandbox.director_port} bar")

    run_bosh('login admin admin')
    expect(run_bosh('status')).to match(/user\s+admin/i)

    run_bosh('target foo')
    expect(run_bosh('status')).to match(/user\s+admin/i)
  end

  it 'verifies a sample valid stemcell', no_reset: true do
    stemcell_filename = spec_asset('valid_stemcell.tgz')
    success = regexp("#{stemcell_filename}' is a valid stemcell")
    expect(run_bosh("verify stemcell #{stemcell_filename}")).to match(success)
  end

  it 'points to an error when verifying an invalid stemcell', no_reset: true do
    stemcell_filename = spec_asset('stemcell_invalid_mf.tgz')
    failure = regexp("`#{stemcell_filename}' is not a valid stemcell")
    expect(run_bosh("verify stemcell #{stemcell_filename}", failure_expected: true)).to match(failure)
  end

  it 'verifies a sample valid release', no_reset: true do
    release_filename = spec_asset('valid_release.tgz')
    out = run_bosh("verify release #{release_filename}")
    expect(out).to match(regexp("`#{release_filename}' is a valid release"))
  end

  it 'points to an error on invalid release', no_reset: true do
    release_filename = spec_asset('release_invalid_checksum.tgz')
    out = run_bosh("verify release #{release_filename}", failure_expected: true)
    expect(out).to match(regexp("`#{release_filename}' is not a valid release"))
  end

  it 'requires login when talking to director', no_reset: true do
    expect(run_bosh('properties', failure_expected: true)).to match(/please choose target first/i)
    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    expect(run_bosh('properties', failure_expected: true)).to match(/please log in first/i)
  end

  it 'creates a user when correct target accessed' do
    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
    expect(run_bosh('create user john pass')).to match(/user `john' has been created/i)
  end

  it 'can log in as a freshly created user and issue commands' do
    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
    run_bosh('create user jane pass')
    run_bosh('login jane pass')

    success = /User `tester' has been created/i
    expect(run_bosh('create user tester testpass')).to match(success)
  end

  it 'cannot log in if password is invalid' do
    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
    run_bosh('create user jane pass')
    run_bosh('logout')
    expect_output('login jane foo', <<-OUT)
      Cannot log in as `jane'
    OUT
  end
end
