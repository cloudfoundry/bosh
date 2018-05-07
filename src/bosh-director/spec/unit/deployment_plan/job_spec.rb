require 'spec_helper'

module Bosh
  module Director
    module DeploymentPlan
      describe Job do
        let(:deployment_name) { 'deployment_name' }

        subject { Job.new(release_version, 'foo', deployment_name) }

        describe '#bind_properties' do
          let(:release_version) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion') }
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
          let(:options) { {} }

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
            expect(config_server_client).to receive(:prepare_and_get_property)
              .with('www.cc.com', 'cloudfoundry.com', nil, deployment_name, options)
              .and_return('www.cc.com')

            expect(config_server_client).to receive(:prepare_and_get_property)
              .with('def', nil, nil, deployment_name, options)
              .and_return('def')

            expect(config_server_client).to receive(:prepare_and_get_property)
              .with(1024, 2048, nil, deployment_name, options)
              .and_return(1024)

            expect(config_server_client).to receive(:prepare_and_get_property)
              .with({ 'n2' => 'foo', 'n1' => 'foo' }, nil, nil, deployment_name, options)
              .and_return('n2' => 'foo', 'n1' => 'foo')

            expect(config_server_client).to receive(:prepare_and_get_property)
              .with(%w[m3 m1], nil, nil, deployment_name, options)
              .and_return(%w[m3 m1])

            subject.bind_properties('instance_group_name', deployment_name)

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
            expect(config_server_client).to receive(:prepare_and_get_property)
              .with('www.cc.com', 'cloudfoundry.com', nil, deployment_name, options)
              .and_return('www.cc.com')

            expect(config_server_client).to receive(:prepare_and_get_property)
              .with('def', nil, nil, deployment_name, options)
              .and_return('def')

            expect(config_server_client).to receive(:prepare_and_get_property)
              .with(nil, 2048, nil, deployment_name, options)
              .and_return(2048)

            expect(config_server_client).to receive(:prepare_and_get_property)
              .with({ 'n2' => 'foo', 'n1' => 'foo' }, nil, nil, deployment_name, options)
              .and_return('n2' => 'foo', 'n1' => 'foo')

            expect(config_server_client).to receive(:prepare_and_get_property)
              .with(%w[m3 m1], nil, nil, deployment_name, options)
              .and_return(%w[m3 m1])

            user_defined_prop.delete('dea_max_memory')
            subject.bind_properties('instance_group_name', deployment_name)

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
            expect(config_server_client).to receive(:prepare_and_get_property)
              .with('www.cc.com', 'cloudfoundry.com', nil, deployment_name, options)
              .and_return('www.cc.com')

            expect(config_server_client).to receive(:prepare_and_get_property)
              .with('def', nil, nil, deployment_name, options)
              .and_return('def')

            expect(config_server_client).to receive(:prepare_and_get_property)
              .with(1024, 2048, nil, deployment_name, options)
              .and_return(1024)

            expect(config_server_client).to receive(:prepare_and_get_property)
              .with({ 'n2' => 'foo', 'n1' => 'foo' }, nil, nil, deployment_name, options)
              .and_return('n2' => 'foo', 'n1' => 'foo')

            expect(config_server_client).to receive(:prepare_and_get_property)
              .with(%w[m3 m1], nil, nil, deployment_name, options)
              .and_return(%w[m3 m1])

            subject.bind_properties('instance_group_name', deployment_name)
            expect(subject.properties['instance_group_name']['cc_url']).to eq('www.cc.com')
          end

          context 'when user specifies invalid property type for job' do
            let(:user_defined_prop) { { 'deep_property' => false } }

            before do
              allow(config_server_client).to receive(:prepare_and_get_property)
                .with(nil, 'cloudfoundry.com', nil, deployment_name, options)

              allow(config_server_client).to receive(:prepare_and_get_property)
                .with(nil, 2048, nil, deployment_name, options)
            end

            it 'raises an exception explaining which property is the wrong type' do
              expect do
                subject.bind_properties('instance_group_name', deployment_name, {})
              end.to raise_error(
                Bosh::Template::InvalidPropertyType,
                "Property 'deep_property.dont_override' expects a hash, but received 'FalseClass'",
              )
            end
          end

          context 'properties interpolation' do
            let(:options) do
              {
                'anything' => %w[1 2],
              }
            end

            before do
              user_defined_prop['cc_url'] = '((secret_url_password_placeholder))'

              release_job_spec_prop['cc_url']['type'] = 'password'
              release_job_spec_prop['deep_property.dont_override']['type'] = nil
              release_job_spec_prop['dea_max_memory']['type'] = 'vroom'
            end

            it 'calls config server client prepare_and_get_property for all job spec properties' do
              expect(config_server_client).to receive(:prepare_and_get_property).with(
                '((secret_url_password_placeholder))',
                'cloudfoundry.com',
                'password',
                deployment_name,
                options,
              ).and_return('generated secret')

              expect(config_server_client).to receive(:prepare_and_get_property)
                .with('def', nil, nil, deployment_name, options)
                .and_return('def')

              expect(config_server_client).to receive(:prepare_and_get_property)
                .with(1024, 2048, 'vroom', deployment_name, options)
                .and_return(1024)

              expect(config_server_client).to receive(:prepare_and_get_property)
                .with({ 'n2' => 'foo', 'n1' => 'foo' }, nil, nil, deployment_name, options)
                .and_return('n2' => 'foo', 'n1' => 'foo')

              expect(config_server_client).to receive(:prepare_and_get_property)
                .with(%w[m3 m1], nil, nil, deployment_name, options)
                .and_return(%w[m3 m1])

              subject.bind_properties('instance_group_name', deployment_name, options)

              expect(subject.properties).to eq(
                'instance_group_name' => {
                  'cc_url' => 'generated secret',
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
          end
        end

        describe '#runs_as_errand' do
          let(:release_version) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion') }
          let(:template_model) { instance_double('Bosh::Director::Models::Template') }

          before do
            allow(release_version).to receive(:get_template_model_by_name).with('foo').and_return(template_model)
            allow(template_model).to receive(:package_names).and_return([])
            expect(release_version).to receive(:bind_model)
            expect(release_version).to receive(:bind_templates)

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
      end
    end
  end
end
