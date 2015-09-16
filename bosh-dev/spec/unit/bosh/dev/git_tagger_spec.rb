require 'spec_helper'
require 'bosh/dev/git_tagger'

module Bosh::Dev
  describe GitTagger do
    subject(:git_tagger) { described_class.new(logger) }

    describe '#tag_and_push' do
      let(:sha)            { 'fake-sha' }
      let(:build_number)   { 'fake-build-id' }

      before { allow(Open3).to receive(:capture3).and_return(success) }
      let(:success) { [nil, nil, instance_double('Process::Status', success?: true)] }

      context 'when tagging and pushing succeeds' do
        it 'tags stable_branch with jenkins build number' do
          tag_name = 'stable-fake-build-id'
          expect(Open3).to receive(:capture3).with("git tag -a #{tag_name} -m ci-tagged #{sha}").and_return(success)
          git_tagger.tag_and_push(sha, build_number)
        end

        it 'pushes tags' do
          expect(Open3).to receive(:capture3).with('git push origin --tags').and_return(success)
          git_tagger.tag_and_push(sha, build_number)
        end
      end

      context 'when tagging fails' do
        before { allow(Open3).to receive(:capture3).and_return(fail) }
        let(:fail) { [nil, nil, instance_double('Process::Status', success?: false)] }

        it 'raises an error' do
          expect {
            git_tagger.tag_and_push(sha, build_number)
          }.to raise_error(/Failed to tag/)
        end
      end

      context 'when pushing fails' do
        before { allow(Open3).to receive(:capture3).and_return(success, fail) }
        let(:fail) { [nil, nil, instance_double('Process::Status', success?: false)] }

        it 'raises an error' do
          expect {
            git_tagger.tag_and_push(sha, build_number)
          }.to raise_error(/Failed to push tags/)
        end
      end

      [nil, ''].each do |invalid|
        context "when sha is #{invalid.inspect}" do
          let(:sha) { invalid }

          it 'raises an error' do
            expect {
              git_tagger.tag_and_push(sha, build_number)
            }.to raise_error(ArgumentError, 'sha is required')
          end

          it 'does not execute any git commands' do
            expect(Open3).to_not receive(:capture3)
            expect { git_tagger.tag_and_push(sha, build_number) }.to raise_error
          end
        end
      end

      [nil, ''].each do |invalid|
        context "when build_number is #{invalid.inspect}" do
          let(:build_number) { invalid }

          it 'raises an error' do
            expect {
              git_tagger.tag_and_push(sha, build_number)
            }.to raise_error(ArgumentError, 'build_number is required')
          end

          it 'does not execute any git commands' do
            expect(Open3).not_to receive(:capture3)
            expect { git_tagger.tag_and_push(sha, build_number) }.to raise_error
          end
        end
      end
    end

    describe '#stable_tag_for?' do
      let(:commit_sha) { 'some-subjected-sha' }

      before do
        allow(Open3).to receive(:capture3).with('git fetch --tags').and_return(
          [ '', nil, instance_double('Process::Status', success?: true) ]
        )
      end

      it 'returns true when there is a stable tag for the given sha' do
        expect(Open3).to receive(:capture3).with("git tag --contains #{commit_sha}").and_return(
          [ 'stable-123', nil, instance_double('Process::Status', success?: true) ]
        )

        expect(git_tagger.stable_tag_for?(commit_sha)).to eq(true)
      end

      it 'returns false when there is not a stable tag for the given sha' do
        expect(Open3).to receive(:capture3).with("git tag --contains #{commit_sha}").and_return(
          [ '', nil, instance_double('Process::Status', success?: true) ]
        )

        expect(git_tagger.stable_tag_for?(commit_sha)).to eq(false)
      end
    end

    describe '#tag_sha' do
      let(:tag_name) { 'fake-tag-name' }
      let(:tag_sha) { 'fake-tag-sha' }

      it 'returns the sha when there is a tag with the given name' do
        expect(Open3).to receive(:capture3).with('git fetch --tags').and_return(
          [ '', nil, instance_double('Process::Status', success?: true) ]
        )

        expect(Open3).to receive(:capture3).with("git rev-parse #{tag_name}^{}").and_return(
          [ tag_sha, nil, instance_double('Process::Status', success?: true) ]
        )

        expect(git_tagger.tag_sha(tag_name)).to eq(tag_sha)
      end

      it 'errors when there is not a tag with the given name' do
        expect(Open3).to receive(:capture3).with('git fetch --tags').and_return(
          [ '', nil, instance_double('Process::Status', success?: true) ]
        )

        expect(Open3).to receive(:capture3).with("git rev-parse #{tag_name}^{}").and_return(
          [ 'fake-error', nil, instance_double('Process::Status', success?: false) ]
        )

        expect{ git_tagger.tag_sha(tag_name) }.to raise_error(/fake-error/)
      end
    end

    describe '#stable_tag_name' do
      it 'prepends stable to the build number' do
        expect(git_tagger.stable_tag_name('63')).to eq('stable-63')
      end
    end
  end
end
