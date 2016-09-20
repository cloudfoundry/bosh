require 'rspec'

shared_examples_for 'All Stemcells' do

  context 'building a new stemcell' do
    describe file '/var/vcap/bosh/etc/stemcell_version' do
      let(:expected_version) { ENV['CANDIDATE_BUILD_NUMBER'] || ENV['STEMCELL_BUILD_NUMBER'] || '0000' }

      it { should be_file }
      it { should contain expected_version }
    end

    describe file '/var/vcap/bosh/etc/stemcell_git_sha1' do
      it { should be_file }
      its(:content) { should match '^[0-9a-f]{40}\+?$' }
    end

    describe command 'ls -l /etc/ssh/*_key*' do
      its(:stderr) { should match /No such file or directory/ }
    end
  end

  context 'disable remote host login (stig: V-38491)' do
    describe command('find /home -name .rhosts') do
      its (:stdout) { should eq('') }
    end

    describe file('/etc/hosts.equiv') do
      it { should_not be_file }
    end
  end

  context 'system library files' do
    describe file('/lib') do
      it('should be owned by root user (stig: V-38466)') { should be_owned_by('root') }
    end

    describe file('/lib64') do
      it('should be owned by root user (stig: V-38466)') { should be_owned_by('root') }
    end

    describe file('/usr/lib') do
      it('should be owned by root user (stig: V-38466)') { should be_owned_by('root') }
    end

    describe command('if [ -e /usr/lib64 ]; then stat -c "%U" /usr/lib64 ; else echo "root" ; fi') do
      its (:stdout) { should eq("root\n") }
    end
  end

  describe file('/var/vcap/micro_bosh/data/cache') do
    it('should still be created') { should be_directory }
  end

  context 'libyaml should be installed' do
    describe command('test -L /usr/lib64/libyaml.so') do
      it { should return_exit_status(0) }
    end

    describe command('readlink -e /usr/lib64/libyaml.so') do
      it { should return_exit_status(0) }
    end
  end

  context 'Library files must have mode 0755 or less permissive (stig: V-38465)' do
    describe command("find -L /lib /lib64 /usr/lib $( [ ! -e /usr/lib64 ] || echo '/usr/lib64' ) -perm /022 -type f") do
      its (:stdout) { should eq('') }
    end
  end

  context 'System command files must have mode 0755 or less permissive (stig: V-38469)' do
    describe command('find -L /bin /usr/bin /usr/local/bin /sbin /usr/sbin /usr/local/sbin -perm /022 -type f') do
      its (:stdout) { should eq('') }
    end
  end

  context 'all system command files must be owned by root (stig: V-38472)' do
    describe command('find -L /bin /usr/bin /usr/local/bin /sbin /usr/sbin /usr/local/sbin ! -user root') do
      its (:stdout) { should eq('') }
    end
  end

  context 'There must be no .netrc files on the system (stig: V-38619)' do
    describe command('sudo find /root /home /var/vcap -xdev -name .netrc') do
      its (:stdout) { should eq('') }
    end
  end

  describe 'logrotate' do
    describe 'should rotate every 15 minutes' do
      describe file('/etc/cron.d/logrotate') do
        it { should contain '0,15,30,45 * * * * root /usr/bin/logrotate-cron' }
      end
    end

    describe 'default su directive' do
      describe file('/etc/logrotate.d/default_su_directive') do
        it { should contain 'su root root' }
      end
    end
  end
end
