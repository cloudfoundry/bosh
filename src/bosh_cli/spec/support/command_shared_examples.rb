require 'spec_helper'

module CommandTargetSharedExamples
  def with_target
    before { allow(command).to receive(:target).and_return('fake-target') }
  end

  def it_requires_target(runnable)
    context 'when user did not target director' do
      before { allow(command).to receive(:target).and_return(nil) }

      it 'raises an error with required target message' do
        expect {
          runnable.call(command)
        }.to raise_error(Bosh::Cli::CliError, 'Please choose target first')
      end
    end
  end
end

module CommandLoggedInUserSharedExamples
  def with_logged_in_user
    before { allow(command).to receive(:logged_in?).and_return(true) }
    before { allow(command).to receive(:show_current_state) }
  end

  def it_requires_logged_in_user(runnable)
    context 'when user is not logged in' do
      before { allow(command).to receive(:logged_in?).and_return(false) }
      before { command.options[:target] = 'http://bosh-target.example.com' }

      it 'requires that the user is logged in' do
        expect {
          runnable.call(command)
        }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
      end
    end
  end
end

module CommandDeploymentSharedExamples
  def with_deployment
    before { allow(command).to receive(:deployment).and_return('/fake-manifest-path') }
  end

  def it_requires_deployment(runnable)
    context 'when user did not choose deployment' do
      before { allow(command).to receive(:deployment).and_return(nil) }

      it 'raises an error with choose deployment message' do
        expect {
          runnable.call(command)
        }.to raise_error(Bosh::Cli::CliError, 'Please choose deployment first')
      end
    end
  end
end

module CommandDirectorSharedExamples
  def with_director
    before { allow(command).to receive(:director).and_return(director) }
    let(:director) { instance_double('Bosh::Cli::Client::Director') }
  end
end

RSpec.configure do |config|
  config.extend(CommandTargetSharedExamples)
  config.extend(CommandLoggedInUserSharedExamples)
  config.extend(CommandDeploymentSharedExamples)
  config.extend(CommandDirectorSharedExamples)
end
