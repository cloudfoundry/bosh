require 'system/spec_helper'

describe 'with release and stemcell and two deployments' do
  before(:all) do
    @requirements.requirement(@requirements.release)
    @requirements.requirement(@requirements.stemcell)
    load_deployment_spec
  end

  context 'first deployment' do
    before(:all) do
      reload_deployment_spec
      # using password 'foobar'
      use_password('$6$tHAu4zCTso$pAQok0MTHP4newel7KMhTzMI4tQrAWwJ.X./fFAKjbWkCb5sAaavygXAspIGWn8qVD8FeT.Z/XN4dvqKzLHhl0')
      @our_ssh_options = ssh_options.merge(password: 'foobar')
      use_static_ip
      use_vip
      @jobs = %w[
        /var/vcap/packages/batlight/bin/batlight
        /var/vcap/packages/batarang/bin/batarang
      ]
      use_job('colocated')
      use_templates(%w[batarang batlight])

      use_persistent_disk(2048)

      @first_deployment_result = @requirements.requirement(deployment, @spec)
    end

    after(:all) do
      @requirements.cleanup(deployment)
    end

    it 'should set vcap password', ssh: true do
      ssh(public_ip, 'vcap', 'echo foobar | sudo -S whoami', @our_ssh_options).should eq("[sudo] password for vcap: root\n")
    end

    it 'should not change the deployment on a noop' do
      deployment_result = bosh('deploy')
      events(get_task_id(deployment_result.output)).each do |event|
        if event['stage']
          expect(event['stage']).to_not match(/^Updating/)
        end
      end
    end

    it 'should do two deployments from one release' do
      pending "This fails on AWS VPC because use_static_ip only sets the eip but doesn't prevent collision" if aws?
      pending "This fails on OpenStack because use_static_ip only sets the floating IP but doesn't prevent collision" if openstack?
      pending "This fails on Warden because use_static_ip only sets the floating IP but doesn't prevent collision" if warden?

      # second deployment can't use static IP or elastic IP or there will be a collision with the first deployment
      no_static_ip
      no_vip
      use_deployment_name('bat2')
      with_deployment do
        @bosh_api.deployments.should include('bat2')
      end
      # Not sure why these are necessary since the before(:all) should call them
      # before setting up future deployments. But without these, the state leaks
      # into subsequent tests.
      use_deployment_name('bat')
      use_static_ip
      use_vip
    end

    it 'should use job colocation', ssh: true do
      @jobs.each do |job|
        grep_cmd = "ps -ef | grep #{job} | grep -v grep"
        ssh(public_ip, 'vcap', grep_cmd, @our_ssh_options).should match /#{job}/
      end
    end

    it 'should deploy using a static network', ssh: true do
      pending "doesn't work on AWS as the VIP IP isn't visible to the VM" if aws?
      pending "doesn't work on OpenStack as the VIP IP isn't visible to the VM" if openstack?
      pending "doesn't work on Warden as the VIP IP isn't visible to eth0" if warden?
      ssh(public_ip, 'vcap', '/sbin/ifconfig eth0', @our_ssh_options).should match /#{static_ip}/
    end

    context 'second deployment' do
      SAVE_FILE = '/var/vcap/store/batarang/save'

      before(:all) do
        ssh(public_ip, 'vcap', "echo 'foobar' > #{SAVE_FILE}", @our_ssh_options)
        @size = persistent_disk(public_ip, 'vcap', @our_ssh_options)
        use_persistent_disk(4096)
        @second_deployment_result = @requirements.requirement(deployment, @spec, force: true)
      end

      it 'should migrate disk contents', ssh: true do
        # Warden df don't work so skip the persistent disk size check
        unless warden?
          persistent_disk(public_ip, 'vcap', @our_ssh_options).should_not eq(@size)
        end
        ssh(public_ip, 'vcap', "cat #{SAVE_FILE}", @our_ssh_options).should match /foobar/
      end

      xit 'should rename a job' do
        bosh('rename job batlight batfoo').should succeed_with /Rename successful/
        bosh('vms').should succeed_with /batfoo/
      end
    end
  end
end
