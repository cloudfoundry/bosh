require 'spec_helper'

describe 'sync blobs', type: :integration do
  with_reset_sandbox_before_each

  subject(:sync_blobs_output) do
    output = ''
    Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.rm_rf('dev_releases')

      blobs_dir = File.join(ClientSandbox.test_release_dir, 'blobs')
      FileUtils.mkdir_p(blobs_dir)

      blobs.each do |blob_name|
        File.open(File.join(blobs_dir, blob_name), 'w+') { |f| f.write(blob_name) }
      end

      out = bosh_runner.run_in_current_dir('upload blobs')
      blobs.each { |b| expect(out).to include("#{b} uploaded") }

      FileUtils.rm_rf(blobs_dir)
      FileUtils.rm_rf(File.join(ClientSandbox.test_release_dir, '.blobs'))

      output = bosh_runner.run_in_current_dir("#{parallel} sync blobs", :interactive => interactive_mode)
    end

    output
  end

  let(:blobs) { %w[test_blob_1 test_blob_2 test_blob_3] }

  context 'in non-interactive mode' do
    let(:interactive_mode) { false }

    context 'with parallel downloads' do
      let(:parallel) { '--parallel 5' }

      it 'properly outputs progress' do
        blobs.each do |blob_name|
          expect(sync_blobs_output).to include("#{blob_name} downloading")
          expect(sync_blobs_output).to include("#{blob_name} downloaded")
        end
      end
    end

    context 'with sequential downloads' do
      let(:parallel) { '' }

      it 'properly outputs progress' do
        blobs.each do |blob_name|
          expected_sequential_output = "#{blob_name} downloading 11B\n"
          expected_sequential_output << "#{blob_name} downloaded\n"
          expect(sync_blobs_output).to include(expected_sequential_output)
        end
      end
    end
  end
end
