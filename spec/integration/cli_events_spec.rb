require 'spec_helper'

describe 'cli: events', type: :integration do
  with_reset_sandbox_before_each

  it 'displays deployment events' do
    deploy_from_scratch(runtime_config_hash: {
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
    expect(scrub_random_numbers(output)).to match_output %(
| x <- x | xxx xxx xx xx:xx:xx UTC xxxx | test | delete | deployment     | simple    | x      | -   | -    | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | delete | deployment     | simple    | x      | -   | -    | -                                                                                        |
| x <- x | xxx xxx xx xx:xx:xx UTC xxxx | test | update | deployment     | simple    | x      | -   | -    | error: 'foobar/0 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)' is not running after update.... |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | update | deployment     | simple    | x      | -   | -    | -                                                                                        |
| x <- x | xxx xxx xx xx:xx:xx UTC xxxx | test | create | deployment     | simple    | x      | -   | -    | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | create | deployment     | simple    | x      | -   | -    | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | update | runtime-config | -         | -    | -   | -    | -                                                                                        |
| x      | xxx xxx xx xx:xx:xx UTC xxxx | test | update | cloud-config   | -         | -    | -   | -    | -                                                                                        |
)
  end

  def scrub_random_numbers(bosh_output)
    bosh_output = scrub_random_ids(bosh_output).gsub /[A-Za-z]{3} [A-Za-z]{3} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC [0-9]{4}/, 'xxx xxx xx xx:xx:xx UTC xxxx'
    bosh_output = bosh_output.gsub /[0-9]{1,} <- [0-9]{1,} [ ]{0,}/, "x <- x "
    bosh_output.gsub /[ ][0-9]{1,} [ ]{0,}/, " x      "
  end
end
