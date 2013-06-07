require "spec_helper"

describe "with release, stemcell and deployment" do
  before(:all) do
    requirement stemcell
    requirement release

    load_deployment_spec
    use_static_ip
    requirement deployment
  end

  after(:all) do
    cleanup deployment
    cleanup release
    cleanup stemcell
  end

  context "agent" do

    it "should survive agent dying", ssh: true do
      Dir.mktmpdir do |tmpdir|
        ssh(static_ip, "vcap", "echo #{password} | sudo -S pkill -9 agent", ssh_options)
        # wait for agent to restart
        wait_for_vm('batlight/0')
        bosh("logs batlight 0 --agent --dir #{tmpdir}")
        # TODO check log for 2 agent starts (first is initial start and second is after crash)
      end
    end
  end

  xit "should return vms in a deployment" do
    bat_vms = vms(deployment.name)
    bat_vms.size.should == 1
    bat_vms.first.name.should == "batlight/0"
  end

  context "dns" do

    before(:all) do
      @dns = Resolv::DNS.new(:nameserver => bosh_director)
    end

    context "external" do
      it "should do forward lookups" do
        pending "director not configured with dns" unless dns?
        address = @dns.getaddress("0.batlight.static.bat.#{bosh_tld}").to_s
        address.should == static_ip
      end

      it "should do reverse lookups" do
        pending "director not configured with dns" unless dns?
        name = @dns.getname(static_ip)
        name.to_s.should == "0.batlight.static.bat.#{bosh_tld}"
      end
    end

    context "internal" do
      it "should be able to lookup of its own name", ssh: true do
        pending "director not configured with dns" unless dns?
        cmd = "dig +short 0.batlight.static.bat.bosh a 0.batlight.static.bat.microbosh a"
        ssh(static_ip, "vcap", cmd, ssh_options).should match /#{static_ip}/
      end
    end
  end

  context "job" do
    it "should restart a job" do
      bosh("restart bat 0").should succeed_with %r{bat/0 has been restarted}
      # TODO verify that the process gets a new pid
    end

    it "should recreate a job" do
      bosh("recreate bat 0").should succeed_with %r{bat/0 has been recreated}
      # TODO verify that the VM gets a new cid
    end

    it "should stop and start a job" do
      bosh("stop bat 0").should succeed_with %r{bat/0 has been stopped}
      bosh("start bat 0").should succeed_with %r{bat/0 has been started}
      # TODO verify that the process gets a new pid
    end

  end

  context "logs" do
    it "should get agent log" do
      with_tmpdir do
        bosh("logs batlight 0 --agent").should succeed_with /Logs saved in/
        files = tar_contents(tarfile)
        files.should include "./current"
      end
    end

    it "should get job logs" do
      with_tmpdir do
        bosh("logs batlight 0").should succeed_with /Logs saved in/
        files = tar_contents(tarfile)
        files.should include "./batlight/batlight.stdout.log"
        files.should include "./batlight/batlight.stderr.log"
      end
    end
  end

  describe "managed properties" do
    context "with no property" do

      it "should not return a value" do
          expect {
            bosh("get property doesntexist")
          }.to raise_error { |error|
            error.should be_a Bosh::Exec::Error
            error.output.should match /Error 110003/
          }
      end

      it "should set a property" do
          result = bosh("set property newprop something")
          result.output.should match /This will be a new property/
          result.output.should match /Property `newprop' set to `something'/
      end

    end

    context "with existing property" do

      it "should set a property" do
          bosh("set property prop1 value1")
          result = bosh("set property prop1 value2")
          result.output.should match /Current `prop1' value is `value1'/
          result.output.should match /Property `prop1' set to `value2'/
      end

      it "should get a value" do
          bosh("set property prop2 value3")
          bosh("get property prop2").should succeed_with /Property `prop2' value is `value3'/
      end

    end
  end

  context "release" do
    describe "upload" do

      after do
        bosh("delete release #{previous_release.name} #{previous_release.version}", :on_error => :return)
      end

      it "should succeed when the release is valid" do
        bosh("upload release #{previous_release.to_path}").should
        succeed_with /Release uploaded/
      end

      it "should fail when the release already is uploaded" do
        expect {
          bosh("upload release #{release.to_path}")
        }.to raise_error { |error|
          error.should be_a Bosh::Exec::Error
          error.output.should match /This release version has already been uploaded/
        }
      end
    end

    describe "delete" do

      before(:each) do
        bosh("upload release #{previous_release.to_path}")
      end

      context "in use" do

        it "should not be possible to delete" do
          expect {
            bosh("delete release #{previous_release.name}")
          }.to raise_error { |error|
            error.should be_a Bosh::Exec::Error
            error.output.should match /Error 30007/
          }
          bosh("delete release #{previous_release.name} #{previous_release.version}")
        end

        it "should be possible to delete a different version" do
          bosh("delete release #{previous_release.name} #{previous_release.version}").should
          succeed_with /Deleted release/
        end
      end

      context "not in use" do
        it "should be possible to delete a single release" do
          bosh("delete release #{previous_release.name} #{previous_release.version}").should
          succeed_with /Deleted release/
          releases.should_not include(previous_release)
        end
      end
    end
  end

  context "stemcell" do

    it "should not delete a stemcell in use" do
      expect {
        bosh("delete stemcell #{stemcell.name} #{stemcell.version}")
      }.to raise_error { |error|
        error.should be_a Bosh::Exec::Error
        error.output.should match /Error 50004/
      }
    end
  end

end
