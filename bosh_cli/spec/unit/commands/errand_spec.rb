require 'spec_helper'
require 'cli'
require 'cli/client/errands_client'

describe Bosh::Cli::Command::Errand do
  subject(:command) { described_class.new }

  ec = Bosh::Cli::Client::ErrandsClient

  describe 'errands' do
    def perform; command.errands; end

    with_director

    context 'when some director is targeted' do
      with_target

      context 'when user is logged in' do
        with_logged_in_user

        context 'when deployment is selected' do
          with_deployment

          before { allow(command).to receive(:prepare_deployment_manifest).and_return(double(:manifest, name: 'fake-deployment')) }

          it 'shows errands in a table' do
            expect(director).to receive(:list_errands).and_return([{"name" => "an-errand"}, {"name" => "another-errand"}])
            perform
            expect(command.exit_code).to eq(0)
          end

          it 'errors if no errands in manifest' do
            expect(director).to receive(:list_errands).and_return([])
            expect {
              perform
            }.to raise_error(Bosh::Cli::CliError, 'Deployment has no available errands')
          end
        end
      end
    end
  end

  describe 'run errand NAME' do
    def perform; command.run_errand('fake-errand-name'); end

    with_director

    before { allow(Bosh::Cli::Client::ErrandsClient).to receive(:new).with(director).and_return(errands_client) }
    let(:errands_client) { instance_double('Bosh::Cli::Client::ErrandsClient') }

    context 'when some director is targeted' do
      with_target

      context 'when user is logged in' do
        with_logged_in_user

        context 'when deployment is selected' do
          with_deployment

          let(:errand_result) { ec::ErrandResult.new(0, 'fake-stdout', 'fake-stderr', nil) }

          before do
            allow(command).to receive(:prepare_deployment_manifest).
              with(show_state: true).and_return(double(:manifest, name: 'fake-dep-name'))
          end

          before do
            allow(Bosh::Cli::LogsDownloader).to receive(:new).
              with(director, command).
              and_return(logs_downloader)
          end
          let(:logs_downloader) { instance_double('Bosh::Cli::LogsDownloader', build_destination_path: nil) }

          it 'tells director to start running errand with given name on given instance' do
            expect(errands_client).to receive(:run_errand).
              with('fake-dep-name', 'fake-errand-name', FALSE).
              and_return([:done, 'fake-task-id', errand_result])
            perform
          end

          context 'when errand is run with keep-alive option' do
            before { command.options[:keep_alive] = true }

            it 'tells the director to not delete/stop the instance' do
              expect(errands_client).to receive(:run_errand).
                with('fake-dep-name', 'fake-errand-name', TRUE).
                and_return([:done, 'fake-task-id', errand_result])
              perform
            end
          end

          context 'when errand director task finishes successfully' do
            before do
              allow(errands_client).to receive(:run_errand).
                and_return([:done, 'fake-task-id', errand_result])
            end

            context 'when errand finished with 0 exit code' do
              let(:errand_result) { ec::ErrandResult.new(0, 'fake-stdout', 'fake-stderr', nil) }

              it 'exits with exit code 0' do
                perform
                expect(command.exit_code).to eq(0)
              end

              it 'does not raise an error' do
                perform
                expect_output(<<-TEXT)

                  [stdout]
                  fake-stdout

                  [stderr]
                  fake-stderr

                  Errand `fake-errand-name' completed successfully (exit code 0)
                TEXT
              end
            end

            context 'when errand finished with non-0 exit code' do
              let(:errand_result) { ec::ErrandResult.new(123, 'fake-stdout', 'fake-stderr', nil) }

              it 'raises an error and prints output' do
                expect {
                  perform
                }.to raise_error(
                  Bosh::Cli::CliError,
                  /Errand `fake-errand-name' completed with error \(exit code 123\)/,
                )

                expect_output(<<-TEXT)

                  [stdout]
                  fake-stdout

                  [stderr]
                  fake-stderr

                TEXT
              end
            end

            context 'when errand finished with >128 exit code' do
              let(:errand_result) { ec::ErrandResult.new(143, 'fake-stdout', 'fake-stderr', nil) }

              it 'raises an error and prints output' do
                expect {
                  perform
                }.to raise_error(
                  Bosh::Cli::CliError,
                  /Errand `fake-errand-name' was canceled \(exit code 143\)/,
                )

                expect_output(<<-TEXT)

                  [stdout]
                  fake-stdout

                  [stderr]
                  fake-stderr

                TEXT
              end
            end

            context 'when errand has stdout and stderr' do
              let(:errand_result) { ec::ErrandResult.new(0, 'fake-stdout', 'fake-stderr', nil) }

              it 'prints actual output for stdout and stderr' do
                perform
                expect_output(<<-TEXT)

                  [stdout]
                  fake-stdout

                  [stderr]
                  fake-stderr

                  Errand `fake-errand-name' completed successfully (exit code 0)
                TEXT
              end
            end

            context 'when errand has stdout and no stderr' do
              let(:errand_result) { ec::ErrandResult.new(0, 'fake-stdout', '', nil) }

              it 'prints None for both stderr and actual output for stdout' do
                perform
                expect_output(<<-TEXT)

                  [stdout]
                  fake-stdout

                  [stderr]
                  None

                  Errand `fake-errand-name' completed successfully (exit code 0)
                TEXT
              end
            end

            context 'when errand has stderr and no stdout' do
              let(:errand_result) { ec::ErrandResult.new(0, '', 'fake-stderr', nil) }

              it 'prints None for both stdout and actual output for stderr' do
                perform
                expect_output(<<-TEXT)

                  [stdout]
                  None

                  [stderr]
                  fake-stderr

                  Errand `fake-errand-name' completed successfully (exit code 0)
                TEXT
              end
            end

            context 'when errand has no stderr and no stdout' do
              let(:errand_result) { ec::ErrandResult.new(0, '', '', nil) }

              it 'prints None for both stdout and stderr' do
                perform
                expect_output(<<-TEXT)

                  [stdout]
                  None

                  [stderr]
                  None

                  Errand `fake-errand-name' completed successfully (exit code 0)
                TEXT
              end
            end

            context 'when errand result includes logs blobstore id' do
              let(:errand_result) { ec::ErrandResult.new(0, 'fake-stdout', 'fake-stderr', 'fake-logs-blobstore-id') }

              context 'when --download-logs option is set' do
                before { command.options[:download_logs] = true }

                it 'downloads the file and moves it to a timestamped file in a current directory' do
                  expect(logs_downloader).to receive(:build_destination_path).
                    with('fake-errand-name', 0, Dir.pwd).
                    and_return('fake-logs-destination-path')

                  expect(logs_downloader).to receive(:download).
                    with('fake-logs-blobstore-id', 'fake-logs-destination-path')

                  perform
                end

                it 'downloads the file and moves it to a timestamped file in a desired directory' do
                  command.options[:logs_dir] = '/fake-path'

                  expect(logs_downloader).to receive(:build_destination_path).
                    with('fake-errand-name', 0, '/fake-path').
                    and_return('fake-logs-destination-path')

                  expect(logs_downloader).to receive(:download).
                    with('fake-logs-blobstore-id', 'fake-logs-destination-path')

                  perform
                end

                context 'when errand logs are downloaded successfully' do
                  it 'shows downloaded logs tarball path' do
                    expect(logs_downloader).to receive(:download) do
                      command.say('fake-download-output')
                    end

                    perform
                    expect_output(<<-TEXT)

                      [stdout]
                      fake-stdout

                      [stderr]
                      fake-stderr

                      fake-download-output
                      Errand `fake-errand-name' completed successfully (exit code 0)
                    TEXT
                  end
                end

                context 'when errand logs are not downloaded successfully' do
                  before { allow(logs_downloader).to receive(:download).and_raise(error) }
                  let(:error) { Bosh::Cli::CliError.new('fake-error') }

                  context 'when errand finished with 0 exit code' do
                    it 'raises fetch logs download error' do
                      expect { perform }.to raise_error(error)

                      expect_output(<<-TEXT)

                        [stdout]
                        fake-stdout

                        [stderr]
                        fake-stderr

                        Errand `fake-errand-name' completed successfully (exit code 0)
                      TEXT
                    end
                  end

                  context 'when errand finished with non-0 exit code' do
                    let(:errand_result) { ec::ErrandResult.new(123, 'fake-stdout', 'fake-stderr', 'fake-logs-blobstore-id') }

                    it 'raises an error regarding errand exit code and prints output' do
                      expect {
                        perform
                      }.to raise_error(
                        Bosh::Cli::CliError,
                        /Errand `fake-errand-name' completed with error \(exit code 123\)/,
                      )

                      expect_output(<<-TEXT)

                        [stdout]
                        fake-stdout

                        [stderr]
                        fake-stderr

                      TEXT
                    end
                  end

                  context 'when errand finished with >128 exit code' do
                    let(:errand_result) { ec::ErrandResult.new(143, 'fake-stdout', 'fake-stderr', 'fake-logs-blobstore-id') }

                    it 'raises an error regarding errand exit code and prints output' do
                      expect {
                        perform
                      }.to raise_error(
                        Bosh::Cli::CliError,
                        /Errand `fake-errand-name' was canceled \(exit code 143\)/,
                      )

                      expect_output(<<-TEXT)

                        [stdout]
                        fake-stdout

                        [stderr]
                        fake-stderr

                      TEXT
                    end
                  end
                end
              end

              context 'when --download-logs option is not set' do
                it 'does not try to download errand logs' do
                  expect(logs_downloader).to_not receive(:download)
                  perform
                end
              end
            end

            context 'when errand result does not include logs blobstore id' do
              let(:errand_result) { ec::ErrandResult.new(0, 'fake-stdout', 'fake-stderr', nil) }

              it 'does not try to download errand logs' do
                expect(logs_downloader).to_not receive(:download)
                perform
              end
            end
          end

          context 'when errand task does not finish successfully' do
            before { allow(errands_client).to receive(:run_errand).and_return([:error, 'fake-task-id', nil]) }

            it 'reports task information to the user' do
              perform
              expect_output(<<-TEXT)

                Errand `fake-errand-name' did not complete

                For a more detailed error report, run: bosh task fake-task-id --debug
              TEXT
            end

            it 'exits with exit code 1' do
              perform
              expect(command.exit_code).to eq(1)
            end
          end
        end

        it_requires_deployment ->(command) { command.run_errand(nil) }
      end

      it_requires_logged_in_user ->(command) { command.run_errand(nil) }
    end

    it_requires_target ->(command) { command.run_errand(nil) }
  end

  describe 'run errand' do
    def perform; command.run_errand; end

    with_director
    with_target
    with_logged_in_user
    with_deployment

    it 'with 0 errands raise error' do
      allow(command).to receive(:prepare_deployment_manifest).and_return(double(:manifest, name: 'fake-deployment'))
      expect(director).to receive(:list_errands).and_return([])

      expect {
        perform
      }.to raise_error(Bosh::Cli::CliError, 'Deployment has no available errands')
    end

    it 'with 1 errand, prompts and invokes run_errand(name)' do
      expect(command).to receive(:perform_run_errand).with('an-errand')
      expect(command).to receive(:choose).and_return({'name' => 'an-errand'})
      allow(command).to receive(:prepare_deployment_manifest).and_return(double(:manifest, name: 'fake-deployment'))
      expect(director).to receive(:list_errands).and_return([{"name" => "an-errand"}])

      perform
    end

    it 'with 2+ errands, prompts and invokes run_errand(name)' do
      expect(command).to receive(:perform_run_errand).with('another-errand')
      expect(command).to receive(:choose).and_return({'name' => 'another-errand'})
      allow(command).to receive(:prepare_deployment_manifest).and_return(double(:manifest, name: 'fake-deployment'))
      expect(director).to receive(:list_errands).and_return([{"name" => "an-errand"}, {"name" => "another-errand"}])
      perform
    end
  end

  def expect_output(expected_output)
    actual = Bosh::Cli::Config.output.string
    indent = expected_output.scan(/^[ \t]*(?=\S)/).min.size || 0
    expect(actual).to eq(expected_output.gsub(/^[ \t]{#{indent}}/, ''))
  end
end
