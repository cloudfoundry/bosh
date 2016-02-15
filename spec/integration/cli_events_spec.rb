require 'spec_helper'

describe 'cli: events', type: :integration do
  with_reset_sandbox_before_each

  it 'displays events' do
    deploy_from_scratch
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1
    deploy_simple_manifest(manifest_hash)

    director.vm('foobar', '0').fail_job

    deploy(failure_expected: true)

    bosh_runner.run('delete deployment simple')
    output = bosh_runner.run('events')

    expect(output).to include('Name')
    expect(output).to include('Action')
    expect(output).to include('State')
    expect(output).to include('Result')
    expect(output).to include('Task')
    expect(output).to include('Timestamp')
    output = scrub_random_ids(output).gsub /[0-9]+/, "x"
    expect(output).to match_output %(
| x | 'simple' deployment | create | started | running                                                                       | x    | x-x-x x:x:x UTC |
| x | 'simple' deployment | create | done    | /deployments/simple                                                           | x    | x-x-x x:x:x UTC |
| x | 'simple' deployment | update | started | running                                                                       | x    | x-x-x x:x:x UTC |
| x | 'simple' deployment | update | done    | /deployments/simple                                                           | x    | x-x-x x:x:x UTC |
| x | 'simple' deployment | update | started | running                                                                       | x    | x-x-x x:x:x UTC |
| x | 'simple' deployment | update | error   | `foobar/x (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)' is not running after update | x    | x-x-x x:x:x UTC |
| x | 'simple' deployment | delete | started | running                                                                       | x    | x-x-x x:x:x UTC |
| x | 'simple' deployment | delete | done    | /deployments/simple                                                           | x    | x-x-x x:x:x UTC |
)
  end
end
