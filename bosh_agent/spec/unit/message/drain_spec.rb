require 'spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::Drain do
  def set_state(state)
    state_file = Tempfile.new('agent-state')
    state_file.write(Psych.dump(state))
    state_file.close
    Bosh::Agent::Config.state = Bosh::Agent::State.new(state_file.path)
  end

  before do
    @nats = double

    Bosh::Agent::Config.logger   = Logger.new(StringIO.new)
    Bosh::Agent::Config.nats     = @nats
    Bosh::Agent::Config.agent_id = 'zb-agent'

    @base_dir = Bosh::Agent::Config.base_dir
  end

  it 'should receive drain type and an optional argument' do
    set_state({'a' => 1})
    handler = Bosh::Agent::Message::Drain.new(['shutdown'])
    handler.should be_kind_of Bosh::Agent::Message::Drain
  end

  it 'should handle shutdown drain type' do
    set_state({ 'job' => {'name' => 'cc', 'template' => 'cloudcontroller'} })

    bindir = File.join(@base_dir, 'jobs', 'cloudcontroller', 'bin')
    tmpdir = File.join(@base_dir, 'tmp')

    FileUtils.mkdir_p(bindir)
    FileUtils.mkdir_p(tmpdir)

    drain_script = File.join(bindir, 'drain')
    drain_out    = File.join(tmpdir, 'yay.out')

    File.open(drain_script, 'w') do |fh|
      fh.puts "#!/bin/bash\necho $@ > #{drain_out}\necho -n '10'"
    end

    handler = Bosh::Agent::Message::Drain.new(['shutdown'])
    FileUtils.chmod(0777, drain_script)

    @nats.should_receive(:publish).with('hm.agent.shutdown.zb-agent').and_yield
    handler.drain.should == 10

    File.read(drain_out).should == "job_shutdown hash_unchanged\n"
  end


  it 'should handle update drain type' do
    set_state(old_spec)

    bindir = File.join(@base_dir, 'jobs', 'cloudcontroller', 'bin')
    tmpdir = File.join(@base_dir, 'tmp')

    FileUtils.mkdir_p(bindir)
    FileUtils.mkdir_p(tmpdir)

    drain_script = File.join(bindir, 'drain')
    drain_out    = File.join(tmpdir, 'yay.out')

    File.open(drain_script, 'w') do |fh|
      fh.puts "#!/bin/bash\necho $@ > #{drain_out}\necho -n '10'"
    end
    FileUtils.chmod(0777, drain_script)

    @nats.should_not_receive(:publish).with('hm.agent.shutdown.zb-agent')

    handler = Bosh::Agent::Message::Drain.new(['update', new_spec])
    handler.drain.should == 10
  end


  it "should return 0 if it receives an update but doesn't have a previously applied job" do
    set_state({ })

    handler = Bosh::Agent::Message::Drain.new(['update', new_spec])
    @nats.should_not_receive(:publish).with('hm.agent.shutdown.zb-agent')
    handler.drain.should == 0
  end

  it 'should pass job update state to drain script' do
    set_state(old_spec)

    job_update_spec = new_spec
    job_update_spec['job']['sha1'] = 'some_sha1'

    handler = Bosh::Agent::Message::Drain.new(['update', job_update_spec])

    handler.stub(:drain_script_exists?).and_return(true)
    handler.stub(:run_drain_script).and_return(10)
    handler.should_receive(:run_drain_script).with('job_changed', 'hash_unchanged', ['mysqlclient'])
    handler.drain.should == 10
  end

  it 'should pass the name of updated packages to drain script' do
    set_state(old_spec)

    pkg_update_spec = new_spec
    pkg_update_spec['packages']['ruby']['sha1'] = 'some_other_sha1'

    handler = Bosh::Agent::Message::Drain.new(['update', pkg_update_spec])

    handler.stub(:drain_script_exists?).and_return(true)
    handler.stub(:run_drain_script).and_return(121)
    handler.should_receive(:run_drain_script).with('job_unchanged', 'hash_unchanged', ['mysqlclient', 'ruby'])
    handler.drain.should == 121
  end

  it 'raises if drain output is invalid' do
    set_state(old_spec)

    bindir = File.join(@base_dir, 'jobs', 'cloudcontroller', 'bin')
    tmpdir = File.join(@base_dir, 'tmp')

    FileUtils.mkdir_p(bindir)
    FileUtils.mkdir_p(tmpdir)

    drain_script = File.join(bindir, 'drain')
    drain_out    = File.join(tmpdir, 'yay.out')

    File.open(drain_script, 'w') do |fh|
      fh.puts "#!/bin/bash\necho $@ > #{drain_out}\necho -n 'broken'"
    end
    FileUtils.chmod(0777, drain_script)

    handler = Bosh::Agent::Message::Drain.new(['update', new_spec])
    expect {
      handler.drain
    }.to raise_error(Bosh::Agent::MessageHandlerError, 'Drain script exit 0: broken')

  end

  it 'raises if drain script exits non-zero' do
    set_state(old_spec)

    bindir = File.join(@base_dir, 'jobs', 'cloudcontroller', 'bin')
    tmpdir = File.join(@base_dir, 'tmp')

    FileUtils.mkdir_p(bindir)
    FileUtils.mkdir_p(tmpdir)

    drain_script = File.join(bindir, 'drain')
    drain_out    = File.join(tmpdir, 'yay.out')

    File.open(drain_script, 'w') do |fh|
      fh.puts "#!/bin/bash\necho $@ > #{drain_out}\necho -n '0'\nexit 1"
    end
    FileUtils.chmod(0777, drain_script)

    handler = Bosh::Agent::Message::Drain.new(['update', new_spec])
    expect {
      handler.drain
    }.to raise_error(Bosh::Agent::MessageHandlerError, 'Drain script exit 1: 0')

  end

  it 'does not attempt to run the drain script when drain script is not found' do
    set_state(old_spec)
    Process.should_not_receive(:spawn)
    handler = Bosh::Agent::Message::Drain.new(['update', new_spec])
    handler.drain
  end

  it 'raises when drain type is unknown' do
    set_state(old_spec)
    handler = Bosh::Agent::Message::Drain.new(['hello', new_spec])
    expect {
      handler.drain
    }.to raise_error(Bosh::Agent::MessageHandlerError, 'Unknown drain type hello')
  end

  def old_spec
    {
      'configuration_hash' => 'bfa2468a257de0ead95e1812038030209dc5b0b7',
      'packages' =>{
        'mysqlclient' =>{
          'name' => 'mysqlclient', 'blobstore_id' => '7eb0da76-2563-445c-81a2-e25a3f446473',
          'sha1' => '9e81d6e1cd2aa612598b78f362d94534cedaff87', 'version' => '1.1'
        },
        'cloudcontroller' =>{
          'name' => 'cloudcontroller', 'blobstore_id' => '8cc08509-c5ff-42ce-9ad9-423a80beee83',
          'sha1' => '40d5b9f0756aa5a22141bf78094b16b6d2c2b5e8', 'version' => '1.1-dev.1'
        },
        'ruby' =>{
          'name' => 'ruby', 'blobstore_id' => '12fbfc36-69be-4f40-81c8-bab238aaa19d',
          'sha1' => 'c5daee2106b4e948d722c7601ce8f5901e790627', 'version' => '1.1'
        }
      },
      'job' =>{
        'name' => 'cloudcontroller',
        'template' => 'cloudcontroller',
        'blobstore_id' => 'fd03f94d-95c2-4581-8ae1-d11c96ca6910',
        'sha1' => '9989206a20fe1ee70eb115287ab4d311a4236564',
        'version' => '1.1-dev'
      },
      'index' =>0
    }
  end

  def new_spec
    tmp_spec = old_spec.dup
    tmp_spec['packages']['mysqlclient']['sha1'] = 'foo_sha1'
    tmp_spec
  end

end
