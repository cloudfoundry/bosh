require 'system/spec_helper'

describe 'with release, stemcell and deployment' do
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

  describe 'agent' do
    it 'should survive agent dying', ssh: true do
      Dir.mktmpdir do |tmpdir|
        ssh(static_ip, 'vcap', "echo #{password} | sudo -S pkill -9 agent", ssh_options)
        wait_for_vm('batlight/0')
        bosh("logs batlight 0 --agent --dir #{tmpdir}")
      end
    end
  end

  describe 'ssh' do
    it 'can bosh ssh into a vm' do
      private_key = ssh_options[:private_key]
      if private_key
        bosh_ssh_options = {
          gateway_host: bosh_director,
          gateway_user: 'vcap',
          gateway_identity_file: private_key,
        }.map { |k, v| "--#{k} '#{v}'" }.join(' ')
      end
      bosh("ssh batlight 0 'uname -a' #{bosh_ssh_options}").should succeed_with /Linux/
    end
  end

  describe 'dns' do
    before(:all) { @dns = Resolv::DNS.new(nameserver: bosh_director) }
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
      bosh('recreate batlight 0').should succeed_with /batlight\/0 has been recreated/
    end

    it 'should stop and start a job' do
      bosh('stop batlight 0').should succeed_with /batlight\/0 has been stopped/
      bosh('start batlight 0').should succeed_with /batlight\/0 has been started/
    end
  end

  describe 'logs' do
    it 'should get agent log' do
      with_tmpdir do
        bosh('logs batlight 0 --agent').should succeed_with /Logs saved in/
        files = tar_contents(tarfile)
        files.should include './current'
      end
    end

    it 'should get job logs' do
      with_tmpdir do
        bosh('logs batlight 0').should succeed_with /Logs saved in/
        files = tar_contents(tarfile)
        files.should include './batlight/batlight.stdout.log'
        files.should include './batlight/batlight.stderr.log'
      end
    end
  end

  describe 'backup' do
    after { FileUtils.rm_f('bosh_backup.tgz') }

    it 'works' do
      bosh('backup bosh_backup.tgz').should succeed_with /Backup of BOSH director was put in/

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
        expect { bosh('get property doesntexist') }.to raise_error do |error|
          error.should be_a Bosh::Exec::Error
          error.output.should match /Error 110003/
        end
      end

      it 'should set a property' do
        result = bosh('set property newprop something')
        result.output.should match /This will be a new property/
        result.output.should match /Property `newprop' set to `something'/
      end
    end

    context 'with existing property' do
      it 'should set a property' do
        bosh('set property prop1 value1')
        result = bosh('set property prop1 value2')
        result.output.should match /Current `prop1' value is `value1'/
        result.output.should match /Property `prop1' set to `value2'/
      end

      it 'should get a value' do
        bosh('set property prop2 value3')
        bosh('get property prop2').should succeed_with /Property `prop2' value is `value3'/
      end
    end
  end

  describe 'release' do
    describe 'upload' do
      after { bosh("delete release #{previous_release.name} #{previous_release.version}", on_error: :return) }

      it 'should succeed when the release is valid' do
        bosh("upload release #{previous_release.to_path}").should succeed_with /Release uploaded/
      end

      it 'should fail when the release already is uploaded' do
        expect { bosh("upload release #{release.to_path}") }.to raise_error do |error|
          error.should be_a Bosh::Exec::Error
          error.output.should match /This release version has already been uploaded/
        end
      end
    end

    describe 'delete' do
      before { bosh("upload release #{previous_release.to_path}") }

      context 'in use' do
        it 'should not be possible to delete' do
          expect { bosh("delete release #{previous_release.name}") }.to raise_error do |error|
            error.should be_a Bosh::Exec::Error
            error.output.should match /Error 30007/
          end

          bosh("delete release #{previous_release.name} #{previous_release.version}")
        end

        it 'should be possible to delete a different version' do
          results = bosh("delete release #{previous_release.name} #{previous_release.version}")
          results.should succeed_with(/Deleted `#{previous_release.name}/)
        end
      end

      context 'not in use' do
        it 'should be possible to delete a single release' do
          results = bosh("delete release #{previous_release.name} #{previous_release.version}")
          results.should succeed_with(/Deleted `#{previous_release.name}/)
          releases.should_not include(previous_release)
        end
      end
    end
  end
end
