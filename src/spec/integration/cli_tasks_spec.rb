require_relative '../spec_helper'

describe 'cli: tasks', type: :integration do
  with_reset_sandbox_before_each

  it 'should return task list' do
    deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups)
    bosh_runner.run('delete-deployment', deployment_name: 'simple')
    output = bosh_runner.run('tasks --recent', deployment_name: 'simple')

    expect(output).to match /4   done   .*  test  simple      delete deployment simple  \/deployments\/simple/
    expect(output).to match /3   done   .*  test  simple      create deployment         \/deployments\/simple/
    expect(output).not_to match /create stemcell/
    expect(output).not_to match /create release/
  end
end
