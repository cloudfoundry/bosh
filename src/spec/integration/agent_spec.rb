require 'spec_helper'
require 'json'

describe 'Agent', type: :integration do
  with_reset_sandbox_before_each

  let(:default_pre_stop_env) do
    {
      'env' => {
        'BOSH_VM_NEXT_STATE' => 'keep',
        'BOSH_INSTANCE_NEXT_STATE' => 'keep',
        'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
      },
    }
  end

  def get_messages_sent_to_agent(output)
    task_id = output.match(/^Task (\d+)$/)[1]
    task_debug = File.read("#{current_sandbox.sandbox_root}/boshdir/tasks/#{task_id}/debug")
    sent_messages = {}
    task_debug.scan(/DirectorJobRunner: SENT: agent\.([^ ]*) (.+)$/).each do |match|
      message = JSON.parse(match[1])
      # get_task may happen one or more times; just ignore it
      next if message['method'] == 'get_task'

      agent_id = match[0]
      sent_messages[agent_id] ||= []
      sent_messages[agent_id] << message
    end
    sent_messages
  end

  describe 'stop' do
    context 'when director calls stop' do
      before do
        manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(instances: 2)
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
      end

      it 'should call these methods in order' do
        output = stop_job('foobar')
        sent_messages = get_messages_sent_to_agent(output)

        sent_messages.each_value do |agent_messages|
          expect(agent_messages.length).to eq(6)
          expect(agent_messages[0]['method']).to eq('get_state')
          expect(agent_messages[1]['method']).to eq('prepare')
          expect(agent_messages[2]['method']).to eq('run_script')
          expect(agent_messages[2]['arguments']).to eq(['pre-stop', default_pre_stop_env])
          expect(agent_messages[3]['method']).to eq('drain')
          expect(agent_messages[4]['method']).to eq('stop')
          expect(agent_messages[5]['method']).to eq('run_script')
          expect(agent_messages[5]['arguments']).to eq(['post-stop', {}])
        end
      end

      context 'when enable_nats_delivered_templates flag is set to TRUE' do
        with_reset_sandbox_before_each(enable_nats_delivered_templates: true)

        before do
          manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(instances: 2)
          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
        end

        it 'sends upload_blob action to agent' do
          output = stop_job('foobar')
          sent_messages = get_messages_sent_to_agent(output)

          sent_messages.each_value do |agent_messages|
            expect(agent_messages.length).to eq(7)
            expect(agent_messages[0]['method']).to eq('get_state')
            expect(agent_messages[1]['method']).to eq('upload_blob')
            expect(agent_messages[2]['method']).to eq('prepare')
            expect(agent_messages[3]['method']).to eq('run_script')
            expect(agent_messages[3]['arguments']).to eq(['pre-stop', default_pre_stop_env])
            expect(agent_messages[4]['method']).to eq('drain')
            expect(agent_messages[5]['method']).to eq('stop')
            expect(agent_messages[6]['method']).to eq('run_script')
            expect(agent_messages[6]['arguments']).to eq(['post-stop', {}])
          end
        end
      end

      context 'calls stop a second time' do
        it 'does not try re-stopping it' do
          stop_job('foobar')
          output = stop_job('foobar')
          sent_messages = get_messages_sent_to_agent(output)
          agent_messages = sent_messages.values[0]

          expect(agent_messages[0]['method']).to eq('get_state')
          expect(agent_messages.length).to eq(1)
        end
      end
    end
  end

  describe 'start' do
    context 'when director calls start' do
      before do
        manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(instances: 1)
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
      end

      context 'starting a new instance' do
        it 'should call these methods in the following order' do
          updated_manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(instances: 2)
          output = deploy_simple_manifest(manifest_hash: updated_manifest_hash)
          sent_messages = get_messages_sent_to_agent(output)

          hash_key1 = sent_messages.keys[0]
          hash_key2 = sent_messages.keys[1]
          first_is_first = sent_messages[hash_key1].length == 2
          agent1 = sent_messages[first_is_first ? hash_key1 : hash_key2]
          agent2 = sent_messages[first_is_first ? hash_key2 : hash_key1]

          expect(agent1.length).to eq(2)
          expect(agent1[0]['method']).to eq('get_state')
          expect(agent1[1]['method']).to eq('run_script')

          expect(agent2[0]['method']).to eq('ping')
          agent2.shift

          # director may make multiple ping calls when agent is slow to start
          agent2.shift while agent2[0]['method'] == 'ping'

          expect(agent2.length).to eq(15)

          expect(agent2[0]['method']).to eq('update_settings')
          expect(agent2[1]['method']).to eq('apply')
          expect(agent2[2]['method']).to eq('get_state')
          expect(agent2[3]['method']).to eq('prepare')
          expect(agent2[4]['method']).to eq('run_script')
          expect(agent2[4]['arguments']).to eq(['pre-stop', default_pre_stop_env])
          expect(agent2[5]['method']).to eq('drain')
          expect(agent2[6]['method']).to eq('stop')
          expect(agent2[7]['method']).to eq('run_script')
          expect(agent2[7]['arguments']).to eq(['post-stop', {}])
          expect(agent2[8]['method']).to eq('update_settings')
          expect(agent2[9]['method']).to eq('apply')
          expect(agent2[10]['method']).to eq('run_script')
          expect(agent2[10]['arguments'][0]).to eq('pre-start')
          expect(agent2[11]['method']).to eq('start')
          expect(agent2[12]['method']).to eq('get_state')
          expect(agent2[13]['method']).to eq('run_script')
          expect(agent2[13]['arguments'][0]).to eq('post-start')
          expect(agent2[14]['method']).to eq('run_script')
          expect(agent2[14]['arguments'][0]).to eq('post-deploy')
        end

        context 'when enable_nats_delivered_templates flag is set to TRUE' do
          with_reset_sandbox_before_each(enable_nats_delivered_templates: true)

          before do
            manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(instances: 1)
            deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
          end

          it 'should call these methods in the following order, including upload blob action' do
            updated_manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(instances: 2)
            output = deploy_simple_manifest(manifest_hash: updated_manifest_hash)
            sent_messages = get_messages_sent_to_agent(output)

            hash_key1 = sent_messages.keys[0]
            hash_key2 = sent_messages.keys[1]
            first_is_first = sent_messages[hash_key1].length == 2
            agent1 = sent_messages[first_is_first ? hash_key1 : hash_key2]
            agent2 = sent_messages[first_is_first ? hash_key2 : hash_key1]

            expect(agent1.length).to eq(2)
            expect(agent1[0]['method']).to eq('get_state')
            expect(agent1[1]['method']).to eq('run_script')

            expect(agent2[0]['method']).to eq('ping')
            agent2.shift

            # director may make multiple ping calls when agent is slow to start
            agent2.shift while agent2[0]['method'] == 'ping'

            expect(agent2.length).to eq(17)

            expect(agent2[0]['method']).to eq('update_settings')
            expect(agent2[1]['method']).to eq('apply')
            expect(agent2[2]['method']).to eq('get_state')
            expect(agent2[3]['method']).to eq('upload_blob')
            expect(agent2[4]['method']).to eq('prepare')
            expect(agent2[5]['method']).to eq('run_script')
            expect(agent2[5]['arguments']).to eq(['pre-stop', default_pre_stop_env])
            expect(agent2[6]['method']).to eq('drain')
            expect(agent2[7]['method']).to eq('stop')
            expect(agent2[8]['method']).to eq('run_script')
            expect(agent2[8]['arguments']).to eq(['post-stop', {}])
            expect(agent2[9]['method']).to eq('update_settings')
            expect(agent2[10]['method']).to eq('upload_blob')
            expect(agent2[11]['method']).to eq('apply')
            expect(agent2[12]['method']).to eq('run_script')
            expect(agent2[12]['arguments']).to eq(['pre-start', {}])
            expect(agent2[13]['method']).to eq('start')
            expect(agent2[14]['method']).to eq('get_state')
            expect(agent2[15]['method']).to eq('run_script')
            expect(agent2[15]['arguments']).to eq(['post-start', {}])
            expect(agent2[16]['method']).to eq('run_script')
            expect(agent2[16]['arguments'][0]).to eq('post-deploy')
          end
        end
      end

      context 'stopping and then starting an existing instance' do
        it 'should call these methods in the following order' do
          stop_job('foobar')
          output = bosh_runner.run('start foobar', deployment_name: 'simple')
          sent_messages = get_messages_sent_to_agent(output)

          agent_messages = sent_messages.values[0]
          expect(agent_messages.length).to eq(9)

          expect(agent_messages[0]['method']).to eq('get_state')
          expect(agent_messages[1]['method']).to eq('prepare')
          expect(agent_messages[2]['method']).to eq('update_settings')
          expect(agent_messages[3]['method']).to eq('apply')
          expect(agent_messages[4]['method']).to eq('run_script')
          expect(agent_messages[4]['arguments']).to eq(['pre-start', {}])
          expect(agent_messages[5]['method']).to eq('start')
          expect(agent_messages[6]['method']).to eq('get_state')
          expect(agent_messages[7]['method']).to eq('run_script')
          expect(agent_messages[7]['arguments']).to eq(['post-start', {}])
          expect(agent_messages[8]['method']).to eq('run_script')
          expect(agent_messages[8]['arguments'][0]).to eq('post-deploy')
        end

        context 'when enable_nats_delivered_templates flag is set to TRUE' do
          with_reset_sandbox_before_each(enable_nats_delivered_templates: true)

          before do
            manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(instances: 1)
            deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
          end

          it 'should call these methods in the following order, including upload blob action' do
            stop_job('foobar')
            output = bosh_runner.run('start foobar', deployment_name: 'simple')
            sent_messages = get_messages_sent_to_agent(output)

            agent_messages = sent_messages.values[0]
            expect(agent_messages.length).to eq(11)

            expect(agent_messages[0]['method']).to eq('get_state')
            expect(agent_messages[1]['method']).to eq('upload_blob')
            expect(agent_messages[2]['method']).to eq('prepare')
            expect(agent_messages[3]['method']).to eq('update_settings')
            expect(agent_messages[4]['method']).to eq('upload_blob')
            expect(agent_messages[5]['method']).to eq('apply')
            expect(agent_messages[6]['method']).to eq('run_script')
            expect(agent_messages[6]['arguments']).to eq(['pre-start', {}])
            expect(agent_messages[7]['method']).to eq('start')
            expect(agent_messages[8]['method']).to eq('get_state')
            expect(agent_messages[9]['method']).to eq('run_script')
            expect(agent_messages[9]['arguments']).to eq(['post-start', {}])
            expect(agent_messages[10]['method']).to eq('run_script')
            expect(agent_messages[10]['arguments'][0]).to eq('post-deploy')
          end
        end
      end
    end
  end

  describe 'deploy' do
    let(:manifest_hash) do
      manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(instances: 1)
      manifest_hash['instance_groups'][0]['jobs'][0]['properties'] = {
        'test_property' => 5,
      }
      manifest_hash
    end

    context 'updating the deployment with a property change' do
      it 'should call these methods in the following order' do
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
        manifest_hash['instance_groups'][0]['jobs'][0]['properties']['test_property'] = 7
        output = deploy_simple_manifest(manifest_hash: manifest_hash)
        sent_messages = get_messages_sent_to_agent(output)

        agent_messages = sent_messages.values[0]
        expect(agent_messages.length).to eq(13)

        expect(agent_messages[0]['method']).to eq('get_state')
        expect(agent_messages[1]['method']).to eq('prepare')
        expect(agent_messages[2]['method']).to eq('run_script')
        expect(agent_messages[2]['arguments']).to eq(['pre-stop', default_pre_stop_env])
        expect(agent_messages[3]['method']).to eq('drain')
        expect(agent_messages[4]['method']).to eq('stop')
        expect(agent_messages[5]['method']).to eq('run_script')
        expect(agent_messages[5]['arguments']).to eq(['post-stop', {}])
        expect(agent_messages[6]['method']).to eq('update_settings')
        expect(agent_messages[7]['method']).to eq('apply')
        expect(agent_messages[8]['method']).to eq('run_script')
        expect(agent_messages[8]['arguments']).to eq(['pre-start', {}])
        expect(agent_messages[9]['method']).to eq('start')
        expect(agent_messages[10]['method']).to eq('get_state')
        expect(agent_messages[11]['method']).to eq('run_script')
        expect(agent_messages[11]['arguments']).to eq(['post-start', {}])
        expect(agent_messages[12]['method']).to eq('run_script')
        expect(agent_messages[12]['arguments'][0]).to eq('post-deploy')
      end
    end

    context 'when enable_nats_delivered_templates is set to TRUE' do
      with_reset_sandbox_before_each(enable_nats_delivered_templates: true)

      before do
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
      end

      it 'should call these methods in the following order' do
        manifest_hash['instance_groups'][0]['jobs'][0]['properties']['test_property'] = 7
        output = deploy_simple_manifest(manifest_hash: manifest_hash)
        sent_messages = get_messages_sent_to_agent(output)

        agent_messages = sent_messages.values[0]
        expect(agent_messages.length).to eq(15)

        expect(agent_messages[0]['method']).to eq('get_state')
        expect(agent_messages[1]['method']).to eq('upload_blob')
        expect(agent_messages[2]['method']).to eq('prepare')
        expect(agent_messages[3]['method']).to eq('run_script')
        expect(agent_messages[3]['arguments']).to eq(['pre-stop', default_pre_stop_env])
        expect(agent_messages[4]['method']).to eq('drain')
        expect(agent_messages[5]['method']).to eq('stop')
        expect(agent_messages[6]['method']).to eq('run_script')
        expect(agent_messages[6]['arguments']).to eq(['post-stop', {}])
        expect(agent_messages[7]['method']).to eq('update_settings')
        expect(agent_messages[8]['method']).to eq('upload_blob')
        expect(agent_messages[9]['method']).to eq('apply')
        expect(agent_messages[10]['method']).to eq('run_script')
        expect(agent_messages[10]['arguments']).to eq(['pre-start', {}])
        expect(agent_messages[11]['method']).to eq('start')
        expect(agent_messages[12]['method']).to eq('get_state')
        expect(agent_messages[13]['method']).to eq('run_script')
        expect(agent_messages[13]['arguments']).to eq(['post-start', {}])
        expect(agent_messages[14]['method']).to eq('run_script')
        expect(agent_messages[14]['arguments'][0]).to eq('post-deploy')
      end
    end

    context 'when post-deploy is enabled' do
      with_reset_sandbox_before_each

      it 'calls post-deploy' do
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)

        manifest_hash['instance_groups'][0]['jobs'][0]['properties']['test_property'] = 7
        output = deploy_simple_manifest(manifest_hash: manifest_hash)
        sent_messages = get_messages_sent_to_agent(output)

        agent_messages = sent_messages.values[0]
        expect(agent_messages.length).to eq(13)

        expect(agent_messages[0]['method']).to eq('get_state')
        expect(agent_messages[1]['method']).to eq('prepare')
        expect(agent_messages[2]['method']).to eq('run_script')
        expect(agent_messages[2]['arguments']).to eq(['pre-stop', default_pre_stop_env])
        expect(agent_messages[3]['method']).to eq('drain')
        expect(agent_messages[4]['method']).to eq('stop')
        expect(agent_messages[5]['method']).to eq('run_script')
        expect(agent_messages[5]['arguments']).to eq(['post-stop', {}])
        expect(agent_messages[6]['method']).to eq('update_settings')
        expect(agent_messages[7]['method']).to eq('apply')
        expect(agent_messages[8]['method']).to eq('run_script')
        expect(agent_messages[8]['arguments']).to eq(['pre-start', {}])
        expect(agent_messages[9]['method']).to eq('start')
        expect(agent_messages[10]['method']).to eq('get_state')
        expect(agent_messages[11]['method']).to eq('run_script')
        expect(agent_messages[11]['arguments']).to eq(['post-start', {}])
        expect(agent_messages[12]['method']).to eq('run_script')
        expect(agent_messages[12]['arguments']).to eq(['post-deploy', {}])
      end

      context 'and enable_nats_delivered_templates is set to TRUE' do
        with_reset_sandbox_before_each(enable_nats_delivered_templates: true)

        before do
          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
        end

        it 'calls post-deploy with upload_blobs' do
          manifest_hash['instance_groups'][0]['jobs'][0]['properties']['test_property'] = 7
          output = deploy_simple_manifest(manifest_hash: manifest_hash)
          sent_messages = get_messages_sent_to_agent(output)

          agent_messages = sent_messages.values[0]
          expect(agent_messages.length).to eq(15)

          expect(agent_messages[0]['method']).to eq('get_state')
          expect(agent_messages[1]['method']).to eq('upload_blob')
          expect(agent_messages[2]['method']).to eq('prepare')
          expect(agent_messages[3]['method']).to eq('run_script')
          expect(agent_messages[3]['arguments']).to eq(['pre-stop', default_pre_stop_env])
          expect(agent_messages[4]['method']).to eq('drain')
          expect(agent_messages[5]['method']).to eq('stop')
          expect(agent_messages[6]['method']).to eq('run_script')
          expect(agent_messages[6]['arguments']).to eq(['post-stop', {}])
          expect(agent_messages[7]['method']).to eq('update_settings')
          expect(agent_messages[8]['method']).to eq('upload_blob')
          expect(agent_messages[9]['method']).to eq('apply')
          expect(agent_messages[10]['method']).to eq('run_script')
          expect(agent_messages[10]['arguments'][0]).to eq('pre-start')
          expect(agent_messages[11]['method']).to eq('start')
          expect(agent_messages[12]['method']).to eq('get_state')
          expect(agent_messages[13]['method']).to eq('run_script')
          expect(agent_messages[13]['arguments'][0]).to eq('post-start')
          expect(agent_messages[14]['method']).to eq('run_script')
          expect(agent_messages[14]['arguments'][0]).to eq('post-deploy')
        end
      end
    end

    describe 'pre-stop lifecycle' do
      let(:vm_delete_pre_stop_env) do
        {
          'env' => {
            'BOSH_VM_NEXT_STATE' => 'delete',
            'BOSH_INSTANCE_NEXT_STATE' => 'keep',
            'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
          },
        }
      end

      let(:instance_delete_pre_stop_env) do
        {
          'env' => {
            'BOSH_VM_NEXT_STATE' => 'delete',
            'BOSH_INSTANCE_NEXT_STATE' => 'delete',
            'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
          },
        }
      end

      let(:deployment_delete_pre_stop_env) do
        {
          'env' => {
            'BOSH_VM_NEXT_STATE' => 'delete',
            'BOSH_INSTANCE_NEXT_STATE' => 'delete',
            'BOSH_DEPLOYMENT_NEXT_STATE' => 'delete',
          },
        }
      end

      context 'when deleting a VM' do
        it 'sets the pre-stop environment variables correctly' do
          manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(instances: 1)
          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
          manifest_hash['instance_groups'][0]['jobs'][0]['properties']['test_property'] = 7
          output = deploy_simple_manifest(manifest_hash: manifest_hash, recreate: true)
          sent_messages = get_messages_sent_to_agent(output)

          agent_messages = sent_messages.values[0]
          expect(agent_messages.length).to eq(5)

          expect(agent_messages[0]['method']).to eq('get_state')
          expect(agent_messages[1]['method']).to eq('run_script')
          expect(agent_messages[1]['arguments']).to eq(['pre-stop', vm_delete_pre_stop_env])
          expect(agent_messages[2]['method']).to eq('drain')
          expect(agent_messages[3]['method']).to eq('stop')
          expect(agent_messages[4]['method']).to eq('run_script')
          expect(agent_messages[4]['arguments']).to eq(['post-stop', {}])
        end
      end

      context 'when deleting an instance' do
        it 'sets the pre-stop environment variables correctly' do
          manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(instances: 1)
          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
          manifest_hash['instance_groups'][0]['instances'] = 0

          output = deploy_simple_manifest(manifest_hash: manifest_hash)
          sent_messages = get_messages_sent_to_agent(output)

          agent_messages = sent_messages.values[0]
          expect(agent_messages.length).to eq(5)

          expect(agent_messages[0]['method']).to eq('get_state')
          expect(agent_messages[1]['method']).to eq('run_script')
          expect(agent_messages[1]['arguments']).to eq(['pre-stop', instance_delete_pre_stop_env])
          expect(agent_messages[2]['method']).to eq('drain')
          expect(agent_messages[3]['method']).to eq('stop')
          expect(agent_messages[4]['method']).to eq('run_script')
          expect(agent_messages[4]['arguments']).to eq(['post-stop', {}])
        end
      end

      context 'when deleting a deployment' do
        it 'sets the pre-stop environment variables correctly' do
          manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(instances: 1)
          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
          output = bosh_runner.run(
            'delete-deployment',
            deployment_name: manifest_hash['name'],
            environment_name: current_sandbox.director_url,
          )
          sent_messages = get_messages_sent_to_agent(output)

          agent_messages = sent_messages.values[0]
          expect(agent_messages.length).to eq(4)

          expect(agent_messages[0]['method']).to eq('run_script')
          expect(agent_messages[0]['arguments']).to eq(['pre-stop', deployment_delete_pre_stop_env])
          expect(agent_messages[1]['method']).to eq('drain')
          expect(agent_messages[2]['method']).to eq('stop')
          expect(agent_messages[3]['method']).to eq('run_script')
          expect(agent_messages[3]['arguments']).to eq(['post-stop', {}])
        end
      end

      context 'when no deletion of the VM is required' do
        it 'sets the pre-stop variables correctly' do
          manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(instances: 1)
          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
          manifest_hash['instance_groups'][0]['jobs'][0]['properties']['test_property'] = 7
          output = deploy_simple_manifest(manifest_hash: manifest_hash, recreate: false)
          sent_messages = get_messages_sent_to_agent(output)

          agent_messages = sent_messages.values[0]
          expect(agent_messages.length).to eq(13)

          expect(agent_messages[0]['method']).to eq('get_state')
          expect(agent_messages[1]['method']).to eq('prepare')
          expect(agent_messages[2]['method']).to eq('run_script')
          expect(agent_messages[2]['arguments']).to eq(['pre-stop', default_pre_stop_env])
          expect(agent_messages[3]['method']).to eq('drain')
          expect(agent_messages[4]['method']).to eq('stop')
          expect(agent_messages[5]['method']).to eq('run_script')
          expect(agent_messages[5]['arguments']).to eq(['post-stop', {}])
          expect(agent_messages[6]['method']).to eq('update_settings')
          expect(agent_messages[7]['method']).to eq('apply')
          expect(agent_messages[8]['method']).to eq('run_script')
          expect(agent_messages[8]['arguments']).to eq(['pre-start', {}])
          expect(agent_messages[9]['method']).to eq('start')
          expect(agent_messages[10]['method']).to eq('get_state')
          expect(agent_messages[11]['method']).to eq('run_script')
          expect(agent_messages[11]['arguments']).to eq(['post-start', {}])
          expect(agent_messages[12]['method']).to eq('run_script')
          expect(agent_messages[12]['arguments'][0]).to eq('post-deploy')
        end
      end
    end
  end
end
