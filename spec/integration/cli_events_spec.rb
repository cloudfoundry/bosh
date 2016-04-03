require 'spec_helper'

describe 'cli: events', type: :integration do
  with_reset_sandbox_before_each

  it 'displays deployment events' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1
    deploy_from_scratch(manifest_hash: manifest_hash, runtime_config_hash: {
        'releases' => [{"name" => 'bosh-release', "version" => "0.1-dev"}]
    })


    director.vm('foobar', '0').fail_job
    deploy(failure_expected: true)

    bosh_runner.run('delete deployment simple')
    output = bosh_runner.run('events')

    expect(output).to include('ID')
    expect(output).to include('Time')
    expect(output).to include('User')
    expect(output).to include('Action')
    expect(output).to include('Object type')
    expect(output).to include('Object ID')
    expect(output).to include('Task')
    expect(output).to include('Dep')
    expect(output).to include('Inst')
    expect(output).to include('Context')
    expect(scrub_event_specific(output)).to match_output %(
| x <- x | xxx xxx xx xx:xx:xx UTC xxxx | test | delete | deployment     | simple                                                                                | x      | -      | -                                                                                     | -                                                                                        |
| x <- x | xxx xxx xx xx:xx:xx UTC xxxx | test | delete | instance       | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                                           | x      | simple | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                                           | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | delete | instance       | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                                           | x      | simple | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                                           | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | delete | deployment     | simple                                                                                | x      | -      | -                                                                                     | -                                                                                        |
| x <- x | xxx xxx xx xx:xx:xx UTC xxxx | test | update | deployment     | simple                                                                                | x      | -      | -                                                                                     | error: 'foobar/0 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)' is not running after update.... |
| x <- x | xxx xxx xx xx:xx:xx UTC xxxx | test | start  | instance       | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                                           | x      | simple | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                                           | error: 'foobar/0 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)' is not running after update.... |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | start  | instance       | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                                           | x      | simple | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                                           | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | update | deployment     | simple                                                                                | x      | -      | -                                                                                     | -                                                                                        |
| x <- x | xxx xxx xx xx:xx:xx UTC xxxx | test | create | deployment     | simple                                                                                | x      | -      | -                                                                                     | -                                                                                        |
| x <- x | xxx xxx xx xx:xx:xx UTC xxxx | test | create | instance       | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                                           | x      | simple | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                                           | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | create | instance       | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                                           | x      | simple | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                                           | -                                                                                        |
| x <- x | xxx xxx xx xx:xx:xx UTC xxxx | test | delete | instance       | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | x      | simple | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | delete | instance       | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | x      | simple | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | -                                                                                        |
| x <- x | xxx xxx xx xx:xx:xx UTC xxxx | test | create | instance       | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | x      | simple | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | create | instance       | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | x      | simple | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | -                                                                                        |
| x <- x | xxx xxx xx xx:xx:xx UTC xxxx | test | delete | instance       | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | x      | simple | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | delete | instance       | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | x      | simple | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | -                                                                                        |
| x <- x | xxx xxx xx xx:xx:xx UTC xxxx | test | create | instance       | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | x      | simple | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | create | instance       | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | x      | simple | compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | create | deployment     | simple                                                                                | x      | -      | -                                                                                     | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | update | runtime-config | -                                                                                     | -    | -      | -                                                                                     | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | update | cloud-config   | -                                                                                     | -    | -      | -                                                                                     | -                                                                                        |
)
  end
end
