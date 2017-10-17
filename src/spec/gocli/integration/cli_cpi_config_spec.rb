require_relative '../spec_helper'

describe "cli cpi config", type: :integration do
  with_reset_sandbox_before_each

  it "can upload a cpi config" do
    cpi_yaml = yaml_file('cpi', Bosh::Spec::Deployments.simple_cpi_config)

    expect(bosh_runner.run("update-cpi-config #{cpi_yaml.path}")).to include("Succeeded")
  end

  it "gives nice errors for common problems when uploading", no_reset: true do
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
      File.write(empty_cpi_config_filename, '')
      expect(bosh_runner.run("update-cpi-config #{empty_cpi_config_filename}", failure_expected: true)).to include("Required property 'cpis' was not specified in object")
    end
  end

  it "can download a cpi config" do
    # none present yet
    output = bosh_runner.run("cpi-config", failure_expected: true)
    expect(output).to include('No CPI config')

    Dir.mktmpdir do |tmpdir|
      cpi_yaml = yaml_file('cpi', Bosh::Spec::Deployments.simple_cpi_config)
      bosh_runner.run("update-cpi-config #{cpi_yaml.path}")

      cpis_str = bosh_runner.run("cpi-config", tty: false)
      cpis = YAML.load(cpis_str)
      expect(cpis).to eq(Bosh::Spec::Deployments.simple_cpi_config)
      # expect(bosh_runner.run("cpi-config", tty: false)).to include(cpi_config.gsub(/^\-\-\-\n/, ''))
    end
  end

  it 'does not fail when cpi config is very large' do
    Dir.mktmpdir do |tmpdir|
      cpi_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.simple_cpi_config)

      for i in 0..10001
        cpi_config["boshbosh#{i}"] = 'smurfsAreBlueGargamelIsBrownPinkpantherIsPinkAndPikachuIsYellow'
      end

      cpi_yaml = yaml_file('cpi_config.yml', cpi_config)
      output, exit_code = bosh_runner.run("update-cpi-config #{cpi_yaml.path}", return_exit_code: true)
      expect(output).to include('Succeeded')
      expect(exit_code).to eq(0)
    end
  end
end
