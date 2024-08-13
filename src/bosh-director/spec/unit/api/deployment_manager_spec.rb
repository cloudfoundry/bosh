require 'spec_helper'

module Bosh::Director
  describe Api::DeploymentManager do
    let(:deployment) { FactoryBot.create(:models_deployment, name: 'DEPLOYMENT_NAME') }
    let(:task) { double('Task') }
    let(:username) { 'FAKE_USER' }
    let(:options) do
      { foo: 'bar' }
    end

    before do
      allow(Config).to receive(:base_dir).and_return('/tmp')
    end

    describe '#create_deployment' do
      let(:runtime_configs) { [Models::Config.make(type: 'runtime'), Models::Config.make(type: 'runtime')] }

      it 'enqueues a DJ job' do
        cloud_configs = [Models::Config.make(:cloud)]

        create_task = subject.create_deployment(username, 'manifest', cloud_configs, runtime_configs, deployment, options)

        expect(create_task.description).to eq('create deployment')
        expect(create_task.deployment_name).to eq('DEPLOYMENT_NAME')
        expect(create_task.context_id).to eq('')
      end

      it 'passes empty cloud config id array and an empty runtime config id array if there are no cloud configs or runtime configs' do
        expect(JobQueue).to receive_message_chain(:new, :enqueue) do |_, job_class, _, params, _|
          expect(job_class).to eq(Jobs::UpdateDeployment)
          expect(params).to eq(['manifest', [], [], options])
        end

        subject.create_deployment(username, 'manifest', [], [], deployment, options)
      end

      it 'passes context id' do
        cloud_configs = [Models::Config.make(:cloud)]
        context_id = 'example-context-id'
        create_task = subject.create_deployment(username, 'manifest', cloud_configs, runtime_configs, deployment, options, context_id)

        expect(create_task.context_id).to eq context_id
      end
    end

    describe '#delete_deployment' do
      it 'enqueues a DJ job' do
        delete_task = subject.delete_deployment(username, deployment, options)

        expect(delete_task.description).to eq('delete deployment DEPLOYMENT_NAME')
        expect(delete_task.deployment_name).to eq('DEPLOYMENT_NAME')
      end

      it 'passes context id' do
        context_id = 'example-context-id'
        delete_task = subject.delete_deployment(username, deployment, options, context_id)
        expect(delete_task.context_id).to eq context_id
      end
    end

    describe '#find_by_name' do
      it 'finds a deployment by name' do
        expect(subject.find_by_name(deployment.name)).to eq deployment
      end
    end

    context 'list deployments by name' do
      before do
        release = FactoryBot.create(:models_release)
        deployment = FactoryBot.create(:models_deployment, name: 'b')
        deployment.cloud_configs = [Models::Config.make(:cloud)]
        release_version = FactoryBot.create(:models_release_version, release_id: release.id)
        deployment.add_release_version(release_version)
      end

      describe '#all_by_name_asc_without' do
        context 'when not excluding anything' do
          let(:deployment_relations) do
            {}
          end

          it 'eagerly loads :stemcells, :release_versions, :teams, :cloud_configs' do
            allow(Bosh::Director::Config.db).to receive(:execute).and_call_original

            deployments = subject.all_by_name_asc_without(deployment_relations)

            deployments.first.stemcells
            deployments.first.release_versions.map(&:release)
            deployments.first.teams

            expect(Bosh::Director::Config.db).to have_received(:execute).exactly(6).times
          end

          it 'lists all deployments in alphabetic order' do
            FactoryBot.create(:models_deployment, name: 'c')
            FactoryBot.create(:models_deployment, name: 'a')

            expect(subject.all_by_name_asc_without(deployment_relations).map(&:name)).to eq(%w[a b c])
          end
        end

        context 'does not eagerly load any excluded relation' do
          let(:exclude_configs) { true }
          let(:exclude_releases) { true }
          let(:exclude_stemcells) { true }
          let(:deployment_relations) do
            {
              exclude_configs: exclude_configs,
              exclude_releases: exclude_releases,
              exclude_stemcells: exclude_stemcells,
            }
          end

          before do
            allow(Bosh::Director::Config.db).to receive(:execute).and_call_original
            subject.all_by_name_asc_without(deployment_relations)
          end

          it 'when excluding all' do
            expect(Bosh::Director::Config.db).to have_received(:execute).exactly(2).times
          end

          context 'when including releases' do
            let(:exclude_releases) { false }

            it 'eagerly loads :releases, :teams' do
              expect(Bosh::Director::Config.db).to have_received(:execute).exactly(4).times
            end
          end

          context 'when including stemcells' do
            let(:exclude_stemcells) { false }

            it 'eagerly loads :stemcells, :teams' do
              expect(Bosh::Director::Config.db).to have_received(:execute).exactly(3).times
            end
          end

          context 'when including configs' do
            let(:exclude_configs) { false }

            it 'eagerly loads :configs, :teams' do
              expect(Bosh::Director::Config.db).to have_received(:execute).exactly(3).times
            end
          end

          context 'when including configs and stemcells' do
            let(:exclude_configs) { false }
            let(:exclude_stemcells) { false }

            it 'eagerly loads :configs, :teams' do
              expect(Bosh::Director::Config.db).to have_received(:execute).exactly(4).times
            end
          end

          it 'lists all deployments in alphabetic order' do
            FactoryBot.create(:models_deployment, name: 'c')
            FactoryBot.create(:models_deployment, name: 'a')

            expect(subject.all_by_name_asc_without(deployment_relations).map(&:name)).to eq(%w[a b c])
          end
        end
      end
    end
  end
end
