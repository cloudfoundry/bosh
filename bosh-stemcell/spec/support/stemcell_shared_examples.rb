shared_examples_for 'a stemcell' do
  describe 'installed by bosh_ruby' do
    describe command('/var/vcap/bosh/bin/ruby -r yaml -e "Psych::SyntaxError"') do
      it { should return_exit_status(0) }
    end
  end

  describe 'installed by bosh_agent' do
    describe command('/var/vcap/bosh/bin/ruby -r bosh_agent -e "Bosh::Agent"') do
      it { should return_exit_status(0) }
    end
  end

  context 'installed by bosh_sudoers' do
    describe file('/etc/sudoers') do
      it { should be_file }
      it { should contain '#includedir /etc/sudoers.d' }
    end
  end

  context 'installed by bosh_micro' do
    describe file('/var/vcap/micro/apply_spec.yml') do
      it { should be_file }
      it { should contain 'deployment: micro' }
      it { should contain 'powerdns' }
    end

    describe file('/var/vcap/micro_bosh/data/cache') do
      it { should be_a_directory }
    end
  end

  # currently `should cotain` on a file does not properly escape $PATH
  context 'installed by bosh_users' do
    describe command("grep -q 'export PATH=/var/vcap/bosh/bin:\\$PATH\n' /root/.bashrc") do
      it { should return_exit_status(0) }
    end

    describe command("grep -q 'export PATH=/var/vcap/bosh/bin:\\$PATH\n' /home/vcap/.bashrc") do
      it { should return_exit_status(0) }
    end
  end
end
