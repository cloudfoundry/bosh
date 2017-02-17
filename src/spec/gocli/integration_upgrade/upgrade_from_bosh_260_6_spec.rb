require_relative '../spec_helper'

describe 'director upgrade after introducing variables tables', type: :upgrade do
  with_reset_sandbox_before_each(test_initial_state: 'bosh-v260.6-f419326cad3e642ed4a5e6d893688c0766d7b259', drop_database: true)

  it 'can start the hard stopped instance' do
    output = scrub_random_ids(parse_blocks(bosh_runner.run('-d simple start', json: true)))

    expect(output).to include('Creating missing vms: foobar1/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
    expect(output).to include('Creating missing vms: foobar1/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)')
    expect(output).to include('Updating instance foobar1: foobar1/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
    expect(output).to include('Updating instance foobar1: foobar1/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1) (canary)')
  end

  it 'can recreate the hard stopped instance' do
    output = scrub_random_ids(parse_blocks(bosh_runner.run('-d simple recreate', json: true)))

    expect(output).to include('Creating missing vms: foobar1/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
    expect(output).to include('Creating missing vms: foobar1/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)')
    expect(output).to include('Updating instance foobar1: foobar1/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
    expect(output).to include('Updating instance foobar1: foobar1/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1) (canary)')
  end

  it 'can show that zero variables are attached to this deployment' do
    variables = table(bosh_runner.run('-d simple variables', json: true))
    expect(variables).to be_empty
  end
end
