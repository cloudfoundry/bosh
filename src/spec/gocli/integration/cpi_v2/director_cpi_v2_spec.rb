require_relative '../../spec_helper'

describe 'director behaviour with CPI v2', type: :integration do
  with_reset_sandbox_before_each(dummy_cpi_api_version: 2)

  context 'create_vm' do
    it 'includes api_version 2 in request' do
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      output = deploy_from_scratch(manifest_hash: manifest_hash)
      task_id = Bosh::Spec::OutputParser.new(output).task_id

      task_output = bosh_runner.run("task #{task_id} --debug")
      results = task_output.split(/\n+/).select { |i| i[/\[external-cpi\] \[cpi-\d{6}\].*"method":"create_vm"/] }
      expect(results).to_not be_empty
      results.each do |result|
        expect(result).to include('"api_version":2')
      end
    end

    it 'responds with v2 result' do
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      output = deploy_from_scratch(manifest_hash: manifest_hash)
      task_id = Bosh::Spec::OutputParser.new(output).task_id

      task_output = bosh_runner.run("task #{task_id} --debug")
      results = task_output.split(/\n+/).select { |i| i[/\[external-cpi\] \[cpi-\d{6}\]/] }

      results.each_with_index do |result, index|
        result2 = results.fetch(index + 1)
        puts "r1 #{result}"
        #puts "r2 #{result2}"
        #expect(result2).to match(/"result":{"vm_cid":"\d+","networks":\[.*\],"disk_hints":{.*}}/) if result.include?('"method":"create_vm"')
      end
    end
  end
end
