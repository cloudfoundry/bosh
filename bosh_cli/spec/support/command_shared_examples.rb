require 'spec_helper'

shared_examples_for 'a command which requires user is logged in' do |runnable|
  context 'when user is not logged in' do
    before do
      command.stub(:logged_in? => false)
      command.options[:target] = 'http://bosh-target.example.com'
    end

    it 'requires that the user is logged in' do
      expect { runnable.call(command) }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
    end
  end
end