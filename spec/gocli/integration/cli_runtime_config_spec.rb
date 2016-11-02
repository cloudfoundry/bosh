require_relative '../spec_helper'

describe 'cli runtime config', type: :integration do
  with_reset_sandbox_before_each

  it 'can upload a runtime config' do
    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      File.write(runtime_config_filename, Psych.dump(Bosh::Spec::Deployments.simple_runtime_config))
      expect(bosh_runner.run("update-runtime-config #{runtime_config_filename}")).to include('Succeeded')
    end
  end

  it 'gives nice errors for common problems when uploading', no_reset: true do
    pending 'QUESTION Discuss correct behavior with Dmitriy on non-logged-in users and files that are not present'

    # not logged in
    expect(bosh_runner.run("update-runtime-config #{__FILE__}", failure_expected: true)).to include('Please log in first')

    bosh_runner.run('log-in', user: 'test', password: 'test')

    # no file
    expect(bosh_runner.run('update-runtime-config /some/nonsense/file', failure_expected: true)).to include("Cannot find file '/some/nonsense/file'")

    # file not yaml
    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      File.write(runtime_config_filename, "---\n}}}i'm not really yaml, hah!")
      expect(bosh_runner.run("update-runtime-config #{runtime_config_filename}", failure_expected: true)).to include('Incorrect YAML structure')
    end

    # empty runtime config file
    Dir.mktmpdir do |tmpdir|
      empty_runtime_config_filename = File.join(tmpdir, 'empty_runtime_config.yml')
      File.write(empty_runtime_config_filename, '')
      expect(bosh_runner.run("update-cloud-config #{empty_runtime_config_filename}", failure_expected: true)).to include('Error 440001: Manifest should not be empty')
    end
  end

  it 'can download a runtime config' do

    # none present yet
    expect(bosh_runner.run('runtime-config', failure_expected: true)).to match(/Using environment 'https:\/\/127\.0\.0\.1:\d+' as user 'test'/)

    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      runtime_config = Psych.dump(Bosh::Spec::Deployments.simple_runtime_config)
      File.write(runtime_config_filename, runtime_config)
      bosh_runner.run("update-runtime-config #{runtime_config_filename}")

      expect(YAML.load(bosh_runner.run('runtime-config', tty: false))).to eq(YAML.load(runtime_config))
    end
  end

  it "gives an error when release version is 'latest'" do
    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      File.write(runtime_config_filename, Psych.dump(Bosh::Spec::Deployments.runtime_config_latest_release))
      expect(bosh_runner.run("update-runtime-config #{runtime_config_filename}", failure_expected: true)).to include(
        "Runtime manifest contains the release 'test_release_2' with version as 'latest'. Please specify the actual version string.")
    end
  end

  it 'gives an error when release for addon does not exist in releases section' do
    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      File.write(runtime_config_filename, Psych.dump(Bosh::Spec::Deployments.runtime_config_release_missing))
      expect(bosh_runner.run("update-runtime-config #{runtime_config_filename}", failure_expected: true)).to include(
        "Runtime manifest specifies job 'job_using_pkg_2' which is defined in 'release2', but 'release2' is not listed in the releases section.")
    end
  end

  it 'does not fail when runtime config is very large' do
    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      runtime_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.simple_runtime_config)

      for i in 0..10001
        runtime_config["boshbosh#{i}"] = 'smurfsAreBlueGargamelIsBrownPinkpantherIsPinkAndPikachuIsYellow'
      end

      runtime_config = Psych.dump(runtime_config)

      File.write(runtime_config_filename, runtime_config)
      output, exit_code = bosh_runner.run("update-runtime-config #{runtime_config_filename}", return_exit_code: true)
      expect(output).to include('Succeeded')
      expect(exit_code).to eq(0)
    end
  end
end
