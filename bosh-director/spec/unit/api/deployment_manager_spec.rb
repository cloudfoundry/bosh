require 'spec_helper'

module Bosh::Director
  describe Api::DeploymentManager do
    let(:deployment) { Models::Deployment.make(name: 'DEPLOYMENT_NAME') }
    let(:task) { double('Task') }
    let(:username) { 'FAKE_USER' }
    let(:options) { {foo: 'bar'} }

    before do
      Bosh::Director::Models::DirectorAttribute.make(name: 'uuid', value: 'fake-director-uuid')
      allow(Config).to receive(:base_dir).and_return('/tmp')
    end

    describe '#create_deployment' do
      before do
        allow(subject).to receive(:write_file)
      end

      context 'when sufficient disk space is available' do
        before do
          allow(subject).to receive_messages(check_available_disk_space: true)
          allow(SecureRandom).to receive_messages(uuid: 'FAKE_UUID')
          allow(Dir).to receive_messages(tmpdir: 'FAKE_TMPDIR')
        end

        it 'enqueues a DJ job' do
          cloud_config = Models::CloudConfig.make
          runtime_config = Models::RuntimeConfig.make

          create_task = subject.create_deployment(username, 'FAKE_TMPDIR/deployment-FAKE_UUID', cloud_config, runtime_config, deployment, options)

          expect(create_task.description).to eq('create deployment')
          expect(create_task.deployment_name).to eq('DEPLOYMENT_NAME')
        end

        it 'passes a nil cloud config id and runtime config id if there is no cloud config or runtime config' do
          expected_manifest_path = File.join('FAKE_TMPDIR', 'deployment-FAKE_UUID')
          expect(JobQueue).to receive_message_chain(:new, :enqueue) do |_, job_class, _, params, _|
            expect(job_class).to eq(Jobs::UpdateDeployment)
            expect(params).to eq([expected_manifest_path, nil, nil, options])
          end

          subject.create_deployment(username, 'FAKE_TMPDIR/deployment-FAKE_UUID', nil, nil, deployment, options)
        end
      end
    end

    describe '#delete_deployment' do
      it 'enqueues a DJ job' do
        delete_task = subject.delete_deployment(username, deployment, options)

        expect(delete_task.description).to eq('delete deployment DEPLOYMENT_NAME')
        expect(delete_task.deployment_name).to eq('DEPLOYMENT_NAME')
      end
    end

    describe '#find_by_name' do
      it 'finds a deployment by name' do
        expect(subject.find_by_name(deployment.name)).to eq deployment
      end
    end
  end
end
