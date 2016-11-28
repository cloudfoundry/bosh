require 'spec_helper'
require 'json'

describe 'Agent', type: :integration do
  with_reset_sandbox_before_each

  def get_messages_sent_to_agent(output)
    task_id = output.match(/^Task (\d+) done$/)[1]
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
        manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 2)
        deploy_from_scratch(manifest_hash: manifest_hash)
      end

      it 'should call these methods in order' do
        output = stop_job('foobar')
        sent_messages = get_messages_sent_to_agent(output)

        sent_messages.each_value do |agent_messages|
          expect(agent_messages[0]['method']).to eq('get_state')
          expect(agent_messages[1]['method']).to eq('prepare')
          expect(agent_messages[2]['method']).to eq('drain')
          expect(agent_messages[3]['method']).to eq('stop')
          expect(agent_messages.length).to eq(4)
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
        manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
        deploy_from_scratch(manifest_hash: manifest_hash)
      end

      context 'starting a new instance' do
        it 'should call these methods in the following order' do
          updated_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 2)
          output = deploy_simple_manifest(manifest_hash: updated_manifest_hash)
          sent_messages = get_messages_sent_to_agent(output)

          hash_key1 = sent_messages.keys[0]
          hash_key2 = sent_messages.keys[1]
          first_is_first = sent_messages[hash_key1].length == 2 ? true : false
          agent1 = sent_messages[first_is_first ? hash_key1 : hash_key2]
          agent2 = sent_messages[first_is_first ? hash_key2 : hash_key1]

          expect(agent1[0]['method']).to eq('get_state')
          expect(agent1[1]['method']).to eq('delete_arp_entries')
          expect(agent1.length).to eq(2)

          expect(agent2[0]['method']).to eq('ping')
          agent2.shift

          # director may make multiple ping calls when agent is slow to start
          while agent2[0]['method'] == 'ping'
            agent2.shift
          end

          expect(agent2[0]['method']).to eq('update_settings')
          expect(agent2[1]['method']).to eq('apply')
          expect(agent2[2]['method']).to eq('get_state')
          expect(agent2[3]['method']).to eq('prepare')
          expect(agent2[4]['method']).to eq('drain')
          expect(agent2[5]['method']).to eq('stop')
          expect(agent2[6]['method']).to eq('update_settings')
          expect(agent2[7]['method']).to eq('apply')
          expect(agent2[8]['method']).to eq('run_script')
          expect(agent2[8]['arguments'][0]).to eq('pre-start')
          expect(agent2[9]['method']).to eq('start')
          expect(agent2[10]['method']).to eq('get_state')
          expect(agent2[11]['method']).to eq('run_script')
          expect(agent2[11]['arguments'][0]).to eq('post-start')
          expect(agent2.length).to eq(12)
        end
      end

      context 'stopping and then starting an existing instance' do
        it 'should call these methods in the following order' do
          stop_job('foobar')
          output = bosh_runner.run('start foobar', {})
          sent_messages = get_messages_sent_to_agent(output)

          agent_messages = sent_messages.values[0]
          expect(agent_messages[0]['method']).to eq('get_state')
          expect(agent_messages[1]['method']).to eq('prepare')
          expect(agent_messages[2]['method']).to eq('update_settings')
          expect(agent_messages[3]['method']).to eq('apply')
          expect(agent_messages[4]['method']).to eq('run_script')
          expect(agent_messages[4]['arguments'][0]).to eq('pre-start')
          expect(agent_messages[5]['method']).to eq('start')
          expect(agent_messages[6]['method']).to eq('get_state')
          expect(agent_messages[7]['method']).to eq('run_script')
          expect(agent_messages[7]['arguments'][0]).to eq('post-start')
          expect(agent_messages.length).to eq(8)
        end
      end
    end
  end

  describe 'deploy' do
    let(:manifest_hash) do
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      manifest_hash['properties'] = {
        'test_property' => 5,
      }
      manifest_hash
    end

    context 'updating the deployment with a property change' do
      before do
        deploy_from_scratch(manifest_hash: manifest_hash)
      end

      it 'should call these methods in the following order' do
        manifest_hash['properties']['test_property'] = 7
        output = deploy_simple_manifest(manifest_hash: manifest_hash)
        sent_messages = get_messages_sent_to_agent(output)

        agent_messages = sent_messages.values[0]
        expect(agent_messages[0]['method']).to eq('get_state')
        expect(agent_messages[1]['method']).to eq('prepare')
        expect(agent_messages[2]['method']).to eq('drain')
        expect(agent_messages[3]['method']).to eq('stop')
        expect(agent_messages[4]['method']).to eq('update_settings')
        expect(agent_messages[5]['method']).to eq('apply')
        expect(agent_messages[6]['method']).to eq('run_script')
        expect(agent_messages[6]['arguments'][0]).to eq('pre-start')
        expect(agent_messages[7]['method']).to eq('start')
        expect(agent_messages[8]['method']).to eq('get_state')
        expect(agent_messages[9]['method']).to eq('run_script')
        expect(agent_messages[9]['arguments'][0]).to eq('post-start')
        expect(agent_messages.length).to eq(10)
      end
    end

    context 'when post-deploy is enabled' do
      with_reset_sandbox_before_each(enable_post_deploy: true)

      before do
        deploy_from_scratch(manifest_hash: manifest_hash)
      end

      it 'calls post-deploy' do
        manifest_hash['properties']['test_property'] = 7
        output = deploy_simple_manifest(manifest_hash: manifest_hash)
        sent_messages = get_messages_sent_to_agent(output)

        agent_messages = sent_messages.values[0]

        expect(agent_messages[0]['method']).to eq('get_state')
        expect(agent_messages[1]['method']).to eq('prepare')
        expect(agent_messages[2]['method']).to eq('drain')
        expect(agent_messages[3]['method']).to eq('stop')
        expect(agent_messages[4]['method']).to eq('update_settings')
        expect(agent_messages[5]['method']).to eq('apply')
        expect(agent_messages[6]['method']).to eq('run_script')
        expect(agent_messages[6]['arguments'][0]).to eq('pre-start')
        expect(agent_messages[7]['method']).to eq('start')
        expect(agent_messages[8]['method']).to eq('get_state')
        expect(agent_messages[9]['method']).to eq('run_script')
        expect(agent_messages[9]['arguments'][0]).to eq('post-start')
        expect(agent_messages[10]['method']).to eq('run_script')
        expect(agent_messages[10]['arguments'][0]).to eq('post-deploy')
        expect(agent_messages.length).to eq(11)
      end
    end
  end
end
