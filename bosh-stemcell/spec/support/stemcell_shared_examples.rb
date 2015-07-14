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
  end

  context 'disable blank password logins (stig: V-38497)' do
    describe command('grep -R nullok /etc/pam.d') do
      its (:stdout) { should eq('') }
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
end
