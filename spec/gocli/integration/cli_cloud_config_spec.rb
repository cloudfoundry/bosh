require_relative '../spec_helper'

describe 'cli cloud config', type: :integration do
  with_reset_sandbox_before_each

  it 'can upload a cloud config' do
    Dir.mktmpdir do |tmpdir|
      cloud_config_filename = File.join(tmpdir, 'cloud_config.yml')
      File.write(cloud_config_filename, Psych.dump(Bosh::Spec::Deployments.simple_cloud_config))
      expect(bosh_runner.run("update-cloud-config #{cloud_config_filename}")).to include('Succeeded')
    end
  end

  it 'gives nice errors for common problems when uploading', no_reset: true do
    pending 'QUESTION Discuss correct behavior with Dmitriy on non-logged-in users and files that are not present'

    # not logged in
    expect(bosh_runner.run("update-cloud-config #{__FILE__}", include_credentials: false, failure_expected: true)).to include('Please log in first')

    # no file
    expect(bosh_runner.run('update-cloud-config /some/nonsense/file', failure_expected: true)).to include("Cannot find file '/some/nonsense/file'")

    # file not yaml
    Dir.mktmpdir do |tmpdir|
      cloud_config_filename = File.join(tmpdir, 'cloud_config.yml')
      File.write(cloud_config_filename, "---\n}}}i'm not really yaml, hah!")
      expect(bosh_runner.run("update-cloud-config #{cloud_config_filename}", failure_expected: true)).to include('Incorrect YAML structure')
    end

    # empty cloud config file
    Dir.mktmpdir do |tmpdir|
      empty_cloud_config_filename = File.join(tmpdir, 'empty_cloud_config.yml')
      File.write(empty_cloud_config_filename, '')
      expect(bosh_runner.run("update-cloud-config #{empty_cloud_config_filename}", failure_expected: true)).to include('Error 440001: Manifest should not be empty')
    end
  end

  it 'can download a cloud config' do
    # none present yet
    expect(bosh_runner.run('cloud-config', failure_expected: true)).to match(/Using environment 'https:\/\/127\.0\.0\.1:\d+' as user 'test'/)

    Dir.mktmpdir do |tmpdir|
      cloud_config_filename = File.join(tmpdir, 'cloud_config.yml')
      cloud_config = Psych.dump(Bosh::Spec::Deployments.simple_cloud_config)
      File.write(cloud_config_filename, cloud_config)
      bosh_runner.run("update-cloud-config #{cloud_config_filename}")

      expect(YAML.load(bosh_runner.run('cloud-config', tty: false))).to eq(YAML.load(cloud_config))
    end
  end

  it 'does not fail if the uploaded cloud config is a large file' do
    Dir.mktmpdir do |tmpdir|
      cloud_config_filename = File.join(tmpdir, 'cloud_config.yml')
      cloud_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.simple_cloud_config)

      for i in 0..10001
        cloud_config["boshbosh#{i}"] = 'smurfsAreBlueGargamelIsBrownPinkpantherIsPinkAndPikachuIsYellow'
      end

      cloud_config = Psych.dump(cloud_config)
      File.write(cloud_config_filename, cloud_config)

      output, exit_code = bosh_runner.run("update-cloud-config #{cloud_config_filename}", return_exit_code: true)
      expect(output).to include('Succeeded')
      expect(exit_code).to eq(0)
    end
  end
end
