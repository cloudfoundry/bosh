require_relative '../spec_helper'

describe "cli cpi config", type: :integration do
  with_reset_sandbox_before_each

  context 'when using old cpi-config command' do
    it 'can upload and download a cpi-config' do
      output = bosh_runner.run('cpi-config', failure_expected: true)
      expect(output).to include('No CPI config')

      cpi_yaml = yaml_file('cpi', Bosh::Spec::Deployments.multi_cpi_config)

      upload_output = bosh_runner.run("update-cpi-config #{cpi_yaml.path}")

      expect(upload_output).to include('Succeeded')

      download_output = YAML.load(bosh_runner.run('cpi-config', tty: false))

      expect(download_output).to eq(Bosh::Spec::Deployments.multi_cpi_config)
    end
  end

  context 'when using multiple named cpi configs' do
    it 'can upload and download them' do
      output = bosh_runner.run('config --type=cpi --name=default', failure_expected: true)
      expect(output).to include('No config')

      cpi1_yaml = yaml_file('cpi1', Bosh::Spec::Deployments.single_cpi_config('cpi-name1'))
      cpi2_yaml = yaml_file('cpi2', Bosh::Spec::Deployments.single_cpi_config('cpi-name2'))

      upload1_output = bosh_runner.run("update-config --name=cpi_config_1 --type=cpi #{cpi1_yaml.path}")
      upload2_output = bosh_runner.run("update-config --name=cpi_config_2 --type=cpi #{cpi2_yaml.path}")

      expect(upload1_output).to include('Succeeded')
      expect(upload2_output).to include('Succeeded')

      download1_output = bosh_runner.run('config --name=cpi_config_1 --type=cpi', tty: false)
      download2_output = bosh_runner.run('config --name=cpi_config_2 --type=cpi', tty: false)

      expect(download1_output).to include('cpi-name1')
      expect(download2_output).to include('cpi-name2', 'somekey: someval')
    end
  end

  it 'does not fail when cpi config is very large' do
    cpi_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.multi_cpi_config)

    (0..10001).each { |i|
      cpi_config["boshbosh#{i}"] = 'smurfsAreBlueGargamelIsBrownPinkpantherIsPinkAndPikachuIsYellow'
    }

    cpi_yaml = yaml_file('cpi_config.yml', cpi_config)
    output, exit_code = bosh_runner.run("update-cpi-config #{cpi_yaml.path}", return_exit_code: true)
    expect(output).to include('Succeeded')
    expect(exit_code).to eq(0)
  end

  it 'gives nice errors for common problems when uploading', no_reset: true do
    # no file
    expect(bosh_runner.run("update-cpi-config /some/nonsense/file", failure_expected: true)).to include("no such file or directory")

    # file not yaml
    Dir.mktmpdir do |tmpdir|
      cpi_config_filename = File.join(tmpdir, 'cpi_config.yml')
      File.write(cpi_config_filename, "---\n}}}i'm not really yaml, hah!")
      expect(bosh_runner.run("update-cpi-config #{cpi_config_filename}", failure_expected: true)).to include("did not find expected node content")
    end

    # empty cpi config file
    Dir.mktmpdir do |tmpdir|
      empty_cpi_config_filename = File.join(tmpdir, 'empty_cpi_config.yml')
      File.write(empty_cpi_config_filename, '--- {}')
      expect(bosh_runner.run("update-cpi-config #{empty_cpi_config_filename}", failure_expected: true)).to include("Required property 'cpis' was not specified in object")
    end
  end
end
