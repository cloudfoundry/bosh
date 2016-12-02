require 'spec_helper'

module Bosh::Cli::Command::Release
  describe InspectRelease do
    subject(:command) { described_class.new }

    describe 'inspect release' do
      with_director
      with_target
      with_logged_in_user

      it 'should raise an error when the response looks like it is from an old director' do
        allow(director).to receive(:inspect_release).and_return({
                                                                    'jobs' => [],
                                                                    'packages' => [],
                                                                    'versions' => [],
                                                                })
        expect { command.inspect('foo/123') }.to raise_error(Bosh::Cli::DirectorError,
                                                             'Response from director does not include expected information. Is your director version 1.3034.0 or newer?')
      end
    end
  end
end