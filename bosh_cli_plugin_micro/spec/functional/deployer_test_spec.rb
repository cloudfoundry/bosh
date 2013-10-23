require 'spec_helper'

describe Bosh::Deployer do
  def setup(config_yml)
    @stemcell_tgz = ENV['BOSH_STEMCELL_TGZ']
    @dir = ENV['BOSH_DEPLOYER_DIR'] || Dir.mktmpdir('bd_spec')

    config = Psych.load_file(spec_asset(config_yml))
    config['dir'] = @dir

    messager = Bosh::Deployer::UiMessager.for_deployer
    @deployer = Bosh::Deployer::InstanceManager.new(
      config, 'fake-config-sha1', messager)
  end

  describe 'vSphere' do
    before(:all) { setup('test-bootstrap-config.yml') }
    after(:all)  { FileUtils.remove_entry_secure(@dir) unless ENV['BOSH_DEPLOYER_DIR'] }

    it 'should create a Bosh VM' do
      pending 'stemcell tgz' unless @stemcell_tgz
      @deployer.create(@stemcell_tgz)
    end

    it 'should respond to agent ping' do
      pending 'VM cid' unless @deployer.state.vm_cid
      @deployer.agent.ping.should == 'pong'
    end

    it 'should destroy the Bosh deployment' do
      pending 'VM cid' unless @deployer.state.vm_cid
      @deployer.destroy
      @deployer.state.disk_cid.should be_nil
    end
  end

  describe 'aws' do
    before(:all) { setup('test-bootstrap-config-aws.yml') }
    after(:all)  { FileUtils.remove_entry_secure(@dir) unless ENV['BOSH_DEPLOYER_DIR'] }

    it 'should instantiate a deployer' do
      @deployer.cloud.should be_kind_of(Bosh::AwsCloud::Cloud)
    end
  end
end
