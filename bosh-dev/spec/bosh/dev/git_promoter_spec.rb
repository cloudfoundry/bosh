require 'spec_helper'
require 'bosh/dev/git_promoter'

module Bosh
  module Dev
    describe GitPromoter do
      subject(:git_promoter) { GitPromoter.new }
      let(:success) { ['', '', instance_double('Process::Status', success?: true)] }
      let(:error) { ['some output', 'a little error', instance_double('Process::Status', success?: false)] }

      before do
        Open3.stub(:capture3)
      end

      it 'promotes local dev_branch to remote stable_branch' do
        Open3.should_receive(:capture3).with('git', 'push', 'origin', 'my_branch:your_branch').and_return(success)
        git_promoter.promote('my_branch', 'your_branch')
      end

      context 'when dev_branch is nil' do
        it 'raises' do
          Open3.should_not_receive(:capture3)
          expect {
            git_promoter.promote(nil, 'stable')
          }.to raise_error('dev_branch is required')
        end
      end

      context 'when dev_branch is empty' do
        it 'raises' do
          Open3.should_not_receive(:capture3)
          expect {
            git_promoter.promote('', 'stable')
          }.to raise_error('dev_branch is required')
        end
      end

      context 'when stable_branch is nil' do
        it 'raises' do
          Open3.should_not_receive(:capture3)
          expect {
            git_promoter.promote('unstable', nil)
          }.to raise_error('stable_branch is required')
        end
      end

      context 'when stable_branch is empty' do
        it 'raises' do
          Open3.should_not_receive(:capture3)
          expect {
            git_promoter.promote('unstable', '')
          }.to raise_error('stable_branch is required')
        end
      end

      context 'when the command fails' do
        it 'raises' do
          Open3.should_receive(:capture3).and_return(error)
          expect {
            git_promoter.promote('my_branch', 'your_branch')
          }.to raise_error("Failed to git push local my_branch to origin your_branch: stdout: 'some output', stderr: 'a little error'")
        end
      end

    end
  end
end