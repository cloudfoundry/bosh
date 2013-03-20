require "spec_helper"

describe "with release, stemcell and deployment" do
  before(:all) do
    requirement stemcell
    requirement release
    requirement deployment
  end

  after(:all) do
    cleanup release
    cleanup stemcell
    cleanup deployment
  end

  context "agent" do
    it "should set vcap password", ssh: true do
      # using password 'foobar'
      use_password('$6$tHAu4zCTso$pAQok0MTHP4newel7KMhTzMI4tQrAWwJ.X./fFAKjbWkCb5sAaavygXAspIGWn8qVD8FeT.Z/XN4dvqKzLHhl0')
      use_static_ip
      ssh(static_ip, "vcap", "echo foobar | sudo -S whoami", ssh_options.merge(password: "foobar")).should == "[sudo] password for vcap: root\n"
    end

    it "should survive agent dying", ssh: true do
      use_static_ip

      Dir.mktmpdir do |tmpdir|
        ssh(static_ip, "vcap", "echo #{password} | sudo -S pkill -9 agent", ssh_options)
        # wait for agent to restart
        sleep(5)
        bosh("logs batlight 0 --agent --dir #{tmpdir}")
        # TODO check log for 2 agent starts (first is initial start and second is after crash)
      end
    end
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

    it "should rename a job" do
      use_job("batfoo")
      use_template("batlight")
      updated_job_manifest = with_deployment
      bosh("deployment #{updated_job_manifest.to_path}").should succeed
      bosh('rename job batlight batfoo').should succeed_with %r{Rename successful}
      bosh('vms').should succeed_with %r{batfoo}
      updated_job_manifest.delete
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
      it "should succeed when the release is valid" do
        bosh("upload release #{@previous.to_path}").should
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

    describe "listing" do
      it "should mark releases that have uncommitted changes" do
        Dir.chdir(release.path) do |dir|
          FileUtils.mkdir File.join(dir, ".git")
          FileUtils.touch File.join("src/batlight/bin/dirty-file")
          commit_hash = `git show-ref --head --hash=8 2> /dev/null`.split.first
          bosh("create release --force")
          bosh("upload release")
          FileUtils.rm File.join("src/batlight/bin/dirty-file")
          FileUtils.rmdir File.join(dir, ".git")
          bosh("releases").should succeed_with /bosh-release.*#{commit_hash}\+.*Uncommitted changes/m
          bosh("delete release bosh-release")
          bosh("reset release")
        end
      end
    end

    describe "delete" do

      before(:each) do
        bosh("upload release #{@previous.to_path}")
      end

      context "in use" do

        it "should not be possible to delete" do
          expect {
            bosh("delete release #{@previous.name}")
          }.to raise_error { |error|
            error.should be_a Bosh::Exec::Error
            error.output.should match /Error 30007/
          }
          bosh("delete release #{@previous.name} #{@previous.version}")
        end

        it "should be possible to delete a different version" do
          bosh("delete release #{@previous.name} #{@previous.version}").should
          succeed_with /Deleted release/
        end
      end

      context "not in use" do
        it "should be possible to delete a single release" do
          bosh("delete release #{@previous.name} #{@previous.version}").should
          succeed_with /Deleted release/
          releases.should_not include(@previous)
        end

        it "should be possible to delete all releases" do
          bosh("delete release #{release.name}").should succeed_with /Deleted `#{release.name}'/
          releases.should_not include(release)
          # TODO this fails when running in fast mode, as it tries to delete the release too
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
