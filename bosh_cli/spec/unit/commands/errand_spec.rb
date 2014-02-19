require 'spec_helper'
require 'cli'
require 'cli/client/errands_client'

describe Bosh::Cli::Command::Errand do
  subject(:command) { described_class.new }

  before { command.stub(director: director) }
  let(:director) { instance_double('Bosh::Cli::Client::Director') }

  describe 'run errand' do
    before { allow(Bosh::Cli::Client::ErrandsClient).to receive(:new).with(director).and_return(errands_client) }
    let(:errands_client) { instance_double('Bosh::Cli::Client::ErrandsClient') }

    context 'when user is logged in' do
      before { allow(command).to receive(:logged_in?).and_return(true) }

      context 'when deployment is selected' do
        before { allow(command).to receive(:deployment).and_return('/fake-manifest-path') }
        before { allow(command).to receive(:prepare_deployment_manifest).with(no_args).and_return('name' => 'fake-dep-name') }

        context 'when errand name is given' do
          def perform; command.run_errand('fake-errand-name'); end
          let(:errand_result) { Bosh::Cli::Client::ErrandsClient::ErrandResult.new(0, 'fake-stdout', 'fake-stderr') }

          it 'tells director to start running errand with given name on given instance' do
            expect(errands_client).to receive(:run_errand).
              with('fake-dep-name', 'fake-errand-name').
              and_return([:done, 'fake-task-id', errand_result])
            perform
          end

          context 'when errand director task finishes successfully' do
            before { allow(errands_client).to receive(:run_errand).and_return([:done, 'fake-task-id', errand_result]) }

            context 'when errand finished with 0 exit code' do
              let(:errand_result) { Bosh::Cli::Client::ErrandsClient::ErrandResult.new(0, 'fake-stdout', 'fake-stderr') }

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
              let(:errand_result) { Bosh::Cli::Client::ErrandsClient::ErrandResult.new(123, 'fake-stdout', 'fake-stderr') }

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

            context 'when errand has stdout and stderr' do
              let(:errand_result) { Bosh::Cli::Client::ErrandsClient::ErrandResult.new(0, 'fake-stdout', 'fake-stderr') }

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
              let(:errand_result) { Bosh::Cli::Client::ErrandsClient::ErrandResult.new(0, 'fake-stdout', '') }

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
              let(:errand_result) { Bosh::Cli::Client::ErrandsClient::ErrandResult.new(0, '', 'fake-stderr') }

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
              let(:errand_result) { Bosh::Cli::Client::ErrandsClient::ErrandResult.new(0, '', '') }

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
      end

      context 'when deployment is not selected' do
        before { allow(command).to receive(:deployment).and_return(nil) }

        it 'raises an CliError that says to choose a deployment' do
          expect {
            command.run_errand(nil)
          }.to raise_error(Bosh::Cli::CliError, /Please choose deployment first/)
        end
      end
    end

    it_requires_logged_in_user ->(command) { command.run_errand(nil) }
  end

  def expect_output(expected_output)
    actual = Bosh::Cli::Config.output.string
    indent = expected_output.scan(/^[ \t]*(?=\S)/).min.size || 0
    expect(actual).to eq(expected_output.gsub(/^[ \t]{#{indent}}/, ''))
  end
end
