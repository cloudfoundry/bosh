require 'system/spec_helper'

describe 'with release, stemcell and deployment' do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
  end

  before(:all) do
    load_deployment_spec
    use_static_ip
    @requirements.requirement(deployment, @spec) # 2.5 min on local vsphere
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  describe 'agent' do
    it 'should survive agent dying', ssh: true do
      Dir.mktmpdir do |tmpdir|
        ssh(static_ip, 'vcap', "echo #{@env.vcap_password} | sudo -S pkill -9 agent", ssh_options)
        wait_for_vm('batlight/0')
        bosh_safe("logs batlight 0 --agent --dir #{tmpdir}").should succeed
      end
    end
  end

  describe 'ssh' do
    it 'can bosh ssh into a vm' do
      private_key = ssh_options[:private_key]

      # Try our best to clean out old host fingerprints for director and vms
      if File.exist?(File.expand_path('~/.ssh/known_hosts'))
        Bosh::Exec.sh("ssh-keygen -R '#{@env.director}'")
        Bosh::Exec.sh("ssh-keygen -R '#{static_ip}'")
      end

      if private_key
        bosh_ssh_options = {
          gateway_host: @env.director,
          gateway_user: 'vcap',
          gateway_identity_file: private_key,
        }.map { |k, v| "--#{k} '#{v}'" }.join(' ')

        # Note gateway_host + ip: ...fingerprint does not match for "micro.ci2.cf-app.com,54.208.15.101" (Net::SSH::HostKeyMismatch)
        if File.exist?(File.expand_path('~/.ssh/known_hosts'))
          Bosh::Exec.sh("ssh-keygen -R '#{@env.director},#{static_ip}'")
        end
      end

      bosh_safe("ssh batlight 0 'uname -a' #{bosh_ssh_options}").should succeed_with /Linux/
    end
  end

  describe 'dns' do
    before(:all) { @dns = Resolv::DNS.new(nameserver: @env.director) }
    before { pending 'director not configured with dns' unless dns? }

    context 'external' do
      it 'should do forward lookups' do
        address = @dns.getaddress("0.batlight.static.bat.#{bosh_tld}").to_s
        address.should eq(static_ip)
      end

      it 'should do reverse lookups' do
        name = @dns.getname(static_ip).to_s
        name.should eq("0.batlight.static.bat.#{bosh_tld}")
      end
    end

    context 'internal' do
      it 'should be able to look up its own name', ssh: true do
        cmd = 'dig +short 0.batlight.static.bat.bosh a 0.batlight.static.bat.microbosh a'
        ssh(static_ip, 'vcap', cmd, ssh_options).should include(static_ip)
      end
    end
  end

  describe 'job' do
    it 'should recreate a job' do
      bosh_safe('recreate batlight 0').should succeed_with /batlight\/0 has been recreated/
    end

    it 'should stop and start a job' do
      bosh_safe('stop batlight 0').should succeed_with /batlight\/0 has been stopped/
      bosh_safe('start batlight 0').should succeed_with /batlight\/0 has been started/
    end
  end

  describe 'logs' do
    it 'should get agent log' do
      with_tmpdir do
        bosh_safe('logs batlight 0 --agent').should succeed_with /Logs saved in/
        files = tar_contents(tarfile)
        files.should include './current'
      end
    end

    it 'should get job logs' do
      with_tmpdir do
        bosh_safe('logs batlight 0').should succeed_with /Logs saved in/
        files = tar_contents(tarfile)
        files.should include './batlight/batlight.stdout.log'
        files.should include './batlight/batlight.stderr.log'
      end
    end
  end

  describe 'backup' do
    after { FileUtils.rm_f('bosh_backup.tgz') }

    it 'works' do
      bosh_safe('backup bosh_backup.tgz').should succeed_with /Backup of BOSH director was put in/

      files = tar_contents('bosh_backup.tgz', true)
      files.each { |f| expect(f.size).to be > 0 }

      file_names = files.map(&:name).join(' ')
      expect(file_names).to include('logs.tgz')
      expect(file_names).to include('task_logs.tgz')
      expect(file_names).to include('director_db.sql')
    end
  end

  describe 'managed properties' do
    context 'with no property' do
      it 'should not return a value' do
        result = bosh_safe('get property doesntexist')
        result.should_not succeed
        result.output.should match /Error 110003/
      end

      it 'should set a property' do
        result = bosh_safe('set property newprop something')
        result.should succeed
        result.output.should match /This will be a new property/
        result.output.should match /Property `newprop' set to `something'/
      end
    end

    context 'with existing property' do
      it 'should set a property' do
        bosh_safe('set property prop1 value1').should succeed
        result = bosh_safe('set property prop1 value2')
        result.should succeed
        result.output.should match /Current `prop1' value is `value1'/
        result.output.should match /Property `prop1' set to `value2'/
      end

      it 'should get a value' do
        bosh_safe('set property prop2 value3').should succeed
        bosh_safe('get property prop2').should succeed_with /Property `prop2' value is `value3'/
      end
    end
  end

  describe 'release' do
    describe 'upload' do
      after { bosh("delete release #{prev_rel.name} #{prev_rel.version}", on_error: :return) }
      let(:prev_rel) { @requirements.previous_release }

      it 'should succeed when the release is valid' do
        bosh_safe("upload release #{prev_rel.to_path}").should succeed_with /Release uploaded/
      end

      it 'should fail when the release already is uploaded' do
        result = bosh_safe("upload release #{@requirements.release.to_path}")
        result.should_not succeed
        result.output.should match /This release version has already been uploaded/
      end
    end

    describe 'delete' do
      context 'in use' do
        it 'should not be possible to delete a release that is in use' do
          result = bosh_safe("delete release #{@requirements.release.name}")
          result.should_not succeed
          result.output.should match /Error 30007/
        end

        it 'should not be possible to delete the version that is in use' do
          result = bosh_safe("delete release #{@requirements.release.name} #{@requirements.release.version}")
          result.should_not succeed
          result.output.should match /Error 30008/
        end
      end

      context 'not in use' do
        before { bosh("upload release #{@requirements.previous_release.to_path}") }

        it 'should be possible to delete a single release' do
          result = bosh_safe("delete release #{@requirements.previous_release.name} #{@requirements.previous_release.version}")
          result.should succeed_with(/Deleted `#{@requirements.previous_release.name}/)
          @bosh_api.releases.should_not include(@requirements.previous_release)
        end
      end
    end
  end
end
