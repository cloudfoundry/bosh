require 'spec_helper'

module Bosh
  module Director
    module DeploymentPlan
      describe Job do
        let(:release_version) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion') }
        let(:deployment_name) { 'deployment_name' }

        subject { Job.new(release_version, 'foo') }

        describe '#bind_properties' do
          let(:template_model) { instance_double('Bosh::Director::Models::Template') }

          let(:release_job_spec_prop) do
            {
              'cc_url' => {
                'description' => 'some desc',
                'default' => 'cloudfoundry.com',
              },
              'deep_property.dont_override' => {
                'description' => 'I have no default',
              },
              'dea_max_memory' => {
                'description' => 'max memory',
                'default' => 2048,
              },
              'map_property' => {
                'description' => 'its a map',
              },
              'array_property' => {
                'description' => 'shockingly, an array',
              },
            }
          end

          let(:user_defined_prop) do
            {
              'cc_url' => 'www.cc.com',
              'deep_property' => {
                'unneeded' => 'abc',
                'dont_override' => 'def',
              },
              'map_property' => {
                'n2' => 'foo',
                'n1' => 'foo',
              },
              'array_property' => %w[m3 m1],
              'dea_max_memory' => 1024,
            }
          end

          let(:client_factory) { double(Bosh::Director::ConfigServer::ClientFactory) }
          let(:config_server_client) { double(Bosh::Director::ConfigServer::ConfigServerClient) }
          let(:options) do
            {}
          end

          before do
            allow(release_version).to receive(:get_template_model_by_name).with('foo').and_return(template_model)
            allow(template_model).to receive(:properties).and_return(release_job_spec_prop)
            allow(template_model).to receive(:package_names).and_return([])

            allow(Bosh::Director::ConfigServer::ClientFactory).to receive(:create).with(anything).and_return(client_factory)
            allow(client_factory).to receive(:create_client).and_return(config_server_client)

            subject.bind_models
            subject.add_properties(user_defined_prop, 'instance_group_name')
          end

          it 'should drop user provided properties not specified in the release job spec properties' do
            subject.bind_properties('instance_group_name')

            expect(subject.properties).to eq(
              'instance_group_name' => {
                'cc_url' => 'www.cc.com',
                'deep_property' => {
                  'dont_override' => 'def',
                },
                'dea_max_memory' => 1024,
                'map_property' => {
                  'n1' => 'foo',
                  'n2' => 'foo',
                },
                'array_property' => %w[m3 m1],
              },
            )
          end

          it 'should include properties that are in the release job spec but not provided by a user' do
            user_defined_prop.delete('dea_max_memory')
            subject.bind_properties('instance_group_name')

            expect(subject.properties).to eq(
              'instance_group_name' => {
                'cc_url' => 'www.cc.com',
                'deep_property' => {
                  'dont_override' => 'def',
                },
                'dea_max_memory' => 2048,
                'map_property' => {
                  'n1' => 'foo',
                  'n2' => 'foo',
                },
                'array_property' => %w[m3 m1],
              },
            )
          end

          it 'should not override user provided properties with release job spec defaults' do
            subject.bind_properties('instance_group_name')
            expect(subject.properties['instance_group_name']['cc_url']).to eq('www.cc.com')
          end

          context 'when user specifies invalid property type for job' do
            let(:user_defined_prop) do
              { 'deep_property' => false }
            end

            it 'raises an exception explaining which property is the wrong type' do
              expect do
                subject.bind_properties('instance_group_name')
              end.to raise_error(
                Bosh::Template::InvalidPropertyType,
                "Property 'deep_property.dont_override' expects a hash, but received 'FalseClass'",
              )
            end
          end
        end

        describe '#runs_as_errand' do
          let(:template_model) { instance_double('Bosh::Director::Models::Template') }

          before do
            allow(release_version).to receive(:get_template_model_by_name).with('foo').and_return(template_model)
            allow(template_model).to receive(:package_names).and_return([])
            expect(release_version).to receive(:bind_model)
            expect(release_version).to receive(:bind_jobs)

            subject.bind_models
          end

          context 'when the template model runs as errand' do
            it 'returns true' do
              allow(template_model).to receive(:runs_as_errand?).and_return(true)

              expect(subject.runs_as_errand?).to eq true
            end
          end

          context 'when the model does not run as errand' do
            it 'returns false' do
              allow(template_model).to receive(:runs_as_errand?).and_return(false)

              expect(subject.runs_as_errand?).to eq false
            end
          end
        end

        describe '#download_blob' do
          let(:template_model) do
            FactoryBot.create(:models_template, name: 'foo', blobstore_id: 'blobstore-id-1', sha1: file_content_sha1)
          end
          let(:instance) { instance_double(Bosh::Director::App, blobstores: blobstores) }
          let(:blobstore) { instance_double(Bosh::Director::Blobstore::RetryableBlobstoreClient) }
          let(:blobstores) do
            instance_double(Bosh::Director::Blobstores, blobstore: blobstore)
          end
          let(:file_content) { 'job-template' }
          let(:file_content_sha1) { Digest::SHA1.hexdigest(file_content) }

          before do
            expect(release_version).to receive(:get_template_model_by_name).with('foo').and_return(template_model)
            expect(App).to receive(:instance).and_return(instance)

            subject.bind_models
          end

          it 'downloads blob from blobstore' do
            expect(blobstore).to receive(:get).with('blobstore-id-1', anything, sha1: file_content_sha1) do |_, file|
              File.open(file.path, 'w') { |f| f.write(file_content) }
            end

            path = subject.download_blob
            expect(path).to_not be_nil

            expect(Digest::SHA1.file(path).to_s).to eq(file_content_sha1)
          end
        end
      end
    end
  end
end
