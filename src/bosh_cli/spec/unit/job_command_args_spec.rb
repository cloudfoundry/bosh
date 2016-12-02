require 'spec_helper'

describe Bosh::Cli::JobCommandArgs do
  subject(:job_command_args) { described_class.new(args) }

  context 'when id is provided' do
    context 'when id is separated by slash in job name' do
      let(:args) { ['fake-job/abc-edf'] }

      it 'does not have id' do
        expect(job_command_args.id).to eq('abc-edf')
      end
    end

    context 'when id is another argument' do
      let(:args) { ['fake-job', 'abc-edf'] }

      it 'does not have id' do
        expect(job_command_args.id).to eq('abc-edf')
      end
    end
  end

  context 'when id is not provided' do
    let(:args) { ['fake-job'] }

    it 'does not have id' do
      expect(job_command_args.id).to be_nil
    end
  end
end
