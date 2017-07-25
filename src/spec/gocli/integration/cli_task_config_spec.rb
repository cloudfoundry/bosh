require_relative '../spec_helper'

describe "cli task config", type: :integration do
  with_reset_sandbox_before_each

  it "updates and displays task config" do
    task_yaml = yaml_file('task', Bosh::Spec::Deployments.simple_task_config(false))
    expect(bosh_runner.run("update-task-config #{task_yaml.path}")).to include("Succeeded")
    output = bosh_runner.run("task-config")
    expect(output).to include('paused: false')
    task_yaml = yaml_file('task', Bosh::Spec::Deployments.simple_task_config(true))
    expect(bosh_runner.run("update-task-config #{task_yaml.path}")).to include("Succeeded")
    output = bosh_runner.run("task-config")
    expect(output).to include('paused: true')
  end

  it "gives nice errors for common problems when uploading", no_reset: true do
    # no file
    expect(bosh_runner.run("update-task-config /some/nonsense/file", failure_expected: true)).to include("no such file or directory")

    # file not yaml
    Dir.mktmpdir do |tmpdir|
      task_config_filename = File.join(tmpdir, 'task_config.yml')
      File.write(task_config_filename, "---\n}}}i'm not really yaml, hah!")
      expect(bosh_runner.run("update-task-config #{task_config_filename}", failure_expected: true)).to include("did not find expected node content")
    end

    # empty task config file
    Dir.mktmpdir do |tmpdir|
      empty_task_config_filename = File.join(tmpdir, 'empty_task_config.yml')
      File.write(empty_task_config_filename, '')
      expect(bosh_runner.run("update-task-config #{empty_task_config_filename}", failure_expected: true)).to include('Incorrect YAML structure of the uploaded manifest')
    end
  end

  it "can download a task config" do
    # none present yet
    output = bosh_runner.run("task-config", failure_expected: true)
    expect(output).to include('No Task config')

    Dir.mktmpdir do |tmpdir|
      task_yaml = yaml_file('task', Bosh::Spec::Deployments.simple_task_config)
      bosh_runner.run("update-task-config #{task_yaml.path}")

      tasks_str = bosh_runner.run("task-config", tty: false)
      tasks = YAML.load(tasks_str)
      expect(tasks).to eq(Bosh::Spec::Deployments.simple_task_config)
    end
  end

end
