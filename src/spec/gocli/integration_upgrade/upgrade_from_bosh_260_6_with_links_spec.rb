require_relative '../spec_helper'

describe 'director upgrade after migrating links schema to include job name', type: :upgrade do
  with_reset_sandbox_before_each(test_initial_state: 'bosh-v260.6-f419326cad3e642ed4a5e6d893688c0766d7b259_with_links', drop_database: true)

  it 'can start the hard stopped instance' do
    output = scrub_random_ids(parse_blocks(bosh_runner.run('-d simple start', json: true)))

    expect(output).to include('Creating missing vms: my_api/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
    expect(output).to include('Creating missing vms: aliased_postgres/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
    expect(output).to include('Creating missing vms: job_with_no_links/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
    expect(output).to include('Updating instance my_api: my_api/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
    expect(output).to include('Updating instance aliased_postgres: aliased_postgres/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
    expect(output).to include('Updating instance job_with_no_links: job_with_no_links/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
  end

  it 'can recreate the hard stopped instance' do
    output = scrub_random_ids(parse_blocks(bosh_runner.run('-d simple recreate', json: true)))

    expect(output).to include('Creating missing vms: my_api/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
    expect(output).to include('Creating missing vms: aliased_postgres/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
    expect(output).to include('Creating missing vms: job_with_no_links/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
    expect(output).to include('Updating instance my_api: my_api/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
    expect(output).to include('Updating instance aliased_postgres: aliased_postgres/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
    expect(output).to include('Updating instance job_with_no_links: job_with_no_links/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

  end

  it 'runs the errand with links' do
    output, exit_code = bosh_runner.run('-d simple run-errand my_errand', return_exit_code: true)
    expect(exit_code).to eq(0)

    expect(output).to include('Creating missing vms: my_errand')
    expect(output).to include('Updating instance my_errand: my_errand')
  end
end
