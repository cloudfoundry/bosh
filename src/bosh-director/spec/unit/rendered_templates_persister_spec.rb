require 'spec_helper'

module Bosh::Director
  describe RenderedTemplatesPersister do
    describe 'persist' do
      context 'when enable_nats_delivered_templates flag is set to true' do
        subject(:persister) { RenderedTemplatesPersister.new(blobstore, per_spec_logger) }

        let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }
        let(:instance_plan) { instance_double('Bosh::Director::DeploymentPlan::InstancePlan') }
        let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }

        let(:blobstore_id) { 'generated-blobstore-id' }
        let(:sha1) { 'generated-sha1' }
        let(:configuration_hash) { 'configuraiton-hash' }
        let(:rendered_templates_archive) { Bosh::Director::Core::Templates::RenderedTemplatesArchive.new(blobstore_id, sha1) }

        let(:rendered_job_instance) { instance_double('Bosh::Director::Core::Templates::RenderedJobInstance') }

        let(:compressed_rendered_job_templates) { instance_double('Bosh::Director::Core::Templates::CompressedRenderedJobTemplates') }

        let(:compressed_archived_sha1) { 'my_compressed_archived_sha1' }

        let(:compressed_template_contents) { 'some-text-be-be-saved' }

        let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
        let(:template_contents) { 'compressed contents' }
        let(:mock_base64_contents) { 'base64 contents' }
        let(:blobstore_id) { 'secure-uuid' }

        before do
          allow(Config).to receive(:enable_nats_delivered_templates).and_return(true)

          allow(instance_plan).to receive(:instance).and_return(instance)

          allow(instance).to receive(:rendered_templates_archive=)
          allow(instance).to receive(:agent_client).and_return(agent_client)
          allow(instance).to receive(:model).and_return(FactoryBot.create(:models_instance))
          allow(instance).to receive(:configuration_hash).and_return(configuration_hash)

          allow(SecureRandom).to receive(:uuid).and_return(blobstore_id)
        end

        context 'when rendered templates do not exist for an instance' do
          before do
            allow(instance_plan).to receive(:rendered_templates).and_return(nil)
          end

          it 'returns without sending templates to NATs' do
            expect(agent_client).to_not receive(:upload_blob)

            persister.persist(instance_plan)
          end
        end

        context 'when rendered templates exist for an instance' do
          before do
            allow(instance_plan).to receive(:rendered_templates).and_return(rendered_job_instance)
          end

          it 'should deliver the templates through NATS' do
            allow(Base64).to receive(:encode64).with(template_contents).and_return(mock_base64_contents)
            expect(rendered_job_instance).to receive(:persist_through_agent).with(agent_client).and_return(rendered_templates_archive)

            persister.persist(instance_plan)
          end

          it 'sets the templates archive to the instance plan instance' do
            allow(rendered_job_instance).to receive(:persist_through_agent).with(agent_client).and_return(rendered_templates_archive)
            expect(instance).to receive(:rendered_templates_archive=).with(rendered_templates_archive)

            persister.persist(instance_plan)
          end

          it 'persists the rendered_templates_archive for the instance model' do
            allow(rendered_job_instance).to receive(:persist_through_agent).with(agent_client).and_return(rendered_templates_archive)

            persister.persist(instance_plan)

            rendered_templates_archive = instance.model.latest_rendered_templates_archive
            expect(rendered_templates_archive).to be
            expect(rendered_templates_archive.content_sha1).to eq(configuration_hash)
            expect(rendered_templates_archive.sha1).to eq(sha1)
            expect(rendered_templates_archive.blobstore_id).to eq(blobstore_id)
          end

          context 'when persist through agent fails with AgentUnsupportedAction error' do
            it 'should delegate to persist_to_blobstore' do
              allow(rendered_job_instance).to receive(:persist_through_agent)
                .and_raise(AgentUnsupportedAction.new('Action unsupported'))

              expect(subject).to receive(:persist_on_blobstore)
              persister.persist(instance_plan)
            end
          end

          context 'when persist through agent fails with AgentUploadBlobUnableToOpenFile error' do
            it 'should delegate to persist_to_blobstore' do
              upload_error = AgentUploadBlobUnableToOpenFile.new("'Upload blob' action: failed to open blob")
              allow(rendered_job_instance).to receive(:persist_through_agent).and_raise(upload_error)

              expect(subject).to receive(:persist_on_blobstore)
              persister.persist(instance_plan)
            end
          end
        end
      end

      context 'when enable_nats_delivered_templates flag is set to false' do
        subject(:persister) { RenderedTemplatesPersister.new(blobstore, per_spec_logger) }

        let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }
        let(:instance_plan) { instance_double('Bosh::Director::DeploymentPlan::InstancePlan') }
        let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
        let(:instance_model) { instance_double('Bosh::Director::Models::Instance') }

        let(:latest_rendered_templates_archive) { instance_double('Bosh::Director::Models::RenderedTemplatesArchive') }
        let(:rendered_templates_archive) { instance_double('Bosh::Director::Core::Templates::RenderedTemplatesArchive') }

        let(:rendered_job_instance) { instance_double('Bosh::Director::Core::Templates::RenderedJobInstance') }

        let(:compressed_rendered_job_templates) { instance_double('Bosh::Director::Core::Templates::CompressedRenderedJobTemplates') }

        let(:smurf_time) { Time.now }

        let(:old_blobstore_id) { 'smurfs-blob-id' }
        let(:old_sha1) { 'smurfs-blob-sha1' }

        let(:new_blobstore_id) { 'generated-blobstore-id' }
        let(:new_sha1) { 'generated-sha1' }

        let(:old_configuration_hash) { 'stored-configuration-hash' }
        let(:matching_configuration_hash) { 'stored-configuration-hash' }
        let(:non_matching_configuration_hash) { 'some-other-configuration-hash' }

        let(:compressed_template_contents) { 'some-text-be-be-saved' }

        before do
          allow(instance_plan).to receive(:instance).and_return(instance)
          allow(instance_plan).to receive(:rendered_templates).and_return(rendered_job_instance)

          allow(rendered_job_instance).to receive(:persist_on_blobstore).and_return(rendered_templates_archive)

          allow(rendered_templates_archive).to receive(:blobstore_id).and_return(new_blobstore_id)
          allow(rendered_templates_archive).to receive(:sha1).and_return(new_sha1)

          allow(instance).to receive(:model).and_return(instance_model)
          allow(instance).to receive(:rendered_templates_archive=)

          allow(instance_model).to receive(:latest_rendered_templates_archive).and_return(latest_rendered_templates_archive)
          allow(instance_model).to receive(:add_rendered_templates_archive)

          allow(latest_rendered_templates_archive).to receive(:blobstore_id).and_return(old_blobstore_id)
          allow(latest_rendered_templates_archive).to receive(:sha1).and_return(old_sha1)
          allow(latest_rendered_templates_archive).to receive(:content_sha1).and_return(old_configuration_hash)
          allow(latest_rendered_templates_archive).to receive(:update)

          allow(compressed_rendered_job_templates).to receive(:sha1).and_return(new_sha1)
          allow(compressed_rendered_job_templates).to receive(:contents).and_return(compressed_template_contents)

          allow(Time).to receive(:now).and_return(smurf_time)
        end

        context 'when rendered templates do not exist for an instance' do
          before do
            allow(instance_plan).to receive(:rendered_templates).and_return(nil)
          end

          it 'returns without persisting templates in blobstore' do
            expect(rendered_job_instance).to_not receive(:persist_on_blobstore)
            expect(instance_model).to_not receive(:add_rendered_templates_archive)
            expect(latest_rendered_templates_archive).to_not receive(:update)
            expect(Bosh::Director::Core::Templates::RenderedTemplatesArchive).to_not receive(:new)
            persister.persist(instance_plan)
          end
        end

        context 'when a rendered templates archive already exists in the DB' do
          context 'when the stored templates config hash matches the new templates config hash' do
            before do
              allow(instance).to receive(:configuration_hash).and_return(matching_configuration_hash)
            end

            context 'when blobstore does not already have the templates' do
              before do
                allow(blobstore).to receive(:exists?).with(old_blobstore_id).and_return(false)
              end

              it 'persists the templates to the blobstore' do
                expect(rendered_job_instance).to receive(:persist_on_blobstore).with(blobstore)

                persister.persist(instance_plan)
              end

              it 'updates the DB with the new blobstore ID and sha1' do
                expect(latest_rendered_templates_archive).to receive(:update).with({ blobstore_id: new_blobstore_id, sha1: new_sha1 })

                persister.persist(instance_plan)
              end

              it 'sets the templates archive to the instance plan instance' do
                expect(Bosh::Director::Core::Templates::RenderedTemplatesArchive).to receive(:new).with(new_blobstore_id, new_sha1).and_return(rendered_templates_archive)
                expect(instance).to receive(:rendered_templates_archive=).with(rendered_templates_archive)

                persister.persist(instance_plan)
              end
            end

            context 'when blobstore already has the templates' do
              before do
                allow(blobstore).to receive(:exists?).with(old_blobstore_id).and_return(true)
              end

              it 'sets the templates archive on the instance plan instance' do
                expect(Bosh::Director::Core::Templates::RenderedTemplatesArchive).to receive(:new).with(old_blobstore_id, old_sha1).and_return(rendered_templates_archive)
                expect(instance).to receive(:rendered_templates_archive=).with(rendered_templates_archive)

                persister.persist(instance_plan)
              end

              it 'does NOT persist the templates to the blobstore' do
                expect(rendered_job_instance).to_not receive(:persist_on_blobstore).with(blobstore)

                persister.persist(instance_plan)
              end
            end
          end

          context 'when stored templates config hash does not match the new templates config hash' do
            let(:new_templates_configuration_hash) { 'the new stuff' }

            before do
              allow(instance).to receive(:configuration_hash).and_return(non_matching_configuration_hash)
            end

            it 'persists the templates to the blobstore' do
              expect(rendered_job_instance).to receive(:persist_on_blobstore).with(blobstore)

              persister.persist(instance_plan)
            end

            it 'persists blob record in the database' do
              expect(instance_model).to receive(:add_rendered_templates_archive).with(
                blobstore_id: new_blobstore_id,
                sha1: new_sha1,
                content_sha1: non_matching_configuration_hash,
                created_at: smurf_time,
              )

              persister.persist(instance_plan)
            end

            it 'sets the templates archive to the instance plan instance' do
              expect(Bosh::Director::Core::Templates::RenderedTemplatesArchive).to receive(:new).with(new_blobstore_id, new_sha1).and_return(rendered_templates_archive)
              expect(instance).to receive(:rendered_templates_archive=).with(rendered_templates_archive)

              persister.persist(instance_plan)
            end
          end
        end

        context 'when a rendered templates archive does NOT exist in the DB' do
          before do
            allow(instance_model).to receive(:latest_rendered_templates_archive).and_return(nil)
            allow(instance).to receive(:configuration_hash).and_return(non_matching_configuration_hash)
          end

          it 'persists the templates to the blobstore' do
            expect(rendered_job_instance).to receive(:persist_on_blobstore).with(blobstore)

            persister.persist(instance_plan)
          end

          it 'persists blob record in the database' do
            expect(instance_model).to receive(:add_rendered_templates_archive).with(
              blobstore_id: new_blobstore_id,
              sha1: new_sha1,
              content_sha1: non_matching_configuration_hash,
              created_at: smurf_time,
            )

            persister.persist(instance_plan)
          end

          it 'sets the templates archive to the instance plan instance' do
            allow(Bosh::Director::Core::Templates::RenderedTemplatesArchive).to receive(:new).with(new_blobstore_id, new_sha1).and_return(rendered_templates_archive)
            expect(instance).to receive(:rendered_templates_archive=).with(rendered_templates_archive)

            persister.persist(instance_plan)
          end
        end
      end
    end
  end
end
