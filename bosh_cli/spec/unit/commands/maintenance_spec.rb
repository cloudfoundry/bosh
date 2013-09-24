require 'spec_helper'

describe Bosh::Cli::Command::Maintenance do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Client::Director) }

  before do
    command.stub(:director).and_return(director)
    command.options[:non_interactive] = true
    command.options[:username] = 'admin'
    command.options[:password] = 'admin'
    command.options[:target] = 'http://example.org'

    director.stub(list_stemcells: [])
  end

  context 'old releases format' do
    let(:release) do
      {
          'name' => 'release-1',
          'versions' => ['2.1-dev', '15', '2', '1'],
          'in_use' => ['2.1-dev']
      }
    end

    it 'should cleanup releases' do
      director.stub(list_releases: [release])

      director.should_receive(:delete_release).
          with('release-1', force: false, version: '1', quiet: true).
          and_return([:done, 1])
      director.should_receive(:delete_release).
          with('release-1', force: false, version: '2', quiet: true).
          and_return([:done, 2])

      command.cleanup
    end
  end


  context 'new releases format' do
    let(:release) do
      {
          'name' => 'release-1',
          'release_versions' => [
              {'version' => '2.1-dev', 'commit_hash' => 'unknown', 'uncommitted_changes' => false, 'currently_deployed' => true},
              {'version' => '15', 'commit_hash' => '1a2b3c4d', 'uncommitted_changes' => true, 'currently_deployed' => false},
              {'version' => '2', 'commit_hash' => '00000000', 'uncommitted_changes' => true, 'currently_deployed' => false},
              {'version' => '1', 'commit_hash' => 'unknown', 'uncommitted_changes' => false, 'currently_deployed' => false}
          ]
      }
    end

    it 'should cleanup releases' do
      director.stub(list_releases: [release])

      director.should_receive(:delete_release).
          with('release-1', force: false, version: '1', quiet: true).
          and_return([:done, 1])
      director.should_receive(:delete_release).
          with('release-1', force: false, version: '2', quiet: true).
          and_return([:done, 2])

      command.cleanup
    end
  end

end
