require 'system/spec_helper'

describe 'with release and stemcell and two deployments' do
  before(:all) do
    @requirements.requirement(@requirements.release)
    @requirements.requirement(@requirements.stemcell)
    load_deployment_spec
  end

  context 'with no ephemeral disk' do
    before do
      skip 'only openstack is configurable without ephemeral disk' unless openstack?

      reload_deployment_spec
      # using password 'foobar'
      use_password('$6$tHAu4zCTso$pAQok0MTHP4newel7KMhTzMI4tQrAWwJ.X./fFAKjbWkCb5sAaavygXAspIGWn8qVD8FeT.Z/XN4dvqKzLHhl0')
      @our_ssh_options = ssh_options.merge(password: 'foobar')
      use_static_ip
      use_vip
      use_job('batlight')
      use_templates(%w[batlight])

      use_flavor_with_no_ephemeral_disk

      @requirements.requirement(deployment, @spec)
    end

    after do
      @requirements.cleanup(deployment)
    end

    it 'creates ephemeral and swap partitions on the root device if no ephemeral disk', ssh: true do
      setting_value = agent_config(public_ip).
        fetch('Platform', {}).
        fetch('Linux', {}).
        fetch('CreatePartitionIfNoEphemeralDisk', false)

      skip 'root disk ephemeral partition requires a stemcell with CreatePartitionIfNoEphemeralDisk enabled' unless setting_value

      # expect ephemeral mount point to be a mounted partition on the root disk
      expect(mounts(public_ip)).to include(hash_including('path' => '/var/vcap/data'))

      # expect swap to be a mounted partition on the root disk
      expect(swaps(public_ip)).to include(hash_including('type' => 'partition'))
    end

    def agent_config(ip)
      output = ssh_sudo(ip, 'vcap', 'cat /var/vcap/bosh/agent.json', @our_ssh_options)
      JSON.parse(output)
    end

    def mounts(ip)
      output = ssh(ip, 'vcap', 'mount', @our_ssh_options)
      output.lines.map do |line|
        matches = /(?<point>.*) on (?<path>.*) type (?<type>.*) \((?<options>.*)\)/.match(line)
        next if matches.nil?
        matchdata_to_h(matches)
      end.compact
    end

    def swaps(ip)
      output = ssh(ip, 'vcap', 'swapon -s', @our_ssh_options)
      output.lines.to_a[1..-1].map do |line|
        matches = /(?<point>.+)\s+(?<type>.+)\s+(?<size>.+)\s+(?<used>.+)\s+(?<priority>.+)/.match(line)
        next if matches.nil?
        matchdata_to_h(matches)
      end.compact
    end

    def matchdata_to_h(matchdata)
      Hash[matchdata.names.zip(matchdata.captures)]
    end
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
      ssh_sudo(public_ip, 'vcap', 'whoami', @our_ssh_options).should eq("root\n")
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
      skip "This fails on AWS VPC because use_static_ip only sets the eip but doesn't prevent collision" if aws?
      skip "This fails on OpenStack because use_static_ip only sets the floating IP but doesn't prevent collision" if openstack?
      skip "This fails on Warden because use_static_ip only sets the floating IP but doesn't prevent collision" if warden?

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
      skip "doesn't work on AWS as the VIP IP isn't visible to the VM" if aws?
      skip "doesn't work on OpenStack as the VIP IP isn't visible to the VM" if openstack?
      skip "doesn't work on Warden as the VIP IP isn't visible to eth0" if warden?
      ssh(public_ip, 'vcap', '/sbin/ifconfig eth0', @our_ssh_options).should match /#{static_ip}/
    end

    context 'second deployment' do
      SAVE_FILE = '/var/vcap/store/batarang/save'

      before(:all) do
        ssh(public_ip, 'vcap', "echo 'foobar' > #{SAVE_FILE}", @our_ssh_options)
        unless warden?
          @size = persistent_disk(public_ip, 'vcap', @our_ssh_options)
        end
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
