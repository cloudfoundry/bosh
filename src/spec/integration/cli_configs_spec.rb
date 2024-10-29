require 'spec_helper'

describe 'cli configs', type: :integration do
  with_reset_sandbox_before_each

  let(:config) { yaml_file('config.yml', Bosh::Spec::Deployments.simple_cloud_config) }

  context 'can upload a config' do
    context 'when config uses placeholders' do
      let(:config) { yaml_file('config.yml', Bosh::Spec::Deployments.manifest_errand_with_placeholders) }

      it 'replaces placeholders' do
        expect(bosh_runner.run("update-config -v placeholder=my-data --type=my-type --name=default #{config.path}")).to include('Succeeded')
        expect(bosh_runner.run('config --type=my-type --name=default')).to include('my-data')
      end
    end

    it 'updates config' do
      expect(bosh_runner.run("update-config --type=my-type --name=default #{config.path}")).to include('Succeeded')
    end

    it 'updates named config' do
      expect(bosh_runner.run("update-config --type=my-type --name=my-name #{config.path}")).to include('Succeeded')
    end

    it 'updates config with default name' do
      bosh_runner.run("update-config --type=my-type --name=default #{config.path}")
      expect(bosh_runner.run('configs --type=my-type --json')).to include('"name": "default"')
    end

    it 'uploads an empty YAML hash' do
      Dir.mktmpdir do |tmpdir|
        empty_config_filename = File.join(tmpdir, 'empty_config.yml')
        File.write(empty_config_filename, '{}')
        expect(bosh_runner.run("update-config --type=my-type --name=default #{empty_config_filename}")).to include('Succeeded')
      end
    end

    it 'does not fail if the uploaded config is a large file' do
      config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.simple_cloud_config)

      (0..10_001).each do |i|
        config["boshbosh#{i}"] = 'smurfsAreBlueGargamelIsBrownPinkpantherIsPinkAndPikachuIsYellow'
      end

      cloud_config_file = yaml_file('config.yml', config)

      output, exit_code = bosh_runner.run("update-config --type=large-config --name=default #{cloud_config_file.path}", return_exit_code: true)
      expect(output).to include('Succeeded')
      expect(exit_code).to eq(0)
    end

    it 'uploads when expected latest id matches' do
      expect(bosh_runner.run("update-config --type=my-type --name=default #{config.path}")).to include('Succeeded')
      id = JSON.parse(bosh_runner.run('configs --recent=99 --json')).dig('Tables', 0, 'Rows', 0, 'id')

      output = bosh_runner.run("update-config --expected-latest-id=#{id.to_i} --type=my-type --name=default #{config.path}")
      expect(output).to include('Succeeded')
    end

    it 'does not upload when expected latest id is not the latest' do
      expect(bosh_runner.run("update-config --type=my-type --name=default #{config.path}")).to include('Succeeded')
      id = JSON.parse(bosh_runner.run('configs --recent=99 --json')).dig('Tables', 0, 'Rows', 0, 'id')

      output = bosh_runner.run(
        "update-config --expected-latest-id=#{id.to_i - 1} --type=my-type --name=default #{config.path}",
        failure_expected: true,
      )
      expect(output).to include('Config update rejected')
    end
  end

  context 'can get a config' do
    it 'by id' do
      bosh_runner.run("update-config --type=my-type --name=default #{config.path}")
      id = JSON.parse(bosh_runner.run('configs --recent=99 --json')).dig('Tables', 0, 'Rows', 0, 'id')
      expect(bosh_runner.run("config #{id.to_i}")).to include('Succeeded')
    end
  end

  context 'can list configs' do
    let(:second_config) { yaml_file('second_config.yml', Bosh::Spec::Deployments.manifest_errand_with_placeholders) }

    it 'lists configs' do
      bosh_runner.run("update-config --type=my-type --name=default #{config.path}")
      bosh_runner.run("update-config --type=other-type --name=other-name #{config.path}")

      expect(bosh_runner.run('configs')).to include('default', 'other-name', 'my-type', 'other-type')
    end

    it 'can filter lists configs' do
      bosh_runner.run("update-config --type=my-type --name=my-name #{config.path}")
      bosh_runner.run("update-config --type=other-type --name=other-name #{config.path}")

      output = bosh_runner.run('configs --type=my-type --name=my-name')
      expect(output).to_not include('other-type', 'other-name')
    end

    it 'can include outdated configs' do
      bosh_runner.run("update-config --type=my-type --name=my-name #{config.path}")
      bosh_runner.run("update-config --type=my-type --name=my-name #{second_config.path}")

      output = bosh_runner.run('configs --recent=99')

      expect(output.scan('my-type').length).to be(2)
      expect(output.scan('my-name').length).to be(2)
    end
  end

  context 'when teams are used' do
    with_reset_sandbox_before_each(user_authentication: 'uaa')

    let(:production_env) do
      { 'BOSH_CLIENT' => 'production_team', 'BOSH_CLIENT_SECRET' => 'secret' }
    end
    let(:admin_env) do
      { 'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret' }
    end
    let(:team_read_env) do
      { 'BOSH_CLIENT' => 'team-client-read-access', 'BOSH_CLIENT_SECRET' => 'team-secret' }
    end
    let(:team_admin_env) do
      { 'BOSH_CLIENT' => 'team-client', 'BOSH_CLIENT_SECRET' => 'team-secret' }
    end

    it 'shows configs of the same team only' do
      bosh_runner.run(
        "update-config --type=cloud --name=prod #{config.path}",
        client: production_env['BOSH_CLIENT'],
        client_secret: production_env['BOSH_CLIENT_SECRET'],
      )

      bosh_runner.run(
        "update-config --type=cloud --name=team #{config.path}",
        client: team_admin_env['BOSH_CLIENT'],
        client_secret: team_admin_env['BOSH_CLIENT_SECRET'],
      )

      production_configs = table(bosh_runner.run('configs', json: true, client: production_env['BOSH_CLIENT'],
                                                            client_secret: production_env['BOSH_CLIENT_SECRET']))
      expect(production_configs.length).to eq(1)
      expect(production_configs.first).to include('name' => 'prod', 'team' => 'production_team', 'type' => 'cloud')

      team_configs = table(bosh_runner.run('configs', json: true, client: team_read_env['BOSH_CLIENT'],
                                                      client_secret: team_read_env['BOSH_CLIENT_SECRET']))
      expect(team_configs.length).to eq(1)
      expect(team_configs.first).to include('name' => 'team', 'team' => 'ateam', 'type' => 'cloud')
    end

    it 'allows to create/delete team only for admin or team admin' do
      output = bosh_runner.run(
        "update-config --type=team-type --name=default #{config.path}",
        failure_expected: true,
        client: team_read_env['BOSH_CLIENT'],
        client_secret: team_read_env['BOSH_CLIENT_SECRET'],
      )
      expect(output).to include("Director responded with non-successful status code '401'")

      bosh_runner.run(
        "update-config --type=team-type --name=team-name1 #{config.path}",
        client: team_admin_env['BOSH_CLIENT'],
        client_secret: team_admin_env['BOSH_CLIENT_SECRET'],
      )
      bosh_runner.run(
        "update-config --type=team-type --name=team-name2 #{config.path}",
        client: team_admin_env['BOSH_CLIENT'],
        client_secret: team_admin_env['BOSH_CLIENT_SECRET'],
      )

      admin_configs = table(
        bosh_runner.run(
          'configs',
          json: true,
          client: team_admin_env['BOSH_CLIENT'],
          client_secret: team_admin_env['BOSH_CLIENT_SECRET'],
        ),
      )
      expect(admin_configs.length).to eq(2)

      expect(admin_configs.first).to include('name' => 'team-name1', 'team' => 'ateam', 'type' => 'team-type')
      expect(admin_configs.last).to include('name' => 'team-name2', 'team' => 'ateam', 'type' => 'team-type')

      output = bosh_runner.run(
        'delete-config --type=team-type --name=team-name1',
        failure_expected: true,
        client: team_read_env['BOSH_CLIENT'],
        client_secret: team_read_env['BOSH_CLIENT_SECRET'],
      )
      expect(output).to include('Require one of the scopes: bosh.admin, bosh.deadbeef.admin')

      output = bosh_runner.run(
        'delete-config --type=team-type --name=team-name1',
        client: admin_env['BOSH_CLIENT'],
        client_secret: admin_env['BOSH_CLIENT_SECRET'],
      )
      expect(output).to include('Succeeded')

      output = bosh_runner.run(
        'delete-config --type=team-type --name=team-name2',
        client: team_admin_env['BOSH_CLIENT'],
        client_secret: team_admin_env['BOSH_CLIENT_SECRET'],
      )
      expect(output).to include('Succeeded')

      admin_configs = table(
        bosh_runner.run('configs', json: true, client: admin_env['BOSH_CLIENT'], client_secret: admin_env['BOSH_CLIENT_SECRET']),
      )
      expect(admin_configs.length).to eq(0)
    end
  end

  context 'can diff configs' do
    let(:other_config) { yaml_file('config.yml', Bosh::Spec::Deployments.manifest_errand_with_placeholders) }

    it 'diffs two saved configs' do
      bosh_runner.run("update-config --type=my-type --name=default #{config.path}")
      bosh_runner.run("update-config --type=other-type --name=other-name #{other_config.path}")

      output = bosh_runner.run('configs --recent=99 --json')
      from, to = JSON.parse(output)['Tables'][0]['Rows'].map { |row| row['id'] }
      result = bosh_runner.run("diff-config --from-id #{from.to_i} --to-id #{to.to_i}")
      expect(result).to include('- vm_types:', '+ releases:', 'Succeeded')
    end

    it 'diffs one saved and one local config' do
      bosh_runner.run("update-config --type=my-type --name=default #{config.path}")

      output = bosh_runner.run('configs --recent=99 --json')
      from = JSON.parse(output)['Tables'][0]['Rows'].map { |row| row['id'] }.first
      result = bosh_runner.run("diff-config --from-id #{from.to_i} --to-content #{other_config.path}")
      expect(result).to include('- vm_types:', '+ releases:', 'Succeeded')
    end

    it 'diffs two local configs' do
      expect(bosh_runner.run("diff-config --from-content #{config.path} --to-content #{other_config.path}")).to include('- vm_types:', '+ releases:', 'Succeeded')
    end
  end

  context 'can delete a config' do
    it 'delete a config' do
      bosh_runner.run("update-config --type=my-type --name=my-name #{config.path}")
      bosh_runner.run("update-config --type=other-type --name=other-name #{config.path}")

      expect(bosh_runner.run('delete-config --type=my-type --name=my-name')).to include('Succeeded')
      output = bosh_runner.run('configs')
      expect(output).to_not include('my-type', 'my-name')
      expect(output).to include('other-type', 'other-name')
    end

    it 'delete a config by id' do
      output = bosh_runner.run("update-config --type=my-type --name=my-name #{config.path} --json")
      config_id = JSON.parse(output)['Tables'][0]['Rows'][0]['id']
      bosh_runner.run("update-config --type=other-type --name=other-name #{config.path}")

      expect(bosh_runner.run("delete-config #{config_id}")).to include('Succeeded')
      output = bosh_runner.run('configs')
      expect(output).to_not include('my-type', 'my-name')
      expect(output).to include('other-type', 'other-name')
    end

    it 'warns if there is nothing to delete' do
      output = bosh_runner.run('delete-config --type=my-type --name=default')
      expect(output).to include('Succeeded')
      expect(output).to include('No configs to delete')
    end
  end

  it 'gives nice errors for common problems when uploading', no_reset: true do
    # not logged in
    expect(
      bosh_runner.run(
        "update-config --type=my-type --name=default #{config.path}",
        include_credentials: false,
        failure_expected: true,
      ),
    ).to include("Director responded with non-successful status code '401'")

    # no file
    expect(
      bosh_runner.run(
        'update-config --type=my-type --name=default /some/nonsense/file',
        failure_expected: true,
      ),
    ).to include('no such file or directory')

    # file not yaml
    Dir.mktmpdir do |tmpdir|
      config_filename = File.join(tmpdir, 'config.yml')
      File.write(config_filename, "---\n}}}invalid yaml!")
      expect(
        bosh_runner.run(
          "update-config --type=my-type --name=default #{config_filename}",
          failure_expected: true,
        ),
      ).to include('did not find expected node content')
    end
  end
end
