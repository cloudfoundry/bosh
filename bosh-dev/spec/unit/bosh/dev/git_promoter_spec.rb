require 'spec_helper'
require 'bosh/dev/git_promoter'

module Bosh::Dev
  describe GitPromoter do
    describe '#promote' do
      subject(:git_promoter) { described_class.new(logger) }

      before { allow(Open3).to receive(:capture3) }

      context 'when promoting suceeds' do
        it 'promotes local commit_sha to remote stable_branch' do
          commit_sha = 'my_branch'
          stable_branch = 'your_branch'
          expect(Open3).to receive(:capture3).with("git push origin #{commit_sha}:#{stable_branch}").
            and_return([ nil, nil, instance_double('Process::Status', success?: true) ])

          git_promoter.promote(commit_sha, stable_branch)
        end
      end

      context 'when the command fails' do
        let(:error) { ['stdout', 'stderr', instance_double('Process::Status', success?: false)] }

        it 'raises an error' do
          expect(Open3).to receive(:capture3).and_return(error)
          expect {
            git_promoter.promote('my_branch', 'your_branch')
          }.to raise_error("Failed to git push local my_branch to origin your_branch: stdout: 'stdout', stderr: 'stderr'")
        end
      end

      [nil, ''].each do |invalid|
        context "when commit_sha is #{invalid}" do
          it 'raises an error' do
            expect {
              git_promoter.promote(invalid, 'stable')
            }.to raise_error('commit_sha is required')
          end

          it 'does not execute any git commands' do
            expect(Open3).to_not receive(:capture3)
            expect { git_promoter.promote(invalid, 'stable') }.to raise_error
          end
        end
      end

      [nil, ''].each do |invalid|
        context "when stable_branch is #{invalid}" do
          it 'raises an error' do
            expect {
              git_promoter.promote('unstable', invalid)
            }.to raise_error(ArgumentError, 'stable_branch is required')
          end

          it 'does not execute any git commands' do
            expect(Open3).to_not receive(:capture3)
            expect { git_promoter.promote('unstable', invalid) }.to raise_error
          end
        end
      end
    end
  end
end
