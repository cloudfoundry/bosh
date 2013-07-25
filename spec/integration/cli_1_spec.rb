require 'spec_helper'

describe Bosh::Spec::IntegrationTest::CliUsage do
  include IntegrationExampleGroup

  it 'has help message', no_reset: true do
    run_bosh('help')
    $?.should == 0
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
    out = run_bosh('target http://localhost', nil, failure_expected: true)
    out.should =~ /cannot access director/i

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
    out = run_bosh('deployment vmforce', nil, failure_expected: true)
    out.should =~ regexp('Please upgrade your deployment manifest')
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
    out.should =~ regexp('test2')
  end

  it 'keeps track of user associated with target' do
    run_bosh("target http://localhost:#{current_sandbox.director_port} foo")
    run_bosh('login admin admin')

    run_bosh("target http://127.0.0.1:#{current_sandbox.director_port} bar")

    run_bosh('login admin admin')
    run_bosh('status').should =~ /user\s+admin/i

    run_bosh('target foo')
    run_bosh('status').should =~ /user\s+admin/i
  end

  it 'verifies a sample valid stemcell', no_reset: true do
    stemcell_filename = spec_asset('valid_stemcell.tgz')
    success = regexp("#{stemcell_filename}' is a valid stemcell")
    run_bosh("verify stemcell #{stemcell_filename}").should =~ success
  end

  it 'points to an error when verifying an invalid stemcell', no_reset: true do
    stemcell_filename = spec_asset('stemcell_invalid_mf.tgz')
    failure = regexp("`#{stemcell_filename}' is not a valid stemcell")
    run_bosh("verify stemcell #{stemcell_filename}", nil, failure_expected: true).should =~ failure
  end

  it 'uses cache when verifying stemcell for the second time', no_reset: true do
    stemcell_filename = spec_asset('valid_stemcell.tgz')
    run_1 = run_bosh("verify stemcell #{stemcell_filename}")
    run_2 = run_bosh("verify stemcell #{stemcell_filename}")

    run_1.should =~ /Manifest not found in cache, verifying tarball/
    run_1.should =~ /Writing manifest to cache/

    run_2.should =~ /Using cached manifest/
  end

  it 'does not allow purging when using non-default directory', no_reset: true do
    run_bosh('purge', nil, failure_expected: true).should =~ regexp('please remove manually')
  end

  it 'verifies a sample valid release', no_reset: true do
    release_filename = spec_asset('valid_release.tgz')
    out = run_bosh("verify release #{release_filename}")
    out.should =~ regexp("`#{release_filename}' is a valid release")
  end

  it 'points to an error on invalid release', no_reset: true do
    release_filename = spec_asset('release_invalid_checksum.tgz')
    out = run_bosh("verify release #{release_filename}", nil, failure_expected: true)
    out.should =~ regexp("`#{release_filename}' is not a valid release")
  end

  it 'requires login when talking to director', no_reset: true do
    run_bosh('properties', nil, failure_expected: true).should =~ /please choose target first/i
    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('properties', nil, failure_expected: true).should =~ /please log in first/i
  end

  it 'creates a user when correct target accessed' do
    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
    run_bosh('create user john pass').should =~ /user `john' has been created/i
  end

  it 'can log in as a freshly created user and issue commands' do
    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
    run_bosh('create user jane pass')
    run_bosh('login jane pass')

    success = /User `tester' has been created/i
    run_bosh('create user tester testpass').should =~ success
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
