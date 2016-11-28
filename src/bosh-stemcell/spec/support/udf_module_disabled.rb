shared_examples_for 'udf module is disabled' do

  context 'prevent udf module from being loaded (CIS-2.24)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install udf /bin/true' }
    end
  end
end