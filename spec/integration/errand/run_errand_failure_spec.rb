require 'spec_helper'

#Errand failure/success were split up so that they can be run on different rspec:parallel threads
describe 'run errand failure', type: :integration, with_tmp_dir: true do

  context 'when errand script exits with non-0 exit code' do
    with_reset_sandbox_before_each
    with_tmp_dir_before_all

    before do
      manifest_hash = Bosh::Spec::Deployments.manifest_with_errand
      jobs = manifest_hash['jobs']

      jobs.find { |job| job['name'] == 'fake-errand-name'}['properties'] = {
        'errand1' => {
          'exit_code' => 23, # non-0 (and non-1) exit code
          'stdout'    => '', # No output
          'stderr'    => "some-stderr1\nsome-stderr2\nsome-stderr3",
        },
      }

      deploy_from_scratch(manifest_hash: manifest_hash)
    end

    context 'with the keep-alive option set' do
      it 'does not delete/create the errand vm' do
        output, exit_code = bosh_runner.run("run errand fake-errand-name --download-logs --logs-dir #{@tmp_dir} --keep-alive",
          {failure_expected: true, return_exit_code: true})
        expect(output).to include("[stdout]\nNone")
        expect(output).to include("some-stderr1\nsome-stderr2\nsome-stderr3")
        expect(exit_code).to_not eq(0)

        expect_running_vms_with_names_and_count('fake-errand-name' => 1, 'foobar' => 1)
      end
    end

    it 'shows the errors and deletes the vm without keep-alive option set' do
      output, exit_code = bosh_runner.run(
        "run errand fake-errand-name --download-logs --logs-dir #{@tmp_dir}",
        {failure_expected: true, return_exit_code: true}
      )
      expect(exit_code).to eq(1)

      expect_running_vms_with_names_and_count('foobar' => 1)

      expect(output).to include("[stdout]\nNone")
      expect(output).to include("some-stderr1\nsome-stderr2\nsome-stderr3")
      expect(output).to include("Errand 'fake-errand-name' completed with error (exit code 23)")
      expect(output =~ /Logs saved in '(.*fake-errand-name\.0\..*\.tgz)'/).to_not(be_nil, @output)
      logs_file = Bosh::Spec::TarFileInspector.new($1)
      expect(logs_file.file_names).to match_array(%w(./errand1/stdout.log ./custom.log))
      expect(logs_file.smallest_file_size).to be > 0
    end
  end

  context 'when errand is canceled' do
    with_reset_sandbox_before_each

    let(:manifest_hash) do
      manifest_hash = Bosh::Spec::Deployments.manifest_with_errand

      # Sleep so we have time to cancel it
      manifest_hash['jobs'].last['properties']['errand1']['blocking_errand'] = true

      manifest_hash
    end

    it 'successfully cancels the errand and returns exit code' do
      deploy_from_scratch(manifest_hash: manifest_hash)

      errand_result = bosh_runner.run('--no-track run errand fake-errand-name')
      task_id = Bosh::Spec::OutputParser.new(errand_result).task_id('running')

      director.wait_for_vm('fake-errand-name', '0', 10)

      cancel_output = bosh_runner.run("cancel task #{task_id}")
      expect(cancel_output).to match(/Task #{task_id} is getting canceled/)

      errand_output = bosh_runner.run("task #{task_id}")
      expect(errand_output).to include("Error 10001: Task #{task_id} cancelled")

      # Cannot assert on output because there is no guarantee
      # that process will be cancelled after output is echoed
      result_output = bosh_runner.run("task #{task_id} --result")
      # can be either terminated or killed
      expect(result_output).to  match /"exit_code":(143|137)/
    end
  end

  context 'when errand cannot be run because there is no bin/run found in the job template' do
    with_reset_sandbox_before_each

    let(:manifest_hash) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest

      # Mark foobar as an errand even though it does not have bin/run
      manifest_hash['jobs'].first['lifecycle'] = 'errand'

      manifest_hash
    end

    it 'returns 1 as exit code and mentions absence of bin/run' do
      deploy_from_scratch(manifest_hash: manifest_hash)

      output, exit_code = bosh_runner.run('run errand foobar', {failure_expected: true, return_exit_code: true})

      expect(output).to match(
        %r{Error 450001: (.*Running errand script:.*jobs/foobar/bin/run: no such file or directory)}
      )
      expect(output).to include("Errand 'foobar' did not complete")
      expect(exit_code).to eq(1)
    end
  end

  context 'when errand does not exist in the deployment manifest' do
    with_reset_sandbox_before_each

    it 'returns 1 as exit code and mentions not found errand' do
      deploy_from_scratch

      output, exit_code = bosh_runner.run('run errand unknown-errand-name',
                                          {failure_expected: true, return_exit_code: true})

      expect(output).to include("Errand 'unknown-errand-name' doesn't exist")
      expect(output).to include("Errand 'unknown-errand-name' did not complete")
      expect(exit_code).to eq(1)
    end
  end
end
