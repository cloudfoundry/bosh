require 'spec_helper'

describe Bosh::Cli::Command::LogManagement do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Client::Director) }

  let(:deployment) { 'mycloud' }
  let(:job) { 'dea' }
  let(:index) { '6' }

  let(:manifest) do
    {
      'name' => deployment,
      'uuid' => 'totally-and-universally-unique',
      'jobs' => [{
        'name' => 'dea',
        'instances' => 5
      }]
    }
  end

  before do
    allow(command).to receive_messages(target: 'http://bosh.example.com')
    allow(command).to receive_messages(logged_in?: true)
    allow(command).to receive_messages(director: director)
    allow(command).to receive_messages(prepare_deployment_manifest: double(:manifest, hash: manifest, name: 'mycloud'))
    allow(command).to receive(:say)
    allow(command).to receive(:show_current_state)
    allow(director).to receive_messages(fetch_logs: 'resource-id', download_resource: '/tmp/resource')
  end

  before { allow(FileUtils).to receive(:mv) }

  describe 'fetching logs' do
    it 'requires that a bosh deployment is targeted' do
      allow(command).to receive_messages(:target => nil)

      expect {
        command.fetch_logs(job, index)
      }.to raise_error(Bosh::Cli::CliError, 'Please choose target first')
    end

    it 'tells the user that --no-track is unsupported' do
      command.options[:no_track] = true

      expect(command).to receive(:say).with("Ignoring `--no-track' option")
      command.fetch_logs(job, index)
    end

    context 'when a deployment is targeted' do
      before { allow(command).to receive_messages(target: 'http://bosh.example.com:25555') }

      it_requires_logged_in_user ->(command) { command.fetch_logs('dea', '6') }

      context 'when logged in' do
        before { allow(command).to receive_messages(:logged_in? => true) }

        it 'does not allow --only and --all together' do
          command.options[:only] = %w(cloud_controller uaa)
          command.options[:all] = true

          expect {
            command.fetch_logs(job, index)
          }.to raise_error(Bosh::Cli::CliError, "You can't use --only and --all together")
        end

        context 'when fetching agent logs' do
          before { command.options[:agent] = true }

          it 'does not allow --agent and --job together' do
            command.options[:job] = true

            expect {
              command.fetch_logs(job, index)
            }.to raise_error(Bosh::Cli::CliError, "You can't use --job and --agent together")
          end

          it 'does not allow --only filtering' do
            command.options[:only] = %w(cloud_controller uaa)

            expect {
              command.fetch_logs(job, index)
            }.to raise_error(Bosh::Cli::CliError, 'Custom filtering is not supported for agent logs')
          end

          it 'successfully retrieves the log resource id' do
            expect(director).to receive(:fetch_logs).with(deployment, job, index, 'agent', nil).and_return('resource_id')
            command.fetch_logs(job, index)
          end

          it 'ignores the --all option' do
            command.options[:all] = true

            expect(director).to receive(:fetch_logs).with(deployment, job, index, 'agent', nil).and_return('resource_id')
            command.fetch_logs(job, index)
          end
        end

        context 'when fetching job logs' do
          before { command.options[:job] = true }

          it 'successfully retrieves the log resource id' do
            expect(director).to receive(:fetch_logs).with(deployment, job, index, 'job', nil).and_return('resource_id')
            command.fetch_logs(job, index)
          end

          it 'ignores the --all option' do
            command.options[:all] = true

            expect(director).to receive(:fetch_logs).with(deployment, job, index, 'job', nil).and_return('resource_id')
            command.fetch_logs(job, index)
          end

          it 'prints deprecation warning about the --all option' do
            command.options[:all] = true

            expect(command).to receive(:say).with('Warning: --all flag is deprecated and has no effect.')
            command.fetch_logs(job, index)
          end

          it 'successfully retrieves the log resource id with only filters' do
            command.options[:only] = %w(cloud_controller uaa)

            expect(director).to receive(:fetch_logs).with(deployment, job, index, 'job', 'cloud_controller,uaa').and_return('resource_id')
            command.fetch_logs(job, index)
          end

          it 'errors if the resource id returned is nil' do
            allow(director).to receive_messages(fetch_logs: nil)

            expect {
              command.fetch_logs(job, index)
            }.to raise_error(Bosh::Cli::CliError, 'Error retrieving logs')
          end

          it 'tells the user about the log bundle it found' do
            allow(director).to receive_messages(fetch_logs: 'bundle-id')

            expect(command).to receive(:say).with('Downloading log bundle (bundle-id)...')
            command.fetch_logs(job, index)
          end

          it 'downloads the file and moves it to a timestamped file' do
            Timecop.freeze do
              time = Time.now.strftime('%Y-%m-%d-%H-%M-%S')

              allow(director).to receive_messages(fetch_logs: 'resource-id')
              expect(director).to receive(:download_resource).with('resource-id').and_return('/wonderful/path')
              expect(FileUtils).to receive(:mv).with('/wonderful/path', "#{Dir.pwd}/#{job}.#{index}.#{time}.tgz")
              command.fetch_logs(job, index)
            end
          end

          it 'downloads the file and moves it to a timestamped file to a different dir' do
            Timecop.freeze do
              command.options[:dir] = '/woah-now'
              time = Time.now.strftime('%Y-%m-%d-%H-%M-%S')

              allow(director).to receive_messages(fetch_logs: 'resource-id')
              expect(director).to receive(:download_resource).with('resource-id').and_return('/wonderful/path')
              expect(FileUtils).to receive(:mv).with('/wonderful/path', "/woah-now/#{job}.#{index}.#{time}.tgz")
              command.fetch_logs(job, index)
            end
          end

          it 'tells the user if the logs could not be downloaded' do
            expect(director).to receive(:download_resource).and_raise(Bosh::Cli::DirectorError.new)

            expect {
              command.fetch_logs(job, index)
            }.to raise_error(Bosh::Cli::CliError, /Unable to download logs from director:/)
          end

          context 'when we do not specify the job index and it is unique' do
            let(:manifest) do
              {
                'name' => deployment,
                'uuid' => 'totally-and-universally-unique',
                'jobs' => [{
                  'name' => 'dea',
                  'instances' => 1
                }]
              }
            end

            it 'does all the same things' do
              Timecop.freeze do
                time = Time.now.strftime('%Y-%m-%d-%H-%M-%S')
                allow(director).to receive_messages(fetch_logs: 'resource-id')
                expect(director).to receive(:download_resource).with('resource-id').and_return('/wonderful/path')
                expect(FileUtils).to receive(:mv).with('/wonderful/path', "#{Dir.pwd}/#{job}.0.#{time}.tgz")
                command.fetch_logs(job)
              end
            end
          end

          context 'when we do not specify the job index and it is not' do
            let(:manifest) do
              {
                'name' => deployment,
                'uuid' => 'totally-and-universally-unique',
                'jobs' => [{
                  'name' => 'dea',
                  'instances' => 52735
                }]
              }
            end

            it 'complains' do
              expect {
                command.fetch_logs(job)
              }.to raise_error(Bosh::Cli::CliError, 'You should specify the job index. There is more than one instance of this job type.')
            end
          end
        end
      end
    end
  end
end
