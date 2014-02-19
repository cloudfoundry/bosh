require 'spec_helper'

module CommandSharedExamples
  def it_requires_logged_in_user(runnable)
    context 'when user is not logged in' do
      before { command.stub(:logged_in? => false) }
      before { command.options[:target] = 'http://bosh-target.example.com' }

      it 'requires that the user is logged in' do
        expect {
          runnable.call(command)
        }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
      end
    end
  end
end

RSpec.configure do |config|
  config.extend(CommandSharedExamples)
end
