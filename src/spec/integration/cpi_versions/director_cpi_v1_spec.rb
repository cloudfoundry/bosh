require 'spec_helper'

describe 'director behaviour', type: :integration do
  with_reset_sandbox_before_each(dummy_cpi_api_version: 1)

  let(:cpi_version) { 1 }
  let(:cpi_version_string) { "\"api_version\":#{cpi_version}" }
  let(:response_string) { nil }
  let(:search_filter_string) { nil }

  shared_examples_for 'using CPI specific cpi_api_version' do
    before do
      manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(instances: 1)
      manifest_hash['instance_groups'][0]['persistent_disk'] = 1000
      output = deploy_from_scratch(manifest_hash: manifest_hash)
      task_id = Bosh::Spec::OutputParser.new(output).task_id
      @task_output = bosh_runner.run("task #{task_id} --debug")
    end

    it 'responds with specific cpi_api_version results' do
      api_version_filter = @task_output.split(/\n+/).select { |i| i[/\[external-cpi\] \[cpi-\d{6}\].*"method":"create_vm"/] }
      expect(api_version_filter).to_not be_empty
      api_version_filter.each do |result|
        expect(result).to include(cpi_version_string)
      end

      cpi_method_call_filter = @task_output.split(/\n+/).select { |i| i[/\[external-cpi\] \[cpi-\d{6}\]/] }
      expect(cpi_method_call_filter).to_not be_empty
      cpi_method_call_filter.each_with_index do |result, index|
        expect(result).to match(response_string) if result.include?(search_filter_string)
      end
    end
  end

  context 'when cpi_version < 2' do
    context 'create_vm' do
      let(:response_string) { /"result":"\d+"/ }
      let(:search_filter_string) { 'DEBUG - Dummy: create_vm' }

      it_behaves_like 'using CPI specific cpi_api_version'
    end

    context 'attach_disk' do
      let(:response_string) { /"result":\d+/ }
      let(:search_filter_string) { 'DEBUG - Saving input for attach_disk' }

      it_behaves_like 'using CPI specific cpi_api_version'
    end
  end
end
