require 'spec_helper'

module Bosh::Director
  describe Jobs::ScheduledMetricsCleanup do
    subject { described_class.new(*params) }
    let(:params) do
      [{
        'retention_days' => retention_days,
      }]
    end
    let(:retention_days) { 7 }
    let(:metrics_dir) { Dir.mktmpdir }
    let(:time) { Time.now }
    let(:seven_days_seconds) { 7 * 24 * 60 * 60 }
    let(:eight_days_ago) { time - seven_days_seconds - 86400 }
    let(:six_days_ago) { time - seven_days_seconds + 86400 }

    before do
      allow(Config).to receive(:metrics_dir).and_return(metrics_dir)
      allow(Time).to receive(:now).and_return(time)
    end

    after do
      FileUtils.rm_rf(metrics_dir) if File.directory?(metrics_dir)
    end

    describe '.job_type' do
      it 'returns the job type' do
        expect(described_class.job_type).to eq(:scheduled_metrics_cleanup)
      end
    end

    describe '.schedule_message' do
      it 'outputs a message' do
        expect(described_class.schedule_message).to eq('clean up stale metrics files')
      end
    end

    describe '.time_days_ago' do
      it 'calculates time correctly' do
        expect(described_class.time_days_ago(7)).to eq(time - seven_days_seconds)
      end
    end

    describe '.has_work' do
      context 'when retention_days is 0' do
        let(:retention_days) { 0 }

        it 'returns false' do
          expect(described_class.has_work(params)).to eq(false)
        end
      end

      context 'when metrics directory does not exist' do
        before do
          FileUtils.rm_rf(metrics_dir)
        end

        it 'returns false' do
          expect(described_class.has_work(params)).to eq(false)
        end
      end

      context 'when there are stale files' do
        before do
          old_file = File.join(metrics_dir, 'metric_old.bin')
          File.write(old_file, 'data')
          File.utime(eight_days_ago, eight_days_ago, old_file)
        end

        it 'returns true' do
          expect(described_class.has_work(params)).to eq(true)
        end
      end

      context 'when there are no stale files' do
        before do
          recent_file = File.join(metrics_dir, 'metric_recent.bin')
          File.write(recent_file, 'data')
          File.utime(six_days_ago, six_days_ago, recent_file)
        end

        it 'returns false' do
          expect(described_class.has_work(params)).to eq(false)
        end
      end
    end

    describe '#perform' do
      context 'when retention_days is 0' do
        let(:retention_days) { 0 }

        it 'returns disabled message' do
          expect(subject.perform).to eq('Metrics cleanup disabled (retention_days is 0)')
        end
      end

      context 'when metrics directory does not exist' do
        before do
          FileUtils.rm_rf(metrics_dir)
        end

        it 'returns directory not exist message' do
          expect(subject.perform).to eq("Metrics directory does not exist: #{metrics_dir}")
        end
      end

      context 'when there are files to clean up' do
        let!(:old_file_1) { File.join(metrics_dir, 'metric_old_1.bin') }
        let!(:old_file_2) { File.join(metrics_dir, 'metric_old_2.bin') }
        let!(:recent_file) { File.join(metrics_dir, 'metric_recent.bin') }
        let!(:other_file) { File.join(metrics_dir, 'other_file.txt') }

        before do
          # Create old files (older than retention period)
          File.write(old_file_1, 'data1')
          File.utime(eight_days_ago, eight_days_ago, old_file_1)

          File.write(old_file_2, 'data2')
          File.utime(eight_days_ago, eight_days_ago, old_file_2)

          # Create recent file (within retention period)
          File.write(recent_file, 'data3')
          File.utime(six_days_ago, six_days_ago, recent_file)

          # Create non-metric file (should not be deleted)
          File.write(other_file, 'other')
          File.utime(eight_days_ago, eight_days_ago, other_file)
        end

        it 'deletes only old metric files' do
          subject.perform

          expect(File.exist?(old_file_1)).to eq(false)
          expect(File.exist?(old_file_2)).to eq(false)
          expect(File.exist?(recent_file)).to eq(true)
          expect(File.exist?(other_file)).to eq(true)
        end

        it 'returns success message with count' do
          cutoff_time = time - seven_days_seconds
          expect(subject.perform).to eq("Deleted 2 metrics file(s) older than #{cutoff_time}.")
        end

        it 'logs the cleanup operation' do
          logger = double('logger', info: nil, debug: nil, warn: nil)
          allow(subject).to receive(:logger).and_return(logger)

          subject.perform

          expect(logger).to have_received(:info).at_least(:once)
        end
      end

      context 'when file deletion fails' do
        let!(:protected_file) { File.join(metrics_dir, 'metric_protected.bin') }

        before do
          File.write(protected_file, 'data')
          File.utime(eight_days_ago, eight_days_ago, protected_file)
          allow(File).to receive(:delete).with(protected_file).and_raise(Errno::EACCES, 'Permission denied')
        end

        it 'logs warning and continues' do
          logger = double('logger', info: nil, debug: nil, warn: nil)
          allow(subject).to receive(:logger).and_return(logger)

          result = subject.perform

          expect(logger).to have_received(:warn).with(/Failed to delete metrics file/)
          expect(result).to match(/Failed to delete 1 file\(s\)/)
        end

        it 'includes failure count in result message' do
          cutoff_time = time - seven_days_seconds
          result = subject.perform
          expect(result).to eq("Deleted 0 metrics file(s) older than #{cutoff_time}. Failed to delete 1 file(s).")
        end
      end

      context 'when there are no files to clean up' do
        it 'returns message with zero count' do
          cutoff_time = time - seven_days_seconds
          expect(subject.perform).to eq("Deleted 0 metrics file(s) older than #{cutoff_time}.")
        end
      end

      context 'with different retention periods' do
        let(:retention_days) { 30 }
        let(:thirty_one_days_ago) { time - (31 * 24 * 60 * 60) }
        let!(:very_old_file) { File.join(metrics_dir, 'metric_very_old.bin') }

        before do
          File.write(very_old_file, 'data')
          File.utime(thirty_one_days_ago, thirty_one_days_ago, very_old_file)
        end

        it 'respects the configured retention period' do
          subject.perform
          expect(File.exist?(very_old_file)).to eq(false)
        end
      end
    end
  end
end
