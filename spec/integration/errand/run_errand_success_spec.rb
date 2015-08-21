require 'spec_helper'

#Errand failure/success were split up so that they can be run on different rspec:parallel threads
describe 'run errand success', type: :integration, with_tmp_dir: true do
  context 'while errand is running' do
    with_reset_sandbox_before_each

    let(:manifest_hash) do
      manifest_hash = Bosh::Spec::Deployments.manifest_with_errand
      manifest_hash['properties'] = {
        'errand1' => {
          'blocking_errand' => true,
        },
      }
      manifest_hash
    end

    it 'creates a deployment lock' do
      deploy_from_scratch(manifest_hash: manifest_hash)

      output = bosh_runner.run('--no-track run errand fake-errand-name')
      task_id = Bosh::Spec::OutputParser.new(output).task_id('running')
      director.wait_for_first_available_vm

      output = bosh_runner.run_until_succeeds('locks')
      expect(output).to match(/\s*\|\s*deployment\s*\|\s*errand\s*\|/)

      errand_vm = director.vms.find { |vm| vm.job_name_index == 'fake-errand-name/0' }
      expect(errand_vm).to_not be_nil

      errand_vm.unblock_errand('errand1')
      bosh_runner.run("task #{task_id}")
    end
  end

  context 'when multiple errands exist in the deployment manifest' do
    with_reset_sandbox_before_each

    let(:manifest_hash) { Bosh::Spec::Deployments.manifest_with_errand }

    let(:errand_requiring_2_instances) do
      {
        'name' => 'second-errand-name',
        'template' => 'errand1',
        'lifecycle' => 'errand',
        'resource_pool' => 'a',
        'instances' => 2,
        'networks' => [{'name' => 'a'}],
        'properties' => {
          'errand1' => {
            'exit_code' => 0,
            'stdout' => 'second-errand-stdout',
            'stderr' => 'second-errand-stderr',
            'run_package_file' => true,
          },
        },
      }
    end

    context 'with a fixed size resource pool size' do
      let(:cloud_config_hash) do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config_hash['resource_pools'].find { |rp| rp['name'] == 'a' }['size'] = 3
        cloud_config_hash
      end

      it 'allocates enough empty VMs for the largest errand on deploy and reallocates empty VMs after each errand run' do
        manifest_with_second_errand = manifest_hash
        manifest_with_second_errand['jobs'] << errand_requiring_2_instances
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_with_second_errand)
        expect_running_vms(%w(foobar/0 unknown/unknown unknown/unknown))
        expect_errands('fake-errand-name', 'second-errand-name')

        # with keep alive, does not delete/create errand vms
        output, exit_code = bosh_runner.run('run errand fake-errand-name --keep-alive', return_exit_code: true)
        expect(output).to include('fake-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms(%w(fake-errand-name/0 foobar/0 unknown/unknown))

        output, exit_code = bosh_runner.run('run errand fake-errand-name --keep-alive', return_exit_code: true)
        expect(output).to include('fake-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms(%w(fake-errand-name/0 foobar/0 unknown/unknown))

        # without keep alive, deletes vm
        output, exit_code = bosh_runner.run('run errand fake-errand-name', return_exit_code: true)
        expect(output).to include('fake-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms(%w(foobar/0 unknown/unknown unknown/unknown))

        output, exit_code = bosh_runner.run('run errand second-errand-name', return_exit_code: true)
        expect(output).to include('second-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms(%w(foobar/0 unknown/unknown unknown/unknown))
      end
    end

    context 'with a dynamically sized resource pool size' do
      let(:cloud_config_hash) do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config_hash['resource_pools'].find { |rp| rp['name'] == 'a' }.delete('size')
        cloud_config_hash
      end

      it 'allocates and de-allocates errand vms for each errand run' do
        manifest_with_second_errand = manifest_hash
        manifest_with_second_errand['jobs'] << errand_requiring_2_instances
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_with_second_errand)
        expect_running_vms(%w(foobar/0))

        expect_errands('fake-errand-name', 'second-errand-name')

        output, exit_code = bosh_runner.run('run errand fake-errand-name --keep-alive', return_exit_code: true)
        expect(output).to include('fake-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms(%w(fake-errand-name/0 foobar/0))

        output, exit_code = bosh_runner.run('run errand fake-errand-name --keep-alive', return_exit_code: true)
        expect(output).to include('fake-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms(%w(fake-errand-name/0 foobar/0))

        output, exit_code = bosh_runner.run('run errand fake-errand-name', return_exit_code: true)
        expect(output).to include('fake-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms(%w(foobar/0))

        output, exit_code = bosh_runner.run('run errand second-errand-name', return_exit_code: true)
        expect(output).to include('second-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms(%w(foobar/0))
      end
    end
  end

  describe 'network update is required for the job vm' do
    with_reset_sandbox_before_each

    context 'when running an errand will require to recreate vm' do
      let(:static_ip) { '192.168.1.13' }
      let(:manifest_hash) do
        # This test setup depends on questionable bosh behavior.
        # The vm for the errand will be created at deploy time,
        # but it will not have the requested static ip.
        # When the errand is run, a network update will be required.
        # The network update will fail, by default dummy CPI will
        # raise NotSupported, like the aws cpi.
        manifest_hash = Bosh::Spec::Deployments.manifest_with_errand

        # get rid of the non-errand job, it's not important
        manifest_hash['jobs'].delete(manifest_hash['jobs'].find{ |i| i['name'] == 'foobar' })
        errand_job = manifest_hash['jobs'].find{ |i| i['name'] == 'fake-errand-name' }
        errand_job_network_a = errand_job['networks'].find{ |i| i['name'] == 'a' }
        errand_job_network_a['static_ips'] = [static_ip]

        manifest_hash
      end

      let(:cloud_config_hash) do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        # set the errand job to have a static ip to trigger the network update
        # at errand run time.
        network_a = cloud_config_hash['networks'].find{ |i| i['name'] == 'a' }
        network_a_subnet = network_a['subnets'].first
        network_a_subnet['reserved'] =  [
          '192.168.1.2 - 192.168.1.10',
          '192.168.1.14 - 192.168.1.254'
        ]
        network_a_subnet['static'] = [static_ip]

        # setting the size of the pool causes the empty vm to be created
        # at deploy time, and this vm will not have the static IP the job has requested
        # When the errand runs it will try to reuse this unassigned vm and it will
        # require network update since it has static IP.
        resource_pool_a = cloud_config_hash['resource_pools'].find { |i| i['name'] == 'a' }
        resource_pool_a['size'] = 1
        cloud_config_hash
      end

      it 'should tear down the VM successfully after running the errand' do
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        _, exit_code = bosh_runner.run('run errand fake-errand-name', return_exit_code: true)
        expect(exit_code).to eq(0)
      end
    end

    context 'when the number of dynamic IPs is equal to the total number of vms' do
      let(:manifest_hash) do
        Bosh::Spec::Deployments.test_release_manifest.merge({
          'jobs' => [{
            'name' => 'fake-errand-name',
            'template' => 'errand_without_package',
            'resource_pool' => 'fake-resource-pool',
            'instances' => 1,
            'lifecycle' => 'errand',
            'networks' => [{'name' => 'fake-network'}],
          }]
        })
      end

      let(:cloud_config_hash) do
        {
          'compilation' => {
            'workers' => 1,
            'network' => 'fake-network',
            'cloud_properties' => {},
          },
          'networks' => [
            {
              'name' => 'fake-network',
              'subnets' => [
                {
                  'range' => '192.168.1.0/24',
                  'gateway' => '192.168.1.1',
                  'dns' => ['192.168.1.1', '192.168.1.2'],
                  'reserved' =>
                    ['192.168.1.2 - 192.168.1.12',
                      '192.168.1.14 - 192.168.1.254'],
                  'cloud_properties' => {}
                }
              ]
            }
          ],
          'resource_pools' => [
            {
              'name' => 'fake-resource-pool',
              'size' => 1,
              'cloud_properties' => {},
              'network' => 'fake-network',
              'stemcell' => {
                'name' => 'ubuntu-stemcell',
                'version' => '1',
              },
            }
          ]
        }
      end

      before { deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash) }

      it 'should have enough IPs to recreate the vm' do
        _, exit_code = bosh_runner.run('run errand fake-errand-name', return_exit_code: true)
        expect(exit_code).to eq(0)
      end
    end
  end

  context 'when errand script exits with 0 exit code' do
    with_reset_sandbox_before_all
    with_tmp_dir_before_all

    before(:all) do
      deploy_from_scratch(manifest_hash: Bosh::Spec::Deployments.manifest_with_errand)
      expect_errands('fake-errand-name')

      @output, @exit_code = bosh_runner.run("run errand fake-errand-name --download-logs --logs-dir #{@tmp_dir}",
                                            {return_exit_code: true})
    end

    it 'shows bin/run stdout and stderr' do
      expect(@output).to include('fake-errand-stdout')
      expect(@output).to include('fake-errand-stderr')
    end

    it 'shows output generated by package script which proves dependent packages are included' do
      expect(@output).to include('stdout-from-errand1-package')
    end

    it 'downloads errand logs and shows downloaded location' do
      expect(@output =~ /Logs saved in `(.*fake-errand-name\.0\..*\.tgz)'/).to_not(be_nil, @output)
      logs_file = Bosh::Spec::TarFileInspector.new($1)
      expect(logs_file.file_names).to match_array(%w(./errand1/stdout.log ./custom.log))
      expect(logs_file.smallest_file_size).to be > 0
    end

    it 'returns 0 as exit code from the cli and indicates that errand ran successfully' do
      expect(@output).to include('Errand `fake-errand-name\' completed successfully (exit code 0)')
      expect(@exit_code).to eq(0)
    end
  end

  context 'when manifest file is greater than 64Kb' do
    with_reset_sandbox_before_each

    let(:manifest_hash) do
      large_property = 64.times.inject('') { |p| p << 'a'*1024 } # generates 64Kb string
      manifest = {'large_property' => large_property }
      manifest.merge(Bosh::Spec::Deployments.manifest_with_errand)
    end

    it 'deploys successfully' do
      deploy_from_scratch(manifest_hash: manifest_hash)

      _, exit_code = bosh_runner.run('run errand fake-errand-name', { return_exit_code: true })
      expect(exit_code).to eq(0)
    end
  end

  def expect_errands(*expected_errands)
    output, _ = bosh_runner.run('errands')
    expected_errands.each do |errand|
      expect(output).to include(errand)
    end
  end
end
