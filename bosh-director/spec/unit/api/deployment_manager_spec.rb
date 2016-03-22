require 'spec_helper'

module Bosh::Director
  describe Api::DeploymentManager do
    let(:deployment) { double('Deployment', name: 'DEPLOYMENT_NAME') }
    let(:task) { double('Task') }
    let(:username) { 'FAKE_USER' }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }
    let(:options) { { foo: 'bar' } }

    before do
      allow(JobQueue).to receive(:new).and_return(job_queue)
      Bosh::Director::Models::DirectorAttribute.make(name: 'uuid', value: 'fake-director-uuid')
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
          expected_manifest_path = File.join('FAKE_TMPDIR', 'deployment-FAKE_UUID')
          cloud_config = instance_double(Bosh::Director::Models::CloudConfig, id: 123)
          runtime_config = instance_double(Bosh::Director::Models::RuntimeConfig, id: 456)
          allow(job_queue).to receive(:enqueue).and_return(task)

          create_task = subject.create_deployment(username, 'FAKE_TMPDIR/deployment-FAKE_UUID', cloud_config, runtime_config, deployment.name, options)

          expect(create_task).to eq(task)
          expect(job_queue).to have_received(:enqueue).with(
              username, Jobs::UpdateDeployment, 'create deployment', [expected_manifest_path, cloud_config.id, runtime_config.id, options], deployment.name)
        end

        it 'passes a nil cloud config id and runtime config id if there is no cloud config or runtime config' do
          expected_manifest_path = File.join('FAKE_TMPDIR', 'deployment-FAKE_UUID')
          allow(job_queue).to receive(:enqueue).and_return(task)

          subject.create_deployment(username, 'FAKE_TMPDIR/deployment-FAKE_UUID', nil, nil, deployment.name, options)

          expect(job_queue).to have_received(:enqueue).with(
              username, Jobs::UpdateDeployment, 'create deployment', [expected_manifest_path, nil, nil, options], deployment.name)
        end
      end
    end

    describe '#delete_deployment' do
      it 'enqueues a DJ job' do
        expect(job_queue).to receive(:enqueue).with(
          username, Jobs::DeleteDeployment, "delete deployment #{deployment.name}", [deployment.name, options], deployment.name).and_return(task)

        expect(subject.delete_deployment(username, deployment, options)).to eq(task)
      end
    end

    describe '#find_by_name' do
      let(:deployment_lookup) { instance_double('Bosh::Director::Api::DeploymentLookup') }

      before do
        allow(Api::DeploymentLookup).to receive_messages(new: deployment_lookup)
      end

      it 'delegates to DeploymentLookup' do
        expect(deployment_lookup).to receive(:by_name).with(deployment.name).and_return(deployment)
        expect(subject.find_by_name(deployment.name)).to eq deployment
      end
    end

    describe '#find_by_name' do
      let(:deployment_lookup) { instance_double('Bosh::Director::Api::DeploymentLookup') }

      before do
        allow(Api::DeploymentLookup).to receive_messages(new: deployment_lookup)
      end

      it 'delegates to DeploymentLookup' do
        expect(deployment_lookup).to receive(:by_name).with(deployment.name).and_return(deployment)
        expect(subject.find_by_name(deployment.name)).to eq deployment
      end
    end
  end
end
