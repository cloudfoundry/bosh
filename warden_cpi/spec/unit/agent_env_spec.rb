require File.expand_path('../../spec_helper',__FILE__)

describe Bosh::WardenCloud::Cloud do
  include Warden::Protocol
  include Bosh::WardenCloud::Helpers
  include Bosh::WardenCloud::Models

  DEFAULT_AGENT_ID = "agent-abcd"

  before :all do
    @cotainer_root = Dir.mktmpdir("warden-cpi")
  end

  after :all do
    FileUtils.rm_rf(@cotainer_root)
  end

  def create_container
    container_id = rand(100).to_s
    FileUtils.mkdir_p File.join(@cotainer_root, container_id)
    container_id
  end

  def destroy_container container_id
    FileUtils.rm_rf File.join(@cotainer_root, container_id)
  end

  before :each do
    @container_id = create_container

    network_spec = {
      "nic1" => { "ip" => "1.1.1.1", "type" => "static" },
    }

    @env = {
      "agent_id" => DEFAULT_AGENT_ID,
      "networks" => network_spec,
      "disk" => { "persistent" => {} },
    }

    options = {
      "stemcell" => { "root" => @cotainer_root },
      "agent" => agent_options,
    }

    @cloud = Bosh::Clouds::Provider.create :warden, options

    [:connect, :disconnect].each do |op|
      Warden::Client.any_instance.stub(op) {} # no-op
    end

    @cloud.delegate.stub(:sudo) { }

    Warden::Client.any_instance.stub(:call) do |request|
      resp = nil

      if request.instance_of? CopyOutRequest
        src_path = File.join @container_id, request.src_path
        FileUtils.copy src_path, request.dst_path

        resp = CopyOutResponse.new
      elsif request.instance_of? CopyInRequest
        dst_path = File.join @container_id, request.dst_path
        FileUtils.mkdir_p File.dirname(dst_path)
        FileUtils.copy request.src_path, dst_path

        resp = CopyInResponse.new
      else
        raise "not support"
      end

      resp
    end
  end

  after :each do
    destroy_container @container_id
  end

  context do "set and get agent env"
    it "can set and get agent env" do
      # set agent env to the container
      @cloud.delegate.send :set_agent_env, @container_id, @env

      # get agent env from the container
      env = @cloud.delegate.send :get_agent_env, @container_id
      env.should == @env
    end
  end
end
