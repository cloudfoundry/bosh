require "spec_helper"

describe Bosh::Spec::IntegrationTest::HealthMonitor do

  before :each do
    @nats = nil
    @events_received = 0
    @alerts_received = 0
    @listener = nil
  end

  def subscribe_to_events
    @listener = Thread.new do
      EM.run do
        @nats = NATS.connect(:uri => "nats://127.0.0.1:#{Bosh::Spec::Sandbox::NATS_PORT}")

        @nats.subscribe("bosh.hm.events") do |event|
          @events_received += 1
        end

        @nats.subscribe("bosh.hm.alerts") do |alert|
          @alerts_received += 1
        end

        @nats.subscribe("test.stop") do
          EM.stop
        end
      end
    end
  end

  def deploy
    assets_dir          = File.dirname(spec_asset("foo"))
    release_filename    = spec_asset("test_release/dev_releases/test_release-1.tgz")
    stemcell_filename   = spec_asset("valid_stemcell.tgz")
    deployment_manifest = yaml_file("simple", Bosh::Spec::Deployments.simple_manifest)

    Dir.chdir(File.join(assets_dir, "test_release")) do
      run_bosh("create release --with-tarball", Dir.pwd)
    end

    run_bosh("deployment #{deployment_manifest.path}")
    run_bosh("login admin admin")
    run_bosh("upload stemcell #{stemcell_filename}")
    run_bosh("upload release #{release_filename}")

    run_bosh("deploy")
  end

  it "HM can be queried for stats" do
    subscribe_to_events
    deploy

    loop do
      break if EM.reactor_running?
      sleep(0.1)
    end

    Thread.new do
      @nats.request("bosh.hm.stats") do |reply_json|
        reply = Yajl::Parser.parse(reply_json)
        reply["agents_count"].should == 3
        reply["deployments_count"].should == 1
      end
    end

    sleep(0.1)

    @nats.publish("test.stop")
    @listener.join
  end

end
