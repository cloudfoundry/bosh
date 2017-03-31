require 'spec_helper'

describe Bosh::Director::ConfigServer::VariablesInterpolator do
  subject(:variables_interpolator) { described_class.new }

  let(:client_factory) { double(Bosh::Director::ConfigServer::ClientFactory) }
  let(:config_server_client) { double(Bosh::Director::ConfigServer::EnabledClient) }
  let(:deployment_name) {'my_deployment_name'}

  before do
    allow(Bosh::Director::ConfigServer::ClientFactory).to receive(:create).and_return(client_factory)
    allow(client_factory).to receive(:create_client).and_return(config_server_client)
  end

  describe '#interpolate_template_spec_properties' do
    let(:job_1_properties) do
      {
        'prop_1' => '((smurf_1_placeholder))',
        'prop_2' => '((smurf_2_placeholder))',
        'prop_3' => {
          'prop_3_1' => '((smurf_3_1_placeholder))'
        }
      }
    end

    let(:job_2_properties) do
      {
        'prop_4' => '((smurf_4_placeholder))',
        'prop_5' => '((smurf_5_placeholder))',
        'prop_6' => {
          'prop_6_1' => '((smurf_6_1_placeholder))'
        }
      }
    end

    let(:properties_spec)  do
      {
        'job_1' => job_1_properties,
        'job_2' => job_2_properties
      }
    end

    let(:interpolated_job_1_properties) do
      {
        'prop_1' => 'smurf_1_value',
        'prop_2' => 'smurf_2_value',
        'prop_3' => {
          'prop_3_1' => 'smurf_3_1_value'
        }
      }
    end

    let(:interpolated_job_2_properties) do
      {
        'prop_4' => 'smurf_4_value',
        'prop_5' => 'smurf_5_value',
        'prop_6' => {
          'prop_6_1' => 'smurf_6_1_value'
        }
      }
    end

    let(:interpolated_properties_spec)  do
      {
        'job_1' => interpolated_job_1_properties,
        'job_2' => interpolated_job_2_properties
      }
    end

    it 'interpolates the hash given to it' do
      expect(config_server_client).to receive(:interpolate).with(job_1_properties, deployment_name, nil).and_return(interpolated_job_1_properties)
      expect(config_server_client).to receive(:interpolate).with(job_2_properties, deployment_name, nil).and_return(interpolated_job_2_properties)

      expect(subject.interpolate_template_spec_properties(properties_spec, deployment_name)).to eq(interpolated_properties_spec)
    end

    it 'interpolates using the variable set passed in' do
      deployment_model = Bosh::Director::Models::Deployment.make({ id: 1, name: deployment_name })
      variable_set = Bosh::Director::Models::VariableSet.make(id: 42, deployment: deployment_model)
      expect(config_server_client).to receive(:interpolate).with(job_1_properties, deployment_name, variable_set).and_return(interpolated_job_1_properties)
      expect(config_server_client).to receive(:interpolate).with(job_2_properties, deployment_name, variable_set).and_return(interpolated_job_2_properties)

      expect(subject.interpolate_template_spec_properties(properties_spec, deployment_name, variable_set)).to eq(interpolated_properties_spec)
    end

    context 'when src hash is nil' do
      it 'returns the src as is' do
        expect(subject.interpolate_template_spec_properties(nil, deployment_name)).to eq(nil)
      end
    end

    context 'when deployment name is nil' do
      it 'raises an error' do
        expect{
          subject.interpolate_template_spec_properties(properties_spec, nil)
        }.to raise_error(Bosh::Director::ConfigServerDeploymentNameMissing, "Deployment name missing while interpolating jobs' properties")
      end
    end

    context 'when config server returns errors while interpolating properties' do
      before do
        allow(config_server_client).to receive(:interpolate).with(job_1_properties, deployment_name, anything).and_raise Exception, <<-EOF
- Failed to find variable '/TestDirector/deployment_name/smurf_1_placeholder' from config server: HTTP code '404'
- Failed to find variable '/TestDirector/deployment_name/smurf_2_placeholder' from config server: HTTP code '404'
- Failed to find variable '/TestDirector/deployment_name/smurf_3_1_placeholder' from config server: HTTP code '404'
        EOF

        allow(config_server_client).to receive(:interpolate).with(job_2_properties, deployment_name, anything).and_raise Exception, <<-EOF
- Failed to find variable '/TestDirector/deployment_name/smurf_4_placeholder' from config server: HTTP code '404'
- Failed to find variable '/TestDirector/deployment_name/smurf_5_placeholder' from config server: HTTP code '404'
- Failed to find variable '/TestDirector/deployment_name/smurf_6_1_placeholder' from config server: HTTP code '404'
        EOF
      end

      it 'returns formatted error messages per job' do
        expected_error_msg = <<-EXPECTED.strip
- Unable to render templates for job 'job_1'. Errors are:
  - Failed to find variable '/TestDirector/deployment_name/smurf_1_placeholder' from config server: HTTP code '404'
  - Failed to find variable '/TestDirector/deployment_name/smurf_2_placeholder' from config server: HTTP code '404'
  - Failed to find variable '/TestDirector/deployment_name/smurf_3_1_placeholder' from config server: HTTP code '404'
- Unable to render templates for job 'job_2'. Errors are:
  - Failed to find variable '/TestDirector/deployment_name/smurf_4_placeholder' from config server: HTTP code '404'
  - Failed to find variable '/TestDirector/deployment_name/smurf_5_placeholder' from config server: HTTP code '404'
  - Failed to find variable '/TestDirector/deployment_name/smurf_6_1_placeholder' from config server: HTTP code '404'
        EXPECTED

        expect {
          subject.interpolate_template_spec_properties(properties_spec, deployment_name, anything)
        }.to raise_error { |error|
          expect(error.message).to eq(expected_error_msg)
        }
      end
    end
  end

  describe '#interpolate_link_spec_properties' do
    let(:link_1_properties) do
      {
        'prop_1' => '((smurf_1_placeholder))',
        'prop_2' => '((smurf_2_placeholder))',
        'prop_3' => {
          'prop_3_1' => '((smurf_3_1_placeholder))'
        }
      }
    end
    let(:link_2_properties) do
      {
        'prop_5' => 'smurf_5_value',
        'prop_6' => 'smurf_6_value',
        'prop_7' => {
          'prop_7_1' => 'smurf_7_1_value'
        }
      }
    end

    let(:interpolated_link_1_properties) do
      {
        'prop_1' => 'smurf_1_value',
        'prop_2' => 'smurf_2_value',
        'prop_3' => {
          'prop_3_1' => 'smurf_3_1_value'
        }
      }
    end
    let(:interpolated_link_2_properties) do
      {
        'prop_5' => 'smurf_5_value',
        'prop_6' => 'smurf_6_value',
        'prop_7' => {
          'prop_7_1' => 'smurf_7_1_value'
        }
      }
    end

    let(:same_deployment_links_spec) do
      {
        'link_1' => {
          'deployment_name' => 'simple_1',
          'networks' => ['a'],
          'properties' => link_1_properties,
          'instances' => [{
            'name' => 'instance_group_1',
            'index' => 0,
            'bootstrap' => true,
            'id' => 'instance_id_1',
            'az' => 'z1',
            'address' => '1.1.1.1'
          }]
        },
        'link_2' => {
          'deployment_name' => 'simple_1',
          'networks' => ['b'],
          'properties' => link_2_properties,
          'instances' => [{
            'name' => 'instance_group_2',
            'index' => 0,
            'bootstrap' => true,
            'id' => 'instance_id_2',
            'az' => 'z1',
            'address' => '2.2.2.2'
          }]
        },
      }
    end
    let(:cross_deployment_links_spec) do
      {
        'link_1' => {
          'deployment_name' => 'simple_1',
          'networks' => ['a'],
          'properties' => link_1_properties,
          'instances' => [{
                            'name' => 'instance_group_1',
                            'index' => 0,
                            'bootstrap' => true,
                            'id' => 'instance_id_1',
                            'az' => 'z1',
                            'address' => '1.1.1.1'
                          }]
        },
        'link_2' => {
          'deployment_name' => 'simple_2',
          'networks' => ['b'],
          'properties' => link_2_properties,
          'instances' => [{
                            'name' => 'instance_group_2',
                            'index' => 0,
                            'bootstrap' => true,
                            'id' => 'instance_id_2',
                            'az' => 'z1',
                            'address' => '2.2.2.2'
                          }]
        },
      }
    end

    let(:interpolated_same_deployment_links_spec) do
      {
        'link_1' => {
          'deployment_name' => 'simple_1',
          'networks' => ['a'],
          'properties' => interpolated_link_1_properties,
          'instances' => [{
            'name' => 'instance_group_1',
            'index' => 0,
            'bootstrap' => true,
            'id' => 'instance_id_1',
            'az' => 'z1',
            'address' => '1.1.1.1'
          }]
        },
        'link_2' => {
          'deployment_name' => 'simple_1',
          'networks' => ['b'],
          'properties' => interpolated_link_2_properties,
          'instances' => [{
            'name' => 'instance_group_2',
            'index' => 0,
            'bootstrap' => true,
            'id' => 'instance_id_2',
            'az' => 'z1',
            'address' => '2.2.2.2'
          }]
        },
      }
    end
    let(:interpolated_cross_deployment_links_spec) do
      {
        'link_1' => {
          'deployment_name' => 'simple_1',
          'networks' => ['a'],
          'properties' => interpolated_link_1_properties,
          'instances' => [{
                            'name' => 'instance_group_1',
                            'index' => 0,
                            'bootstrap' => true,
                            'id' => 'instance_id_1',
                            'az' => 'z1',
                            'address' => '1.1.1.1'
                          }]
        },
        'link_2' => {
          'deployment_name' => 'simple_2',
          'networks' => ['b'],
          'properties' => interpolated_link_2_properties,
          'instances' => [{
                            'name' => 'instance_group_2',
                            'index' => 0,
                            'bootstrap' => true,
                            'id' => 'instance_id_2',
                            'az' => 'z1',
                            'address' => '2.2.2.2'
                          }]
        },
      }
    end

    let(:consumer_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }
    let(:consumer_deployment) { instance_double(Bosh::Director::Models::Deployment)}

    before do
      allow(consumer_variable_set).to receive(:deployment).and_return(consumer_deployment)
      allow(consumer_deployment).to receive(:name).and_return('simple_1')
    end
    context 'when links spec is nil' do
      it 'returns the spec as is' do
        expect(subject.interpolate_link_spec_properties(nil, consumer_variable_set)).to eq(nil)
      end
    end

    context 'when links spec is given' do

      context 'when links spec is empty hash' do
        it 'returns it as is' do
          expect(subject.interpolate_link_spec_properties({}, consumer_variable_set)).to eq({})
        end
      end

      context 'when the properties of a link is missing' do
        let(:input) do
          same_deployment_links_spec['link_1'].delete('properties')
          same_deployment_links_spec
        end

        let(:result) do
          interpolated_same_deployment_links_spec['link_1'].delete('properties')
          interpolated_same_deployment_links_spec
        end

        it 'does not add it' do
          expect(config_server_client).to receive(:interpolate).with(link_2_properties, 'simple_1', consumer_variable_set).and_return(interpolated_link_2_properties)
          expect(subject.interpolate_link_spec_properties(input, consumer_variable_set)).to eq(result)
        end
      end

      context 'when the properties of a link is nil' do
        let(:input) do
          same_deployment_links_spec['link_1']['properties'] = nil
          same_deployment_links_spec
        end

        let(:result) do
          interpolated_same_deployment_links_spec['link_1']['properties'] = nil
          interpolated_same_deployment_links_spec
        end

        it 'keeps it as nil' do
          expect(config_server_client).to receive(:interpolate).with(link_2_properties, 'simple_1', consumer_variable_set).and_return(interpolated_link_2_properties)
          expect(subject.interpolate_link_spec_properties(input, consumer_variable_set)).to eq(result)
        end
      end

      context 'when the properties of a link is present' do
        context 'when all the links are provided by the SAME deployment' do
          it 'interpolates the hash given to it by calling config_server_client.interpolate method' do
            expect(config_server_client).to receive(:interpolate).with(link_1_properties, 'simple_1', consumer_variable_set).and_return(interpolated_link_1_properties)
            expect(config_server_client).to receive(:interpolate).with(link_2_properties, 'simple_1', consumer_variable_set).and_return(interpolated_link_2_properties)
            result = subject.interpolate_link_spec_properties(same_deployment_links_spec, consumer_variable_set)
            expect(result).to eq(interpolated_same_deployment_links_spec)
            expect(result).to_not equal(interpolated_same_deployment_links_spec)
          end
        end

        context 'when there are links provided by a DIFFERENT deployment' do
          let(:provider_deployment) { instance_double(Bosh::Director::Models::Deployment)}
          let(:provider_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

          before do
            allow(Bosh::Director::Models::Deployment).to receive(:[]).with(name: 'simple_2').and_return(provider_deployment)
            allow(provider_deployment).to receive(:last_successful_variable_set).and_return(provider_variable_set)
            allow(config_server_client).to receive(:interpolate).with(link_1_properties, 'simple_1', consumer_variable_set).and_return(interpolated_link_1_properties)
          end

          it 'interpolates the cross deployment link properties by calling config_server_client.interpolate_cross_deployment_link method' do
            expect(config_server_client).to receive(:interpolate_cross_deployment_link).with(link_2_properties, consumer_variable_set, provider_variable_set).and_return(interpolated_link_2_properties)
            result = subject.interpolate_link_spec_properties(cross_deployment_links_spec, consumer_variable_set)
            expect(result).to eq(interpolated_cross_deployment_links_spec)
            expect(result).to_not equal(interpolated_cross_deployment_links_spec)
          end

          context 'when provider deployment does NOT exist' do
            before do
              allow(Bosh::Director::Models::Deployment).to receive(:[]).with(name: 'simple_2').and_return(nil)
            end

            it 'should raise an exception with appropriate message' do
              expected_error_msg = <<-EXPECTED.strip
- Unable to interpolate link 'link_2' properties; provided by 'simple_2' deployment. Errors are:
  - Deployment 'simple_2' doesn't exist
              EXPECTED

              expect{
                subject.interpolate_link_spec_properties(cross_deployment_links_spec, consumer_variable_set)
              }.to raise_error { |error|
                expect(error.message).to eq(expected_error_msg)
              }
            end
          end

          context 'when provider deployment does NOT have a successful variable set' do
            before do
              allow(provider_deployment).to receive(:last_successful_variable_set).and_return(nil)
              allow(provider_deployment).to receive(:name).and_return('simple_2')
            end

            it 'should raise an exception with appropriate message' do
              expected_error_msg = <<-EXPECTED.strip
- Unable to interpolate link 'link_2' properties; provided by 'simple_2' deployment. Errors are:
  - Cannot consume properties from deployment 'simple_2'. It was never successfully deployed.
              EXPECTED

              expect{
                subject.interpolate_link_spec_properties(cross_deployment_links_spec, consumer_variable_set)
              }.to raise_error { |error|
                expect(error.message).to eq(expected_error_msg)
              }
            end
          end

        end
      end

      context 'when config server returns errors while interpolating properties' do
        before do
          allow(config_server_client).to receive(:interpolate).with(link_1_properties, 'simple_1', consumer_variable_set).and_raise Exception, <<-EOF
- Failed to find variable '/TestDirector/deployment_name/smurf_1_placeholder' from config server: HTTP code '404'
- Failed to find variable '/TestDirector/deployment_name/smurf_2_placeholder' from config server: HTTP code '404'
- Failed to find variable '/TestDirector/deployment_name/smurf_3_1_placeholder' from config server: HTTP code '404'
          EOF

          allow(config_server_client).to receive(:interpolate).with(link_2_properties, 'simple_1', consumer_variable_set).and_raise Exception, <<-EOF
- Failed to find variable '/TestDirector/deployment_name/smurf_4_placeholder' from config server: HTTP code '404'
- Failed to find variable '/TestDirector/deployment_name/smurf_5_placeholder' from config server: HTTP code '404'
- Failed to find variable '/TestDirector/deployment_name/smurf_6_1_placeholder' from config server: HTTP code '404'
          EOF
        end

        it 'returns formatted error messages per job' do
          expected_error_msg = <<-EXPECTED.strip
- Unable to interpolate link 'link_1' properties; provided by 'simple_1' deployment. Errors are:
  - Failed to find variable '/TestDirector/deployment_name/smurf_1_placeholder' from config server: HTTP code '404'
  - Failed to find variable '/TestDirector/deployment_name/smurf_2_placeholder' from config server: HTTP code '404'
  - Failed to find variable '/TestDirector/deployment_name/smurf_3_1_placeholder' from config server: HTTP code '404'
- Unable to interpolate link 'link_2' properties; provided by 'simple_1' deployment. Errors are:
  - Failed to find variable '/TestDirector/deployment_name/smurf_4_placeholder' from config server: HTTP code '404'
  - Failed to find variable '/TestDirector/deployment_name/smurf_5_placeholder' from config server: HTTP code '404'
  - Failed to find variable '/TestDirector/deployment_name/smurf_6_1_placeholder' from config server: HTTP code '404'
          EXPECTED

          expect {
            subject.interpolate_link_spec_properties(same_deployment_links_spec, consumer_variable_set)
          }.to raise_error { |error|
            expect(error.message).to eq(expected_error_msg)
          }
        end
      end
    end
  end

  describe '#interpolate_deployment_manifest' do
    let(:ignored_subtrees) do
      index_type = Integer
      any_string = String

      ignored_subtrees = []
      ignored_subtrees << ['properties']
      ignored_subtrees << ['instance_groups', index_type, 'properties']
      ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'properties']
      ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'consumes', any_string, 'properties']
      ignored_subtrees << ['jobs', index_type, 'properties']
      ignored_subtrees << ['jobs', index_type, 'templates', index_type, 'properties']
      ignored_subtrees << ['jobs', index_type, 'templates', index_type, 'consumes', any_string, 'properties']
      ignored_subtrees << ['instance_groups', index_type, 'env']
      ignored_subtrees << ['jobs', index_type, 'env']
      ignored_subtrees << ['resource_pools', index_type, 'env']
      ignored_subtrees
    end

    let(:deployment_manifest) {{'name' => 'smurf-deployment', 'properties' => {'a' => '{{placeholder}}'}}}

    it 'should call interpolate with the correct arguments' do
      expect(config_server_client).to receive(:interpolate).with(deployment_manifest , 'smurf-deployment', anything, subtrees_to_ignore: ignored_subtrees, must_be_absolute_name: false).and_return({'name' => 'smurf'})
      result = subject.interpolate_deployment_manifest(deployment_manifest)
      expect(result).to eq({'name' => 'smurf'})
    end
  end

  describe '#interpolate_runtime_manifest' do
    let(:deployment_name) { 'some_deployment_name' }

    let(:ignored_subtrees) do
      index_type = Integer
      any_string = String

      ignored_subtrees = []
      ignored_subtrees << ['addons', index_type, 'properties']
      ignored_subtrees << ['addons', index_type, 'jobs', index_type, 'properties']
      ignored_subtrees << ['addons', index_type, 'jobs', index_type, 'consumes', any_string, 'properties']
      ignored_subtrees
    end

    it 'should call interpolate with the correct arguments' do
      expect(config_server_client).to receive(:interpolate).with({'name' => '{{placeholder}}'}, deployment_name, anything, {subtrees_to_ignore: ignored_subtrees, must_be_absolute_name: true}).and_return({'name' => 'smurf'})
      result = subject.interpolate_runtime_manifest({'name' => '{{placeholder}}'}, deployment_name)
      expect(result).to eq({'name' => 'smurf'})
    end
  end
end