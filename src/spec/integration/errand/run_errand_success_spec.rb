require_relative '../../spec_helper'

# Errand failure/success were split up so that they can be run on different rspec:parallel threads
describe 'run-errand success', type: :integration, with_tmp_dir: true do
  let(:manifest_hash) { Bosh::Spec::Deployments.manifest_with_errand }
  let(:deployment_name) { manifest_hash['name'] }

  context 'while errand is running' do
    with_reset_sandbox_before_each

    let(:manifest_hash_errand) do
      manifest_hash['instance_groups'][1]['jobs'][0]['properties'] = {
        'errand1' => {
          'blocking_errand' => true,
        },
      }
      manifest_hash
    end

    it 'creates a deployment lock' do
      deploy_from_scratch(manifest_hash: manifest_hash_errand, cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)

      output = bosh_runner.run('run-errand fake-errand-name', deployment_name: deployment_name, no_track: true)
      task_id = Bosh::Spec::OutputParser.new(output).task_id('*')
      expect(director.wait_for_vm('fake-errand-name', '0', 150, deployment_name: deployment_name)).to_not be_nil

      output = JSON.parse(bosh_runner.run_until_succeeds('locks --json'))
      expect(output['Tables'][0]['Rows'])
        .to include('type' => 'deployment', 'resource' => 'errand', 'expires_at' => anything, 'task_id' => /^[\d]*$/)

      errand_instance = director.instances(deployment_name: deployment_name)
        .find { |instance| instance.instance_group_name == 'fake-errand-name' && instance.index == '0' }
      expect(errand_instance).to_not be_nil

      errand_instance.unblock_errand('errand1')
      bosh_runner.run("task #{task_id}")
    end
  end

  context 'when multiple errands exist in the deployment manifest' do
    with_reset_sandbox_before_each

    let(:manifest_hash) { Bosh::Spec::Deployments.manifest_with_errand }

    let(:errand_requiring_2_instances) do
      {
        'name' => 'second-errand-name',
        'jobs' => [{
          'release' => 'bosh-release',
          'name' => 'errand1',
          'properties' => {
            'errand1' => {
              'exit_code' => 0,
              'stdout' => 'second-errand-stdout',
              'stderr' => 'second-errand-stderr',
              'run_package_file' => true,
            },
          },
        }],
        'lifecycle' => 'errand',
        'vm_type' => 'a',
        'instances' => 2,
        'networks' => [{ 'name' => 'a' }],
        'stemcell' => 'default',
      }
    end

    context 'with a fixed size resource pool size' do
      let(:cloud_config_hash) do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config_hash['vm_types'].find { |type| type['name'] == 'a' }['size'] = 3
        cloud_config_hash
      end

      it "reuses vms when keep-alive is set and cleans them up when it's not" do
        manifest_with_second_errand = manifest_hash
        manifest_with_second_errand['instance_groups'] << errand_requiring_2_instances
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_with_second_errand)
        expect_running_vms_with_names_and_count({ 'foobar' => 1 }, { deployment_name: deployment_name })
        expect_errands('fake-errand-name', 'second-errand-name')

        # with keep alive, does not delete/create errand vms (always exactly 1 fake-errand-name/0)
        output, exit_code = bosh_runner.run(
          'run-errand fake-errand-name --keep-alive',
          return_exit_code: true,
          deployment_name: deployment_name,
        )
        expect(output).to include('fake-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms_with_names_and_count({ 'foobar' => 1, 'fake-errand-name' => 1 }, { deployment_name: deployment_name })

        output, exit_code = bosh_runner.run(
          'run-errand fake-errand-name --keep-alive',
          return_exit_code: true,
          deployment_name: deployment_name,
        )
        expect(output).to include('fake-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms_with_names_and_count({ 'foobar' => 1, 'fake-errand-name' => 1 }, { deployment_name: deployment_name })

        # without keep alive, deletes vm (no fake-errand-name/0)
        output, exit_code = bosh_runner.run(
          'run-errand fake-errand-name',
          return_exit_code: true,
          deployment_name: deployment_name,
        )
        expect(output).to include('fake-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms_with_names_and_count({ 'foobar' => 1 }, { deployment_name: deployment_name })

        output, exit_code = bosh_runner.run(
          'run-errand second-errand-name',
          return_exit_code: true,
          deployment_name: deployment_name,
        )
        expect(output).to include('second-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms_with_names_and_count({ 'foobar' => 1 }, { deployment_name: deployment_name })
      end
    end

    context 'with a dynamically sized resource pool size' do
      let(:cloud_config_hash) do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config_hash['vm_types'].find { |type| type['name'] == 'a' }.delete('size')
        cloud_config_hash
      end

      it 'allocates and de-allocates errand vms for each errand run' do
        manifest_with_second_errand = manifest_hash
        manifest_with_second_errand['instance_groups'] << errand_requiring_2_instances
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_with_second_errand)
        expect_running_vms_with_names_and_count({ 'foobar' => 1 }, { deployment_name: deployment_name })

        expect_errands('fake-errand-name', 'second-errand-name')

        output, exit_code = bosh_runner.run(
          'run-errand fake-errand-name --keep-alive',
          return_exit_code: true,
          deployment_name: deployment_name,
        )
        expect(output).to include('fake-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms_with_names_and_count({ 'foobar' => 1, 'fake-errand-name' => 1 }, { deployment_name: deployment_name })

        output, exit_code = bosh_runner.run(
          'run-errand fake-errand-name --keep-alive',
          return_exit_code: true,
          deployment_name: deployment_name,
        )
        expect(output).to include('fake-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms_with_names_and_count({ 'foobar' => 1, 'fake-errand-name' => 1 }, { deployment_name: deployment_name })

        output, exit_code = bosh_runner.run(
          'run-errand fake-errand-name',
          return_exit_code: true,
          deployment_name: deployment_name,
        )
        expect(output).to include('fake-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms_with_names_and_count({ 'foobar' => 1 }, { deployment_name: deployment_name })

        output, exit_code = bosh_runner.run(
          'run-errand second-errand-name',
          return_exit_code: true,
          deployment_name: deployment_name,
        )
        expect(output).to include('second-errand-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms_with_names_and_count({ 'foobar' => 1 }, { deployment_name: deployment_name })
      end
    end
  end

  context 'when the --when-changed flag is specified' do
    with_reset_sandbox_before_each

    before do
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
      bosh_runner.run('run-errand fake-errand-name', return_exit_code: true, deployment_name: deployment_name)
    end

    context 'when the errand configuration has not changed' do
      it 'does not re-run the errand' do
        output, exit_code = bosh_runner.run(
          'run-errand fake-errand-name --when-changed',
          return_exit_code: true,
          deployment_name: deployment_name,
        )
        expect(exit_code).to eq(0)
        errand_task_id = bosh_runner.get_most_recent_task_id
        task_result = bosh_runner.run("task #{errand_task_id} --result", deployment_name: deployment_name)
        expect(task_result).to_not include('{"exit_code":0,"stdout":"","stderr":"","logs":{}}')
        expect(output).not_to match('Creating missing vms')
      end
    end

    context 'when the errand configuration has changed' do
      it 'reruns the errand' do
        instance_group = manifest_hash['instance_groups'].find { |ig| ig['name'] == 'fake-errand-name' }['jobs'].first
        instance_group['properties'] = {
          'errand1' => {
            'exit_code' => 0,
            'stdout' => "new-stdout\nadditional-stdout",
            'stderr' => 'new-stderr',
            'run_package_file' => true,
          },
        }

        deploy_simple_manifest(manifest_hash: manifest_hash)

        output, exit_code = bosh_runner.run(
          'run-errand fake-errand-name --when-changed',
          return_exit_code: true,
          deployment_name: deployment_name,
        )
        expect(exit_code).to eq(0)
        expect(output).to match('Creating missing vms') # output should indicate errand runs
        errand_task_id = bosh_runner.get_most_recent_task_id
        task_result = bosh_runner.run("task #{errand_task_id} --result", deployment_name: deployment_name)
        expect(task_result).to match('"exit_code":0')
        expect(task_result).to match(/"stdout":"job=fake-errand-name index=0 id=.{36}\\nnew-stdout\\nadditional-stdout/)
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
        manifest_hash['instance_groups'].delete(manifest_hash['instance_groups'].find { |i| i['name'] == 'foobar' })
        errand_job = manifest_hash['instance_groups'].find { |i| i['name'] == 'fake-errand-name' }
        errand_job_network_a = errand_job['networks'].find { |i| i['name'] == 'a' }
        errand_job_network_a['static_ips'] = [static_ip]

        manifest_hash
      end

      let(:cloud_config_hash) do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        # set the errand job to have a static ip to trigger the network update
        # at errand run time.
        network_a = cloud_config_hash['networks'].find { |i| i['name'] == 'a' }
        network_a_subnet = network_a['subnets'].first
        network_a_subnet['reserved'] = [
          '192.168.1.2 - 192.168.1.10',
          '192.168.1.14 - 192.168.1.254',
        ]
        network_a_subnet['static'] = [static_ip]

        # setting the size of the pool causes the empty vm to be created
        # at deploy time, and this vm will not have the static IP the job has requested
        # When the errand runs it will try to reuse this unassigned vm and it will
        # require network update since it has static IP.
        vm_type_a = cloud_config_hash['vm_types'].find { |i| i['name'] == 'a' }
        vm_type_a['size'] = 1
        cloud_config_hash
      end

      it 'should tear down the VM successfully after running the errand' do
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        _, exit_code = bosh_runner.run('run-errand fake-errand-name', return_exit_code: true, deployment_name: deployment_name)
        expect(exit_code).to eq(0)
      end
    end

    context 'when the number of dynamic IPs is equal to the total number of vms' do
      let(:manifest_hash) do
        Bosh::Spec::Deployments.manifest_with_release.merge(
          'instance_groups' => [{
            'name' => 'fake-errand-name',
            'jobs' => [{
              'release' => 'bosh-release',
              'name' => 'errand_without_package',
            }],
            'vm_type' => 'fake-vm-type',
            'instances' => 1,
            'lifecycle' => 'errand',
            'networks' => [{ 'name' => 'fake-network' }],
            'stemcell' => 'default',
          }],
        )
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
                  'cloud_properties' => {},
                },
              ],
            },
          ],
          'vm_types' => [
            {
              'name' => 'fake-vm-type',
              'size' => 1,
              'cloud_properties' => {},
              'network' => 'fake-network',
              'stemcell' => {
                'name' => 'ubuntu-stemcell',
                'version' => '1',
              },
            },
          ],
        }
      end

      before { deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash) }

      it 'should have enough IPs to recreate the vm' do
        _, exit_code = bosh_runner.run('run-errand fake-errand-name', return_exit_code: true, deployment_name: deployment_name)
        expect(exit_code).to eq(0)
      end
    end
  end

  context 'when errand script exits with 0 exit code' do
    with_reset_sandbox_before_all
    with_tmp_dir_before_all

    it 'returns 0 as exit code from the cli and indicates that errand ran successfully' do
      deploy_from_scratch(
        manifest_hash: Bosh::Spec::Deployments.manifest_with_errand,
        cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config,
      )
      expect_errands('fake-errand-name')

      errand_output, exit_code = bosh_runner.run(
        'run-errand fake-errand-name',
        return_exit_code: true,
        json: true,
        deployment_name: 'errand',
      )
      expect(exit_code).to eq(0)

      output = scrub_random_ids(table(errand_output))

      expect(output[0]['instance']).to match('fake-errand-name/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx')
      expect(output[0]['stdout']).to match('fake-errand-stdout')
      expect(output[0]['stderr']).to match('fake-errand-stderr')
      expect(output[0]['exit_code']).to match('0')

      output = bosh_runner.run('events --object-type errand', deployment_name: 'errand', json: true)
      events = scrub_event_time(scrub_random_cids(scrub_random_ids(table(output))))
      expect(events).to contain_exactly(
        { 'id' => /[0-9]{1,3} <- [0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'run', 'object_type' => 'errand', 'task_id' => /[0-9]{1,3}/, 'object_name' => 'fake-errand-name', 'deployment' => 'errand', 'instance' => 'fake-errand-name/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)', 'context' => 'exit_code: 0', 'error' => '' },
        { 'id' => /[0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'run', 'object_type' => 'errand', 'task_id' => /[0-9]{1,3}/, 'object_name' => 'fake-errand-name', 'deployment' => 'errand', 'instance' => 'fake-errand-name/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)', 'context' => '', 'error' => '' },
      )
    end

    context 'when downloading logs' do
      context 'regular errand' do
        before(:all) do
          deploy_from_scratch(
            manifest_hash: Bosh::Spec::Deployments.manifest_with_errand,
            cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config,
          )
          expect_errands('fake-errand-name')
        end

        it 'shows bin/run stdout and stderr' do
          output = bosh_runner.run(
            "run-errand fake-errand-name --download-logs --logs-dir #{@tmp_dir}",
            json: true,
            deployment_name: 'errand',
          )
          expect(output).to include('fake-errand-stdout')
          expect(output).to include('fake-errand-stderr')
        end

        it 'shows output generated by package script which proves dependent packages are included' do
          output = bosh_runner.run(
            "run-errand fake-errand-name --download-logs --logs-dir #{@tmp_dir}",
            json: true,
            deployment_name: 'errand',
          )
          expect(output).to include('stdout-from-errand1-package')
        end

        it 'downloads errand logs and shows downloaded location' do
          output = bosh_runner.run(
            "run-errand fake-errand-name --download-logs --logs-dir #{@tmp_dir}",
            json: true,
            deployment_name: 'errand',
          )
          expect(output =~ /Downloading resource .* to '(.*fake-errand-name[0-9-]*\.tgz)'/).to_not(be_nil, output)
          logs_file = Bosh::Spec::TarFileInspector.new($1)
          expect(logs_file.file_names).to match_array(%w(./errand1/stdout.log ./custom.log))
          expect(logs_file.smallest_file_size).to be > 0
        end
      end

      context 'utf8 errand output' do
        let(:encoded_emoji1) { '\u{1F600}' }
        let(:encoded_emoji2) do
          '\u{26A0}\u{FE0F}\u{FE0F}\u{FE0F} \u{1F6A8}\u{FE0F}\u{FE0F} \u{26A0}\u{FE0F} \u{1F6A8}\u{FE0F}\u{FE0F}'
        end

        it 'shows output' do
          manifest = Bosh::Spec::Deployments.manifest_with_errand
          manifest['instance_groups'] = [{
            'name' => 'fake-errand-name',
            'jobs' => [
              {
                'release' => 'bosh-release',
                'name' => 'emoji-errand',
              },
            ],
            'lifecycle' => 'errand',
            'vm_type' => 'a',
            'instances' => 1,
            'networks' => [{ 'name' => 'a' }],
            'stemcell' => 'default',
          }]

          deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
          expect_errands('fake-errand-name')

          output = bosh_runner.run(
            "run-errand fake-errand-name --download-logs --logs-dir #{@tmp_dir}",
            json: false,
            deployment_name: 'errand',
          )
          expect(output).to match(/errand is (<bosh-non-ascii-char>|#{encoded_emoji1})/)
          expect(output).to match(/(<bosh-non-ascii-char>|#{encoded_emoji2})/)
        end
      end
    end
  end

  context 'when manifest file is greater than 64Kb' do
    with_reset_sandbox_before_each

    let(:manifest_hash) do
      large_property = 64.times.inject('') { |p| p << 'a' * 1024 } # generates 64Kb string
      manifest = { 'large_property' => large_property }
      manifest.merge(Bosh::Spec::Deployments.manifest_with_errand)
    end

    it 'deploys successfully' do
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)

      _, exit_code = bosh_runner.run('run-errand fake-errand-name', return_exit_code: true, deployment_name: deployment_name)
      expect(exit_code).to eq(0)
    end
  end

  context 'when configured with addons' do
    with_reset_sandbox_before_each
    with_tmp_dir_before_all

    let(:runtime_config_hash) do
      config_hash = Bosh::Spec::Deployments.runtime_config_with_addon
      config_hash['releases'][0]['name'] = 'bosh-release'
      config_hash['releases'][0]['version'] = '0.1-dev'
      config_hash['addons'][0]['jobs'] = [{ 'name' => 'has_drain_script', 'release' => 'bosh-release' }]
      config_hash
    end

    let(:manifest_with_errand) do
      errand = Bosh::Spec::Deployments.manifest_with_errand
      errand['instance_groups'][1]['jobs'] << {
        'release' => 'bosh-release',
        'name' => 'foobar_without_packages',
      }
      errand
    end

    it 'does not stop jobs after the errand has run' do
      deploy_from_scratch(
        manifest_hash: manifest_with_errand,
        runtime_config_hash: runtime_config_hash,
        cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config,
      )
      _, exit_code = bosh_runner.run(
        "run-errand --keep-alive fake-errand-name --download-logs --logs-dir #{@tmp_dir}",
        return_exit_code: true,
        deployment_name: deployment_name,
      )
      expect(exit_code).to eq(0)

      instance = director.instance('fake-errand-name', '0', deployment_name: deployment_name)

      expect(instance.last_known_state).to eq('running')

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{instance.agent_id}.log")
      expect(agent_log.scan('{"protocol":3,"method":"run_script","arguments":["pre-stop",').size).to eq(1)
      expect(agent_log.scan('{"protocol":3,"method":"drain"').size).to eq(1)
      expect(agent_log.scan('{"protocol":3,"method":"stop"').size).to eq(1)
      expect(agent_log.scan('{"protocol":3,"method":"run_script","arguments":["pre-start",').size).to eq(1)
      expect(agent_log.scan('{"protocol":3,"method":"start"').size).to eq(1)
      expect(agent_log.scan('{"protocol":3,"method":"run_script","arguments":["post-start",').size).to eq(1)
      expect(agent_log.scan('{"protocol":3,"method":"run_errand",').size).to eq(1)
      expect(agent_log.scan('{"protocol":3,"method":"fetch_logs",').size).to eq(1)
    end
  end

  context 'errand name != first job' do
    let(:manifest_hash) do
      manifest_hash = Bosh::Spec::Deployments.manifest_with_errand_on_service_instance
      manifest_hash['instance_groups'][0]['jobs'].unshift(
        'release' => 'bosh-release', 'name' => 'foobar',
      )
      manifest_hash
    end

    with_reset_sandbox_before_each

    it 'should run the requested bin/run on the first instance' do
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)

      output, exit_code = bosh_runner.run('run-errand errand1', return_exit_code: true, deployment_name: deployment_name)
      expect(output).to include('fake-errand-stdout')
      expect(exit_code).to eq(0)
    end
  end

  context 'when instance lifecycle = service' do
    with_reset_sandbox_before_each

    let(:manifest_hash) do
      Bosh::Spec::Deployments.simple_manifest_with_instance_groups.merge(
        'instance_groups' => [
          {
            'name' => 'service-with-errand',
            'jobs' => [{
              'release' => 'bosh-release',
              'name' => 'errand1',
              'properties' => {
                'errand1' => {
                  'exit_code' => 0,
                  'stdout' => 'service-errand-stdout',
                  'stderr' => 'service-errand-stderr',
                  'run_package_file' => true,
                },
              },

            }],
            'lifecycle' => 'service',
            'vm_type' => 'a',
            'stemcell' => 'default',
            'instances' => 2,
            'networks' => [{ 'name' => 'a' }],
          },
          {
            'name' => 'errand-with-same-errand-and-multiple-instances',
            'jobs' => [{
              'release' => 'bosh-release',
              'name' => 'errand1',
              'properties' => {
                'errand1' => {
                  'exit_code' => 0,
                  'stdout' => 'service-errand-stdout',
                  'stderr' => 'service-errand-stderr',
                  'run_package_file' => true,
                },
              },
            }],
            'lifecycle' => 'errand',
            'vm_type' => 'a',
            'stemcell' => 'default',
            'instances' => 2,
            'networks' => [{ 'name' => 'a' }],
          },
        ],
      )
    end

    context 'running with /first' do
      it 'runs the errand on the first instance (ordered by uuid)' do
        deploy_from_scratch(manifest_hash: manifest_hash)
        first = director.instances.select { |i| i.instance_group_name == 'service-with-errand' }.map(&:id).min

        # with keep alive, does not delete/create errand vms (always exactly 1 fake-errand-name/0)
        output, exit_code = bosh_runner.run(
          'run-errand errand1 --instance service-with-errand/first',
          return_exit_code: true,
          deployment_name: deployment_name,
        )
        expect(output).to include('service-errand-stdout')
        expect(output).to include("Instance   service-with-errand/#{first}")
        expect(exit_code).to eq(0)
      end
    end
  end

  context 'when running an errand across multiple instances' do
    with_reset_sandbox_before_each

    let(:manifest_hash) do
      errand_instance_spec = {
        'name' => 'errand-with-same-errand-and-multiple-instances',
        'jobs' => [
          {
            'release' => 'bosh-release',
            'name' => 'errand1',
            'properties' => {
              'errand1' => {
                'exit_code' => 0,
                'stdout' => 'service-errand-stdout',
                'stderr' => 'service-errand-stderr',
                'run_package_file' => true,
              },
            },
          },
          {
            'release' => 'bosh-release',
            'name' => 'emoji-errand',
            'properties' => {
              'errand1' => {
                'exit_code' => 0,
                'stdout' => 'service-errand-stdout',
                'stderr' => 'service-errand-stderr',
                'run_package_file' => true,
              },
            },
          },
        ],
        'lifecycle' => 'errand',
        'vm_type' => 'a',
        'stemcell' => 'default',
        'instances' => 1,
        'networks' => [{ 'name' => 'a' }],
      }

      manifest = Bosh::Spec::Deployments.manifest_with_errand_on_service_instance
      manifest['instance_groups'] << errand_instance_spec
      manifest['instance_groups'].first['instances'] = 4

      manifest
    end

    before do
      deploy_from_scratch(manifest_hash: manifest_hash)
    end

    it 'warns if errand is present across multiple instances' do
      output, exit_code = bosh_runner.run('run-errand errand1', return_exit_code: true, deployment_name: deployment_name)
      expect(output).to include('Executing errand on multiple instances in parallel')
      expect(exit_code).to eq(0)
    end

    it 'does not warn if errand is in a single instance' do
      output, exit_code = bosh_runner.run('run-errand emoji-errand', return_exit_code: true, deployment_name: deployment_name)
      expect(output).not_to include('Executing errand on multiple instances in parallel')
      expect(exit_code).to eq(0)
    end
  end

  def expect_errands(*expected_errands)
    output = bosh_runner.run('errands', deployment_name: 'errand')
    expected_errands.each do |errand|
      expect(output).to include(errand)
    end
  end
end
