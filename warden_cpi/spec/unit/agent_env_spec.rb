require File.expand_path('../../spec_helper',__FILE__)

describe Bosh::WardenCloud::Cloud do
  include Warden::Protocol
  include Bosh::WardenCloud::Helpers
  include Bosh::WardenCloud::Models
  attr_reader :logger

  DEFAULT_HANDLE = "1234"
  DEFAULT_AGENT_ID = "agent-abcd"

  before :all do
    @cotainer_root = Dir.mktmpdir("warden-cpi")
  end

  after :all do
    FileUtils.rm_rf(@cotainer_root)
  end

  def create_container
    FileUtils.mkdir_p File.join(@cotainer_root, rand.to_s)
    rand.to_s
  end

  def destroy_container container_path
    FileUtils.rm_rf File.join(@cotainer_root, container_path)
  end

  before :each do
    @container_path = create_container

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
        # stub copy-in request handler here by copying the agent settings file from container to the temp file
        src_path = File.join @container_path, request.src_path
        FileUtils.copy src_path, request.dst_path

        resp = CopyOutResponse.new
      elsif request.instance_of? CopyInRequest
        # stub copy-out request handler here by copying temp file to the agent settings file
        dst_path = File.join @container_path, request.dst_path
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
    destroy_container @container_path
  end

  context do "set and get agent env"
    it "can set and get agent env" do
      # set agent env to the container
      @cloud.delegate.send :set_agent_env, DEFAULT_HANDLE, @env

      # get agent env from the container
      env = @cloud.delegate.send :get_agent_env, DEFAULT_HANDLE
      env.should == @env
    end
  end
end
