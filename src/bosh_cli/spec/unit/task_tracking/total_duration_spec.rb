require 'spec_helper'

describe Bosh::Cli::TaskTracking::TotalDuration do
  describe '#started_at=' do
    context 'when started at is not set' do
      context 'when time is parseable' do
        it 'sets started at' do
          expect {
            subject.started_at = 1386918001
          }.to change { subject.started_at }.from(nil).to(Time.at(1386918001))
        end
      end

      context 'when time is not parseable' do
        it 'keeps started at as nil' do
          expect {
            subject.started_at = 'invalid-time'
          }.to_not change { subject.started_at }.from(nil)
        end
      end
    end

    context 'when started at is already set' do
      before { subject.started_at = 1386918001 }

      context 'when time is parseable' do
        it 'does not change previously set started at' do
          expect {
            subject.started_at = 1999999999
          }.to_not change { subject.started_at }.from(Time.at(1386918001))
        end
      end

      context 'when time is not parseable' do
        it 'does not change previously set started at' do
          expect {
            subject.started_at = 'invalid-time'
          }.to_not change { subject.started_at }.from(Time.at(1386918001))
        end
      end
    end
  end

  describe '#finished_at=' do
    context 'when finished at is not set' do
      context 'when time is parseable' do
        it 'sets finished at' do
          expect {
            subject.finished_at = 1386918001
          }.to change { subject.finished_at }.from(nil).to(Time.at(1386918001))
        end
      end

      context 'when time is not parseable' do
        it 'keeps finished at as nil' do
          expect {
            subject.finished_at = 'invalid-time'
          }.to_not change { subject.finished_at }.from(nil)
        end
      end
    end

    context 'when finished at is already set' do
      before { subject.finished_at = 1386918001 }

      context 'when time is parseable' do
        it 'changes previously set finished at' do
          expect {
            subject.finished_at = 1999999999
          }.to change { subject.finished_at }.from(Time.at(1386918001)).to(Time.at(1999999999))
        end
      end

      context 'when time is not parseable' do
        it 'does not change previously set finished at' do
          expect {
            subject.finished_at = 'invalid-time'
          }.to_not change { subject.finished_at }.from(Time.at(1386918001))
        end
      end
    end
  end

  describe '#duration/duration_known?' do
    it 'returns nil by default' do
      expect(subject.duration).to eq(nil)
      expect(subject.duration_known?).to be(false)
    end

    context 'when started at is not nil' do
      before { subject.started_at = 1386918001 }

      context 'when finished at is not nil' do
        it 'returns duration' do
          subject.finished_at = 1386918002
          expect(subject.duration).to eq(1)
          expect(subject.duration_known?).to be(true)
        end
      end

      context 'when finished at is nil' do
        it 'returns nil' do
          subject.finished_at = nil
          expect(subject.duration).to eq(nil)
          expect(subject.duration_known?).to be(false)
        end
      end
    end

    context 'when started at is nil' do
      before { subject.started_at = nil }

      context 'when finished at is not nil' do
        it 'returns nil' do
          subject.finished_at = 1386918002
          expect(subject.duration).to eq(nil)
          expect(subject.duration_known?).to be(false)
        end
      end

      context 'when finished at is nil' do
        it 'returns nil' do
          subject.finished_at = nil
          expect(subject.duration).to eq(nil)
          expect(subject.duration_known?).to be(false)
        end
      end
    end
  end
end
