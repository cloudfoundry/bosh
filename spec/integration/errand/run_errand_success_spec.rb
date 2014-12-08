require 'spec_helper'

#Errand failure/success were split up so that they can be run on different rspec:parallel threads
describe 'run errand success', type: :integration, with_tmp_dir: true do
  context 'while errand is running' do
    with_reset_sandbox_before_each

    let(:manifest_hash) do
      manifest_hash = Bosh::Spec::Deployments.manifest_with_errand
      manifest_hash['properties'] = {
        'errand1' => {
          'sleep_duration_in_seconds' => 60,
        },
      }
      manifest_hash
    end

    it 'creates a deployment lock' do
      deploy_simple(manifest_hash: manifest_hash)

      bosh_runner.run('--no-track run errand fake-errand-name')
      output = bosh_runner.run_until_succeeds('locks')
      expect(output).to match(/\s*\|\s*deployment\s*\|\s*errand\s*\|/)
    end
  end

  context 'when multiple errands exist in the deployment manifest' do
    with_reset_sandbox_before_each

    let(:manifest_hash) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest

      # Include other jobs in the deployment
      manifest_hash['resource_pools'].first['size'] = 3
      manifest_hash['jobs'].first['instances'] = 1

      # First errand
      manifest_hash['jobs'] << {
        'name'          => 'errand1-name',
        'template'      => 'errand1',
        'lifecycle'     => 'errand',
        'resource_pool' => 'a',
        'instances'     => 1,
        'networks'      => [{ 'name' => 'a' }],
        'properties' => {
          'errand1' => {
            'exit_code' => 0,
            'stdout'    => 'some-errand1-stdout',
            'stderr'    => 'some-errand1-stderr',
            'run_package_file' => true,
          },
        },
      }

      # Second errand
      manifest_hash['jobs'] << {
        'name'          => 'errand2-name',
        'template'      => 'errand1',
        'lifecycle'     => 'errand',
        'resource_pool' => 'a',
        'instances'     => 2,
        'networks'      => [{ 'name' => 'a' }],
        'properties' => {
          'errand1' => {
            'exit_code' => 0,
            'stdout'    => 'some-errand2-stdout',
            'stderr'    => 'some-errand2-stderr',
            'run_package_file' => true,
          },
        },
      }

      manifest_hash
    end

    context 'with a fixed size resource pool size' do
      before { manifest_hash['resource_pools'].first['size'] = 3 }

      it 'allocates enough empty VMs for the largest errand on deploy and reallocates empty VMs after each errand run' do
        deploy_simple(manifest_hash: manifest_hash)
        expect_running_vms(%w(foobar/0 unknown/unknown unknown/unknown))

        expect_errands('errand1-name', 'errand2-name')

        output, exit_code = bosh_runner.run('run errand errand1-name', return_exit_code: true)
        expect(output).to include('some-errand1-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms(%w(foobar/0 unknown/unknown unknown/unknown))

        output, exit_code = bosh_runner.run('run errand errand2-name', return_exit_code: true)
        expect(output).to include('some-errand2-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms(%w(foobar/0 unknown/unknown unknown/unknown))
      end

      context 'with the keep-alive option set' do
        it 'does not delete/create the errand vm' do
          deploy_simple(manifest_hash: manifest_hash)

          output, exit_code = bosh_runner.run('run errand errand1-name --keep-alive', return_exit_code: true)
          expect(output).to include('some-errand1-stdout')
          expect(exit_code).to eq(0)
          expect_running_vms(%w(errand1-name/0 foobar/0 unknown/unknown))

          output, exit_code = bosh_runner.run('run errand errand1-name --keep-alive', return_exit_code: true)
          expect(output).to include('some-errand1-stdout')
          expect(exit_code).to eq(0)
          expect_running_vms(%w(errand1-name/0 foobar/0 unknown/unknown))

          output, exit_code = bosh_runner.run('run errand errand1-name', return_exit_code: true)
          expect(output).to include('some-errand1-stdout')
          expect(exit_code).to eq(0)
          expect_running_vms(%w(foobar/0 unknown/unknown unknown/unknown))
        end
      end
    end

    context 'with a dynamically sized resource pool size' do
      before { manifest_hash['resource_pools'].first.delete('size') }

      it 'allocates and de-allocates errand vms for each errand run' do
        deploy_simple(manifest_hash: manifest_hash)
        expect_running_vms(%w(foobar/0))

        expect_errands('errand1-name', 'errand2-name')

        output, exit_code = bosh_runner.run('run errand errand1-name', return_exit_code: true)
        expect(output).to include('some-errand1-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms(%w(foobar/0))

        output, exit_code = bosh_runner.run('run errand errand2-name', return_exit_code: true)
        expect(output).to include('some-errand2-stdout')
        expect(exit_code).to eq(0)
        expect_running_vms(%w(foobar/0))
      end

      context 'with the keep-alive option set' do
        it 'does not delete/create the errand vm' do
          deploy_simple(manifest_hash: manifest_hash)

          output, exit_code = bosh_runner.run('run errand errand1-name --keep-alive', return_exit_code: true)
          expect(output).to include('some-errand1-stdout')
          expect(exit_code).to eq(0)
          expect_running_vms(%w(errand1-name/0 foobar/0))

          output, exit_code = bosh_runner.run('run errand errand1-name --keep-alive', return_exit_code: true)
          expect(output).to include('some-errand1-stdout')
          expect(exit_code).to eq(0)
          expect_running_vms(%w(errand1-name/0 foobar/0))

          output, exit_code = bosh_runner.run('run errand errand1-name', return_exit_code: true)
          expect(output).to include('some-errand1-stdout')
          expect(exit_code).to eq(0)
          expect_running_vms(%w(foobar/0))
        end
      end
    end
  end

  context 'when errand script exits with 0 exit code' do
    with_reset_sandbox_before_all
    with_tmp_dir_before_all

    before(:all) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest

      # Include other jobs in the deployment
      manifest_hash['jobs'].first['instances'] = 1

      # Currently errands are represented via jobs
      manifest_hash['jobs'] << {
        'name'          => 'errand1-name',
        'template'      => 'errand1',
        'lifecycle'     => 'errand',
        'resource_pool' => 'a',
        'instances'     => 1,
        'networks'      => [{ 'name' => 'a' }],
        'properties' => {
          'errand1' => {
            'exit_code' => 0,
            'stdout'    => 'some-stdout',
            'stderr'    => 'some-stderr',
            'run_package_file' => true,
          },
        },
      }

      deploy_simple(manifest_hash: manifest_hash)

      expect_errands('errand1-name')

      @output, @exit_code = bosh_runner.run("run errand errand1-name --download-logs --logs-dir #{@tmp_dir}",
                                            {return_exit_code: true})
    end

    it 'shows bin/run stdout and stderr' do
      expect(@output).to include('some-stdout')
      expect(@output).to include('some-stderr')
    end

    it 'shows output generated by package script which proves dependent packages are included' do
      expect(@output).to include('stdout-from-errand1-package')
    end

    it 'downloads errand logs and shows downloaded location' do
      expect(@output =~ /Logs saved in `(.*errand1-name\.0\..*\.tgz)'/).to_not(be_nil, @output)
      logs_file = Bosh::Spec::TarFileInspector.new($1)
      expect(logs_file.file_names).to match_array(%w(./errand1/stdout.log ./custom.log))
      expect(logs_file.smallest_file_size).to be > 0
    end

    it 'returns 0 as exit code from the cli and indicates that errand ran successfully' do
      expect(@output).to include('Errand `errand1-name\' completed successfully (exit code 0)')
      expect(@exit_code).to eq(0)
    end
  end

  def expect_errands(*expected_errands)
    output, _ = bosh_runner.run('errands')
    expected_errands.each do |errand|
      expect(output).to include(errand)
    end
  end
end
