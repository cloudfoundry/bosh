require 'spec_helper'

module Bosh::Cli::Command::Release
  describe ListReleases do
    subject(:command) { described_class.new }

    let(:director) do
      instance_double(
        'Bosh::Cli::Client::Director',
        get_status: { 'version' => '1.2580.0' }
      )
    end

    before do
      allow(command).to receive(:director).and_return(director)
      allow(command).to receive(:show_current_state)
    end

    describe '#list' do
      let(:releases) do
        [
          {
            'name' => 'bosh-release',
            'release_versions' => [
              {
                'version' => '0+dev.3',
                'commit_hash' => 'fake-hash-3',
                'currently_deployed' => false,
                'uncommitted_changes' => true
              },
              {
                'version' => '0+dev.2',
                'commit_hash' => 'fake-hash-2',
                'currently_deployed' => true,
              },
              {
                'version' => '0+dev.1',
                'commit_hash' => 'fake-hash-1',
                'currently_deployed' => false,
              }
            ],
          }
        ]
      end

      before do
        allow(command).to receive(:logged_in?).and_return(true)
        command.options[:target] = 'http://bosh-target.example.com'
        allow(director).to receive(:list_releases).and_return(releases)
      end

      it 'lists all releases' do
        command.list
        expect_output(<<-OUT)

        +--------------+----------+--------------+
        | Name         | Versions | Commit Hash  |
        +--------------+----------+--------------+
        | bosh-release | 0+dev.1  | fake-hash-1  |
        |              | 0+dev.2* | fake-hash-2  |
        |              | 0+dev.3  | fake-hash-3+ |
        +--------------+----------+--------------+
        (*) Currently deployed
        (+) Uncommitted changes

        Releases total: 1
        OUT
      end

      context 'when there is a deployed release' do
        let(:releases) do
          [
            {
              'name' => 'bosh-release',
              'release_versions' => [
                {
                  'version' => '0+dev.3',
                  'commit_hash' => 'fake-hash-3',
                  'currently_deployed' => true,
                  'uncommitted_changes' => false
                }
              ],
            }
          ]
        end

        it 'prints Currently deployed' do
          command.list
          expect_output(<<-OUT)

          +--------------+----------+-------------+
          | Name         | Versions | Commit Hash |
          +--------------+----------+-------------+
          | bosh-release | 0+dev.3* | fake-hash-3 |
          +--------------+----------+-------------+
          (*) Currently deployed

          Releases total: 1
          OUT
        end
      end

      context 'when there are releases with uncommited changes' do
        let(:releases) do
          [
            {
              'name' => 'bosh-release',
              'release_versions' => [
                {
                  'version' => '0+dev.3',
                  'commit_hash' => 'fake-hash-3',
                  'currently_deployed' => false,
                  'uncommitted_changes' => true
                }
              ],
            }
          ]
        end

        it 'prints Uncommited changes' do
          command.list
          expect_output(<<-OUT)

          +--------------+----------+--------------+
          | Name         | Versions | Commit Hash  |
          +--------------+----------+--------------+
          | bosh-release | 0+dev.3  | fake-hash-3+ |
          +--------------+----------+--------------+
          (+) Uncommitted changes

          Releases total: 1
          OUT
        end
      end

      context 'when there are releases with unknown version' do
        let(:releases) do
          [
            {
              'name' => 'bosh-release',
              'release_versions' => []
            }
          ]
        end

        it 'prints Uncommited changes' do
          command.list
          expect_output(<<-OUT)

          +--------------+----------+-------------+
          | Name         | Versions | Commit Hash |
          +--------------+----------+-------------+
          | bosh-release | unknown  | unknown     |
          +--------------+----------+-------------+

          Releases total: 1
          OUT
        end
      end      
    end

    def expect_output(expected_output)
      actual = Bosh::Cli::Config.output.string
      indent = expected_output.scan(/^[ \t]*(?=\S)/).min.size || 0
      expect(actual).to eq(expected_output.gsub(/^[ \t]{#{indent}}/, ''))
    end
  end
end
