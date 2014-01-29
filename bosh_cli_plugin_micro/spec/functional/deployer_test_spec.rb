require 'spec_helper'
require 'bosh/deployer/instance_manager/vsphere'

describe Bosh::Deployer do
  let(:infrastructure) do
    double(
      'Bosh::Deployer::InstanceManager::Vsphere',
      disk_model: nil,
      discover_bosh_ip: '127.127.0.1',
    )
  end
  before do
    Bosh::Deployer::InstanceManager.stub_chain(:const_get, :new).and_return(infrastructure)
  end

  def setup(config_yml)
    @stemcell_tgz = ENV['BOSH_STEMCELL_TGZ']
    @dir = ENV['BOSH_DEPLOYER_DIR'] || Dir.mktmpdir('bd_spec')

    config = Psych.load_file(spec_asset(config_yml))
    config['dir'] = @dir

    messager = Bosh::Deployer::UiMessager.for_deployer
    @deployer = Bosh::Deployer::InstanceManager.new(
      config, 'fake-config-sha1', messager, 'fake-plugin')
  end

  describe 'vSphere' do
    before { setup('test-bootstrap-config.yml') }
    after  { FileUtils.remove_entry_secure(@dir) unless ENV['BOSH_DEPLOYER_DIR'] }

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
    before { setup('test-bootstrap-config-aws.yml') }
    after  { FileUtils.remove_entry_secure(@dir) unless ENV['BOSH_DEPLOYER_DIR'] }

    it 'should instantiate a deployer' do
      @deployer.cloud.should be_kind_of(Bosh::AwsCloud::Cloud)
    end
  end
end
