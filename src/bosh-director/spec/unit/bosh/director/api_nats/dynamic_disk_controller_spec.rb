require 'spec_helper'

module Bosh::Director
  module ApiNats
    describe DynamicDiskController do
      subject(:controller) { DynamicDiskController.new }
      let(:nats_rpc) { instance_double('Bosh::Director::NatsRpc') }
      let(:task) { instance_double('Bosh::Director::Models::Task', id: 1) }
      let(:job_queue) { instance_double('Bosh::Director::JobQueue', enqueue: task) }
      let(:agent_id) { 'fake_agent_id' }
      let(:reply) { 'inbox.fake' }
      let(:disk_pool_name) { 'fake_disk_pool_name' }
      let(:disk_name) { 'fake_disk_name' }
      let(:disk_size) { 1000 }
      let(:metadata) { { 'some-key' => 'some-value' } }

      before do
        allow(Config).to receive(:nats_rpc).and_return(nats_rpc)
        allow(JobQueue).to receive(:new).and_return(job_queue)
      end

      describe 'handle_provide_disk_request' do
        let(:payload) do
          {
            'disk_pool_name' => disk_pool_name,
            'disk_name' => disk_name,
            'disk_size' => disk_size,
            'metadata' => metadata
          }.compact
        end

        it 'enqueues a ProvideDynamicDisk task' do
          expect(job_queue).to receive(:enqueue).with(
            'bosh-agent',
            Jobs::DynamicDisks::ProvideDynamicDisk,
            'provide dynamic disk',
            [agent_id, reply, disk_name, disk_pool_name, disk_size, metadata],
          ).and_return(task)

          controller.handle_provide_disk_request(agent_id, reply, payload)
        end

        context 'payload is invalid' do
          context 'disk_pool_name is nil' do
            let(:disk_pool_name) { nil }

            it 'raises an error' do
              expect(nats_rpc).to receive(:send_message).with(reply, hash_including({ 'error' => a_string_matching("Required property 'disk_pool_name'") }))
              expect {
                controller.handle_provide_disk_request(agent_id, reply, payload)
              }.to raise_error(ValidationMissingField)
            end
          end

          context 'disk_pool_name is empty' do
            let(:disk_pool_name) { "" }

            it 'raises an error' do
              expect(nats_rpc).to receive(:send_message).with(reply, hash_including({ 'error' => a_string_matching("'disk_pool_name' length") }))
              expect {
                controller.handle_provide_disk_request(agent_id, reply, payload)
              }.to raise_error(ValidationViolatedMin)
            end
          end

          context 'disk_name is nil' do
            let(:disk_name) { nil }

            it 'raises an error' do
              expect(nats_rpc).to receive(:send_message).with(reply, hash_including({ 'error' => a_string_matching("Required property 'disk_name'") }))
              expect {
                controller.handle_provide_disk_request(agent_id, reply, payload)
              }.to raise_error(ValidationMissingField)
            end
          end

          context 'disk_name is empty' do
            let(:disk_name) { "" }

            it 'raises an error' do
              expect(nats_rpc).to receive(:send_message).with(reply, hash_including({ 'error' => a_string_matching("'disk_name' length") }))
              expect {
                controller.handle_provide_disk_request(agent_id, reply, payload)
              }.to raise_error(ValidationViolatedMin)
            end
          end

          context 'disk_size is empty' do
            let(:disk_size) { nil }

            it 'raises an error' do
              expect(nats_rpc).to receive(:send_message).with(reply, hash_including({ 'error' => a_string_matching("Required property 'disk_size'") }))
              expect {
                controller.handle_provide_disk_request(agent_id, reply, payload)
              }.to raise_error(ValidationMissingField)
            end
          end

          context 'disk_size is 0' do
            let(:disk_size) { 0 }

            it 'raises an error' do
              expect(nats_rpc).to receive(:send_message).with(reply, hash_including({ 'error' => a_string_matching("'disk_size' value") }))
              expect {
                controller.handle_provide_disk_request(agent_id, reply, payload)
              }.to raise_error(ValidationViolatedMin)
            end
          end
        end
      end

      describe 'handle_detach_disk_request' do
        let(:payload) do
          {
            'disk_name' => disk_name,
          }.compact
        end

        it 'enqueues a DetachDynamicDisk task' do
          expect(job_queue).to receive(:enqueue).with(
            'bosh-agent',
            Jobs::DynamicDisks::DetachDynamicDisk,
            'detach dynamic disk',
            [reply, disk_name],
          ).and_return(task)

          controller.handle_detach_disk_request(agent_id, reply, payload)
        end

        context 'payload is invalid' do
          context 'disk_name is nil' do
            let(:disk_name) { nil }

            it 'raises an error' do
              expect(nats_rpc).to receive(:send_message).with(reply, hash_including({ 'error' => a_string_matching("Required property 'disk_name'") }))
              expect {
                controller.handle_detach_disk_request(agent_id, reply, payload)
              }.to raise_error(ValidationMissingField)
            end
          end

          context 'disk_name is empty' do
            let(:disk_name) { "" }

            it 'raises an error' do
              expect(nats_rpc).to receive(:send_message).with(reply, hash_including({ 'error' => a_string_matching("'disk_name' length") }))
              expect {
                controller.handle_detach_disk_request(agent_id, reply, payload)
              }.to raise_error(ValidationViolatedMin)
            end
          end
        end
      end

      describe 'handle_delete_disk_request' do
        let(:payload) do
          {
            'disk_name' => disk_name,
          }.compact
        end

        it 'enqueues a DeleteDynamicDisk task' do
          expect(job_queue).to receive(:enqueue).with(
            'bosh-agent',
            Jobs::DynamicDisks::DeleteDynamicDisk,
            'delete dynamic disk',
            [reply, disk_name],
          ).and_return(task)

          controller.handle_delete_disk_request(reply, payload)
        end

        context 'payload is invalid' do
          context 'disk_name is nil' do
            let(:disk_name) { nil }

            it 'raises an error' do
              expect(nats_rpc).to receive(:send_message).with(reply, hash_including({ 'error' => a_string_matching("Required property 'disk_name'") }))
              expect {
                controller.handle_delete_disk_request(reply, payload)
              }.to raise_error(ValidationMissingField)
            end
          end

          context 'disk_name is empty' do
            let(:disk_name) { "" }

            it 'raises an error' do
              expect(nats_rpc).to receive(:send_message).with(reply, hash_including({ 'error' => a_string_matching("'disk_name' length") }))
              expect {
                controller.handle_delete_disk_request(reply, payload)
              }.to raise_error(ValidationViolatedMin)
            end
          end
        end
      end
    end
  end
end