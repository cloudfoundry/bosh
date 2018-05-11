require_relative '../spec_helper'

describe 'Links with local_dns enabled', type: :integration do
  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: false)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
    cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
    cloud_config_hash['compilation']['az'] = 'z1'
    cloud_config_hash['networks'] << {
      'name' => 'manual-network',
      'type' => 'manual',
      'subnets' => [
        {'range' => '10.10.0.0/24',
         'gateway' => '10.10.0.1',
         'az' => 'z1'}]
    }
    cloud_config_hash['networks'] << {
      'name' => 'dynamic-network',
      'type' => 'dynamic',
      'subnets' => [{'az' => 'z1'}]
    }

    cloud_config_hash
  end

  let(:api_instance_group_spec) do
    spec = Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'my_api',
      jobs: [{'name' => 'api_server', 'consumes' => {
        'db' => {'from' => 'db'}
      }}],
      instances: 1
    )
    spec['networks'] = [{ 'name' => 'manual-network'}]
    spec['azs'] = ['z1']
    spec
  end

  let(:mysql_instance_group_spec) do
    spec = Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'mysql',
      jobs: [{'name' => 'database'}],
      instances: 1,
      static_ips: ['192.168.1.10']
    )
    spec['azs'] = ['z1']
    spec['networks'] = [{ 'name' => provider_network_name}]
    spec
  end

  let(:provider_network_name) { 'manual-network' }

  let(:manifest) do
    manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest['instance_groups'] = [api_instance_group_spec, mysql_instance_group_spec]
    manifest
  end

  context 'when use_dns_addresses director flag is TRUE' do
    with_reset_sandbox_before_each(local_dns: {'enabled' => true, 'include_index' => false, 'use_dns_addresses' => true})

    before do
      upload_links_release
      upload_stemcell

      upload_cloud_config(cloud_config_hash: cloud_config)
    end

    context 'when job requires link' do
      context 'when link is provided' do
        context 'when network is manual' do
          it 'outputs dns address when accessing instance.address of the link' do
            deploy_simple_manifest(manifest_hash: manifest)
            instances = director.instances
            api_instance = director.find_instance(instances, 'my_api', '0')
            mysql_0_instance = director.find_instance(instances, 'mysql', '0')
            template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))
            addresses = template['databases']['main'].map do |elem|
              elem['address']
            end
            expect(addresses).to eq(["#{mysql_0_instance.id}.mysql.manual-network.simple.bosh"])
          end

          context 'when deployment manifest features specifies use_dns_addresses to FALSE' do
            before do
              manifest['features'] = { 'use_dns_addresses' => false }
            end

            it 'outputs ip address when accessing instance.address of the link' do
              deploy_simple_manifest(manifest_hash: manifest)
              instances = director.instances
              api_instance = director.find_instance(instances, 'my_api', '0')
              template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))
              addresses = template['databases']['main'].map do |elem|
                elem['address']
              end
              expect(addresses).to eq(['10.10.0.3'])
            end
          end

          context "when 'ip_addresses' is set to true on the consumer jobs link options" do
            before do
              api_instance_group_spec['jobs'][0]['consumes']['db']['ip_addresses'] = true
            end

            it 'outputs ip addresses when accessing instance.address of the link' do
              deploy_simple_manifest(manifest_hash: manifest)

              instances = director.instances
              api_instance = director.find_instance(instances, 'my_api', '0')

              template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))

              addresses = template['databases']['main'].map do |elem|
                elem['address']
              end

              expect(addresses).to eq(['10.10.0.3'])
            end

            context 'when deployment manifest features specifies use_dns_addresses to TRUE' do
              before do
                manifest['features'] = {'use_dns_addresses' => true}
              end

              it 'outputs ip address when accessing instance.address of the link' do
                deploy_simple_manifest(manifest_hash: manifest)

                instances = director.instances
                api_instance = director.find_instance(instances, 'my_api', '0')

                template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))

                addresses = template['databases']['main'].map do |elem|
                  elem['address']
                end

                expect(addresses).to eq(['10.10.0.3'])
              end
            end
          end
        end

        context 'when network is dynamic' do
          let(:provider_network_name) { 'dynamic-network' }

          context "when 'ip_addresses' is set to true on the consumer jobs link options" do
            before do
              api_instance_group_spec['jobs'][0]['consumes']['db']['ip_addresses'] = true
            end

            it 'logs to debug that IP address is not available for the link provider instance' do
              deploy_output = deploy_simple_manifest(manifest_hash: manifest)
              task_id = Bosh::Spec::OutputParser.new(deploy_output).task_id
              task_debug_logs = bosh_runner.run("task --debug #{task_id}")
              mysql_instance = director.find_instance(director.instances, 'mysql', '0')

              expect(task_debug_logs).to match("DirectorJobRunner: IP address not available for the link provider instance: mysql/#{mysql_instance.id}")
            end

            it 'logs to events that IP address is not available for the link provider instance' do
              deploy_output = deploy_simple_manifest(manifest_hash: manifest)
              task_id = Bosh::Spec::OutputParser.new(deploy_output).task_id
              task_event_logs = bosh_runner.run("task --event #{task_id}")
              mysql_instance = director.find_instance(director.instances, 'mysql', '0')

              expect(task_event_logs).to match("\"type\":\"warning\",\"message\":\"IP address not available for the link provider instance: mysql/#{mysql_instance.id}\"")
            end
          end
        end

        context 'using link.address helper' do
          let(:job_link_overrided_spec) do
            instance_group_spec = Bosh::Spec::NewDeployments.simple_instance_group(
              name: 'my_api',
              jobs: [
                {
                  'name' => 'api_server',
                  'consumes' => {
                    'db' => {
                      'address' => 'broker.external-db.com',
                      'instances' => [],
                      'properties' => {'foo' => 'bar'},
                    },
                    'backup_db' => {
                      'address' => 'nothing',
                      'instances' => [],
                      'properties' => {'foo' => 'bar'},
                    }
                  }
                }],
              instances: 1
            )
            instance_group_spec['networks'] = [{ 'name' => 'manual-network'}]
            instance_group_spec['azs'] = ['z1']
            instance_group_spec
          end

          let(:rendered_template) do
            api_instance = director.find_instance(director.instances, 'my_api', '0')
            YAML.load(api_instance.read_job_template('api_server', 'config.yml'))
          end

          it 'returns a query string for az and healthiness' do
            deploy_simple_manifest(manifest_hash: manifest)
            expect(rendered_template['db_az_link']['address']).to eq('q-a1s0.mysql.manual-network.simple.bosh')
            expect(rendered_template['optional_backup_link'][0]['address']).to eq('q-s0.mysql.manual-network.simple.bosh')
          end

          it 'uses a short DNS name if manifest so indicates' do
            manifest['features'] = {'use_short_dns_addresses' => true}
            deploy_simple_manifest(manifest_hash: manifest)
            expect(rendered_template['db_az_link']['address']).to match(/q-a1n\ds0.q-g2.bosh/)
          end

          it 'respects address provided in a manual link' do
            manifest['instance_groups'] = [job_link_overrided_spec]
            deploy_simple_manifest(manifest_hash: manifest)
            expect(rendered_template['db_az_link']['address']).to eq('broker.external-db.com')
            expect(rendered_template['optional_backup_link'][0]['address']).to eq('nothing')
          end
        end

        context 'using link.instances[x].address helper' do
          let(:rendered_template) do
            api_instance = director.find_instance(director.instances, 'my_api', '0')
            YAML.load(api_instance.read_job_template('api_server', 'config.yml'))
          end

          let(:dns_address) { nil }
          let(:features_hash) {{ 'use_dns_addresses' => true, 'use_short_dns_addresses' => true }}

          shared_examples 'matching DNS names' do
            it 'expects DNS address to match' do
              if features_hash
                manifest['features'] = features_hash
              end

              deploy_simple_manifest(manifest_hash: manifest)
              expect(rendered_template['databases']['main'][0]['address']).to match(dns_address)
            end
          end

          context 'uses short DNS name if manifest so indicates' do
            let(:dns_address) { /q-m\dn\ds0.q-g2.bosh/ }
            it_should_behave_like 'matching DNS names'
          end

          context 'use FULL DNS if manifest doesnt specify short DNS' do
            let(:dns_address) { /.mysql.manual-network.simple.bosh/ }
            let(:features_hash) { nil }
            it_should_behave_like 'matching DNS names'
          end


          # it 'uses short DNS name if manifest so indicates' do
          #   manifest['features'] = {'use_short_dns_addresses' => true}
          #   deploy_simple_manifest(manifest_hash: manifest)
          #   expect(rendered_template['databases']['main'][0]['address']).to match(/q-m\dn\ds0.q-g2.bosh/)
          # end

          # it 'use FULL DNS if manifest doesnt specify short DNS' do
          #   deploy_simple_manifest(manifest_hash: manifest)
          #   expect(rendered_template['databases']['main'][0]['address']).to match(/q-s0.mysql.manual-network.simple.bosh/)
          # end
        end
      end

      context 'when having cross deployment links' do
        let(:mysql_instance_group_spec) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'mysql',
            jobs: [
              {
                'name' => 'database',
                'provides' => {
                  'db' => {
                    'as' => 'mysql_link',
                    'shared' => true
                  }
                }
              }
            ],
            instances: 1,
            static_ips: ['192.168.1.10']
          )
          spec['azs'] = ['z1']
          spec['networks'] = [{ 'name' => network_name}]
          spec
        end

        let(:api_instance_group_spec) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'my_api',
            jobs: [
              {
                'name' => 'api_server',
                'consumes' => {
                  'db' => {
                    'from' => 'mysql_link',
                    'deployment' => 'provider_deployment',
                  },
                  'backup_db' => {
                    'from' => 'mysql_link',
                    'deployment' => 'provider_deployment'
                  }
                }
              }],
            instances: 1
          )
          spec['networks'] = [{ 'name' => network_name}]
          spec['azs'] = ['z1']
          spec
        end

        let(:provider_deployment_manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'provider_deployment')
          manifest['instance_groups'] = [mysql_instance_group_spec]
          manifest
        end

        let(:consumer_deployment_manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'consumer_deployment')
          manifest['instance_groups'] = [api_instance_group_spec]
          manifest
        end

        context 'when provider job network is manual' do
          let(:network_name) { 'manual-network' }

          it 'outputs dns address when accessing instance.address of the link' do
            deploy_simple_manifest(manifest_hash: provider_deployment_manifest)
            deploy_simple_manifest(manifest_hash: consumer_deployment_manifest)

            instances = director.instances(deployment_name: 'consumer_deployment')
            api_instance = director.find_instance(instances, 'my_api', '0')
            template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))

            provider_instances = director.instances(deployment_name: 'provider_deployment')
            mysql_instance = director.find_instance(provider_instances, 'mysql', '0')

            addresses = template['databases']['backup'].map do |elem|
              elem['address']
            end

            expect(addresses).to eq(["#{mysql_instance.id}.mysql.manual-network.provider-deployment.bosh"])
          end

          context "when consumer job sets 'ip_addresses' to true in its manifest link options" do
            before do
              api_instance_group_spec['jobs'][0]['consumes']['db']['ip_addresses'] = true
            end

            it 'outputs ip address when accessing instance.address of the link' do
              deploy_simple_manifest(manifest_hash: provider_deployment_manifest)
              deploy_simple_manifest(manifest_hash: consumer_deployment_manifest)

              instances = director.instances(deployment_name: 'consumer_deployment')
              api_instance = director.find_instance(instances, 'my_api', '0')
              template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))

              addresses = template['databases']['main'].map do |elem|
                elem['address']
              end

              expect(addresses).to eq(['10.10.0.2'])
            end
          end
        end

        context 'when provider job network is dynamic' do
          let(:network_name) { 'dynamic-network' }

          it 'outputs dns address when accessing instance.address of the link' do
            deploy_simple_manifest(manifest_hash: provider_deployment_manifest)
            deploy_simple_manifest(manifest_hash: consumer_deployment_manifest)

            instances = director.instances(deployment_name: 'consumer_deployment')
            api_instance = director.find_instance(instances, 'my_api', '0')
            template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))

            provider_instances = director.instances(deployment_name: 'provider_deployment')
            mysql_instance = director.find_instance(provider_instances, 'mysql', '0')

            addresses = template['databases']['main'].map do |elem|
              elem['address']
            end

            expect(addresses).to eq(["#{mysql_instance.id}.mysql.dynamic-network.provider-deployment.bosh"])
          end

          context "when consumer job set 'ip_addresses' to true in its manifest link options" do
            before do
              api_instance_group_spec['jobs'][0]['consumes']['db']['ip_addresses'] = true
            end

            it 'logs to debug that IP address is not available for the link provider instance' do
              deploy_simple_manifest(manifest_hash: provider_deployment_manifest)
              consumer_deployment_output = deploy_simple_manifest(manifest_hash: consumer_deployment_manifest)

              task_id = Bosh::Spec::OutputParser.new(consumer_deployment_output).task_id
              task_debug_logs = bosh_runner.run("task --debug #{task_id}")
              instances = director.instances(deployment_name: 'provider_deployment')
              mysql_instance = director.find_instance(instances, 'mysql', '0')

              expect(task_debug_logs).to match("DirectorJobRunner: IP address not available for the link provider instance: mysql/#{mysql_instance.id}")
            end

            it 'logs to events that IP address is not available for the link provider instance' do
              deploy_simple_manifest(manifest_hash: provider_deployment_manifest)
              consumer_deployment_output = deploy_simple_manifest(manifest_hash: consumer_deployment_manifest)

              task_id = Bosh::Spec::OutputParser.new(consumer_deployment_output).task_id
              task_event_logs = bosh_runner.run("task --event #{task_id}")
              instances = director.instances(deployment_name: 'provider_deployment')
              mysql_instance = director.find_instance(instances, 'mysql', '0')

              expect(task_event_logs).to match("\"type\":\"warning\",\"message\":\"IP address not available for the link provider instance: mysql/#{mysql_instance.id}\"")
            end
          end
        end
      end
    end
  end

  context 'when use_dns_addresses director flag is FALSE' do
    with_reset_sandbox_before_each(local_dns: {'enabled' => true, 'include_index' => false, 'use_dns_addresses' => false} )

    before do
      upload_links_release
      upload_stemcell

      upload_cloud_config(cloud_config_hash: cloud_config)
    end

    it 'outputs ip address when accessing instance.address of the link' do
      deploy_simple_manifest(manifest_hash: manifest)

      instances = director.instances
      api_instance = director.find_instance(instances, 'my_api', '0')

      template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))

      addresses = template['databases']['main'].map do |elem|
        elem['address']
      end

      expect(addresses).to eq(['10.10.0.3'])
    end

    context 'when deployment manifest features specifies use_dns_addresses to TRUE' do
      before do
        manifest['features'] = {'use_dns_addresses' => true}
      end

      it 'outputs DNS address when accessing instance.address of the link' do
        deploy_simple_manifest(manifest_hash: manifest)
        instances = director.instances
        api_instance = director.find_instance(instances, 'my_api', '0')
        mysql_instance = director.find_instance(instances, 'mysql', '0')
        template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))
        addresses = template['databases']['main'].map do |elem|
          elem['address']
        end
        expect(addresses).to eq(["#{mysql_instance.id}.mysql.manual-network.simple.bosh"])
      end

      context 'when deployment manifest features specifies use_short_dns_addresses to TRUE' do
        before do
          manifest['features']['use_short_dns_addresses'] = true
        end

        it 'outputs an abbreviated DNS address when accessing instance.address of the link' do
          deploy_simple_manifest(manifest_hash: manifest)
          instances = director.instances
          api_instance = director.find_instance(instances, 'my_api', '0')
          template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))
          addresses = template['databases']['main'].map do |elem|
            elem['address']
          end
          expect(addresses.length).to eq(1)
          expect(addresses[0]).to match(/q-m\dn\ds0\.q-g\d\.bosh/)
        end
      end
    end

    context 'when ip_addresses field is explicitly set to FALSE in the consume link section' do
      before do
        api_instance_group_spec['jobs'][0]['consumes']['db']['ip_addresses'] = false
      end

      it 'outputs dns address when accessing instance.address of the link' do
        deploy_simple_manifest(manifest_hash: manifest)

        instances = director.instances
        api_instance = director.find_instance(instances, 'my_api', '0')
        mysql_instance = director.find_instance(instances, 'mysql', '0')

        template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))

        addresses = template['databases']['main'].map do |elem|
          elem['address']
        end

        expect(addresses).to eq(["#{mysql_instance.id}.mysql.manual-network.simple.bosh"])
      end

      context 'when deployment manifest features specifies use_dns_addresses to FALSE' do
        before do
          manifest['features'] = {'use_dns_addresses' => false}
        end

        it 'outputs DNS address when accessing instance.address of the link' do
          deploy_simple_manifest(manifest_hash: manifest)

          instances = director.instances
          api_instance = director.find_instance(instances, 'my_api', '0')
          mysql_instance = director.find_instance(instances, 'mysql', '0')

          template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))
          addresses = template['databases']['main'].map do |elem|
            elem['address']
          end

          expect(addresses).to eq(["#{mysql_instance.id}.mysql.manual-network.simple.bosh"])
        end
      end
    end

    context 'when having cross deployment links' do
      let(:mysql_instance_group_spec) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'mysql',
          jobs: [
            {
              'name' => 'database',
              'provides' => {
                'db' => {
                  'as' => 'mysql_link',
                  'shared' => true
                }
              }
            }
          ],
          instances: 1,
          static_ips: ['192.168.1.10']
        )
        spec['azs'] = ['z1']
        spec['networks'] = [{ 'name' => network_name}]
        spec
      end

      let(:api_instance_group_spec) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'my_api',
          jobs: [
            {
              'name' => 'api_server',
              'consumes' => {
                'db' => {
                  'from' => 'mysql_link',
                  'deployment' => 'provider_deployment',
                },
                'backup_db' => {
                  'from' => 'mysql_link',
                  'deployment' => 'provider_deployment'
                }
              }
            }],
          instances: 1
        )
        spec['networks'] = [{ 'name' => network_name}]
        spec['azs'] = ['z1']
        spec
      end

      let(:provider_deployment_manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'provider_deployment')
        manifest['instance_groups'] = [mysql_instance_group_spec]
        manifest
      end

      let(:consumer_deployment_manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'consumer_deployment')
        manifest['instance_groups'] = [api_instance_group_spec]
        manifest
      end

      context 'when provider job network is manual' do
        let(:network_name) { 'manual-network' }

        it 'outputs ip address when accessing instance.address of the link' do
          deploy_simple_manifest(manifest_hash: provider_deployment_manifest)
          deploy_simple_manifest(manifest_hash: consumer_deployment_manifest)

          instances = director.instances(deployment_name: 'consumer_deployment')
          api_instance = director.find_instance(instances, 'my_api', '0')
          template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))

          addresses = template['databases']['backup'].map do |elem|
            elem['address']
          end

          expect(addresses).to eq(["10.10.0.2"])
        end

        context "when consumer job sets 'ip_addresses' to FALSE in its manifest link options" do
          before do
            api_instance_group_spec['jobs'][0]['consumes']['db']['ip_addresses'] = false
          end

          it 'outputs dns address when accessing instance.address of the link' do
            deploy_simple_manifest(manifest_hash: provider_deployment_manifest)
            deploy_simple_manifest(manifest_hash: consumer_deployment_manifest)

            instances = director.instances(deployment_name: 'consumer_deployment')
            api_instance = director.find_instance(instances, 'my_api', '0')
            template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))

            provider_instances = director.instances(deployment_name: 'provider_deployment')
            mysql_instance = director.find_instance(provider_instances, 'mysql', '0')

            addresses = template['databases']['main'].map do |elem|
              elem['address']
            end

            expect(addresses).to eq(["#{mysql_instance.id}.mysql.manual-network.provider-deployment.bosh"])
          end
        end
      end

      context 'when provider job network is dynamic' do
        let(:network_name) { 'dynamic-network' }

        it 'logs to debug that IP address is not available for the link provider instance' do
          deploy_simple_manifest(manifest_hash: provider_deployment_manifest)
          consumer_deployment_output = deploy_simple_manifest(manifest_hash: consumer_deployment_manifest)

          task_id = Bosh::Spec::OutputParser.new(consumer_deployment_output).task_id
          task_debug_logs = bosh_runner.run("task --debug #{task_id}")
          instances = director.instances(deployment_name: 'provider_deployment')
          mysql_instance = director.find_instance(instances, 'mysql', '0')

          expect(task_debug_logs).to match("DirectorJobRunner: IP address not available for the link provider instance: mysql/#{mysql_instance.id}")
        end

        it 'logs to events that IP address is not available for the link provider instance' do
          deploy_simple_manifest(manifest_hash: provider_deployment_manifest)
          consumer_deployment_output = deploy_simple_manifest(manifest_hash: consumer_deployment_manifest)

          task_id = Bosh::Spec::OutputParser.new(consumer_deployment_output).task_id
          task_event_logs = bosh_runner.run("task --event #{task_id}")
          instances = director.instances(deployment_name: 'provider_deployment')
          mysql_instance = director.find_instance(instances, 'mysql', '0')

          expect(task_event_logs).to match("\"type\":\"warning\",\"message\":\"IP address not available for the link provider instance: mysql/#{mysql_instance.id}\"")
        end

        context "when consumer job set 'ip_addresses' to FALSE in its manifest link options" do
          before do
            api_instance_group_spec['jobs'][0]['consumes']['db']['ip_addresses'] = false
          end

          it 'outputs dns address when accessing instance.address of the link' do
            deploy_simple_manifest(manifest_hash: provider_deployment_manifest)
            deploy_simple_manifest(manifest_hash: consumer_deployment_manifest)

            instances = director.instances(deployment_name: 'consumer_deployment')
            api_instance = director.find_instance(instances, 'my_api', '0')
            template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))

            provider_instances = director.instances(deployment_name: 'provider_deployment')
            mysql_instance = director.find_instance(provider_instances, 'mysql', '0')

            addresses = template['databases']['main'].map do |elem|
              elem['address']
            end

            expect(addresses).to eq(["#{mysql_instance.id}.mysql.dynamic-network.provider-deployment.bosh"])
          end
        end
      end
    end
  end
end
