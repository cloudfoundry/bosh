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
      its(:stderr) {should match /No such file or directory/}
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

  context 'all system command files must be owned by root (stig: V-38472)' do
    describe command('find -L /bin /usr/bin /usr/local/bin /sbin /usr/sbin /usr/local/sbin ! -user root') do
      its (:stdout) { should eq('') }
      end
  end
end
