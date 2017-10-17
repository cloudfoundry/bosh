require_relative '../spec_helper'

describe 'cli configs', type: :integration do
  with_reset_sandbox_before_each

  let(:config) { yaml_file('config.yml', Bosh::Spec::Deployments.simple_cloud_config) }

  context 'can upload a config' do
    context 'when config uses placeholders' do
      let(:config) {yaml_file('config.yml', Bosh::Spec::Deployments.manifest_errand_with_placeholders)}

      it 'replaces placeholders' do
        expect(bosh_runner.run("update-config -v placeholder=my-data my-type #{config.path}")).to include('Succeeded')
        expect(bosh_runner.run("config my-type")).to include('my-data')
      end
    end

    it 'updates config' do
      expect(bosh_runner.run("update-config my-type #{config.path}")).to include('Succeeded')
    end

    it 'updates named config' do
      expect(bosh_runner.run("update-config --name=my-name my-type #{config.path}")).to include('Succeeded')
    end

    it 'updates config with default name' do
      bosh_runner.run("update-config my-type #{config.path}")
      expect(bosh_runner.run('configs --type=my-type --json')).to include('"name": "default"')
    end

    it 'uploads an empty YAML hash' do
      Dir.mktmpdir do |tmpdir|
        empty_config_filename = File.join(tmpdir, 'empty_config.yml')
        File.write(empty_config_filename, '{}')
        expect(bosh_runner.run("update-config my-type #{empty_config_filename}")).to include('Succeeded')
      end
    end
    
    it 'does not fail if the uploaded config is a large file' do
      config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.simple_cloud_config)

      for i in 0..10001
        config["boshbosh#{i}"] = 'smurfsAreBlueGargamelIsBrownPinkpantherIsPinkAndPikachuIsYellow'
      end

      cloud_config_file = yaml_file('config.yml', config)

      output, exit_code = bosh_runner.run("update-config large-config #{cloud_config_file.path}", return_exit_code: true)
      expect(output).to include('Succeeded')
      expect(exit_code).to eq(0)
    end
  end

  context 'can list configs' do
    it 'lists configs' do
      bosh_runner.run("update-config my-type #{config.path}")
      bosh_runner.run("update-config other-type --name=other-name #{config.path}")

      expect(bosh_runner.run("configs")).to include('default', 'other-name', 'my-type', 'other-type')
    end

    it 'can filter lists configs' do
      bosh_runner.run("update-config my-type --name=my-name #{config.path}")
      bosh_runner.run("update-config other-type --name=other-name #{config.path}")

      output = bosh_runner.run('configs --type=my-type --name=my-name')
      expect(output).to_not include('other-type','other-name')
      expect(output).to include('my-type', 'my-name')
    end
  end

  context 'can delete a config' do
    it 'delete a config' do
      bosh_runner.run("update-config my-type --name=my-name #{config.path}")
      bosh_runner.run("update-config other-type --name=other-name #{config.path}")

      expect(bosh_runner.run("delete-config my-type --name=my-name")).to include('Succeeded')
      output = bosh_runner.run("configs")
      expect(output).to_not include('my-type','my-name')
      expect(output).to include('other-type', 'other-name')
    end

    it 'warns if there is nothing to delete' do
      output = bosh_runner.run('delete-config my-type')
      expect(output).to include('Succeeded')
      expect(output).to include('No configs to delete')
    end
  end

  it 'gives nice errors for common problems when uploading', no_reset: true do
    # not logged in
    expect(bosh_runner.run("update-config my-type #{config.path}", include_credentials: false, failure_expected: true)).to include('Retry: Post')

    # no file
    expect(bosh_runner.run('update-config my-type /some/nonsense/file', failure_expected: true)).to include('no such file or directory')

    # file not yaml
    Dir.mktmpdir do |tmpdir|
      config_filename = File.join(tmpdir, 'config.yml')
      File.write(config_filename, "---\n}}}invalid yaml!")
      expect(bosh_runner.run("update-config my-type #{config_filename}", failure_expected: true)).to include('did not find expected node content')
    end
  end
end
