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
        blob = File.join(blobs_dir, blob_name)
        File.open(blob, 'w+') { |f| f.write(blob_name) }
        bosh_runner.run_in_current_dir("add-blob #{blob} #{blob_name}")
      end

      out = bosh_runner.run_in_current_dir('upload-blobs')
      blobs.each { |b| expect(out).to match(/Blob upload '#{b}' .* finished/) }

      FileUtils.rm_rf(blobs_dir)
      FileUtils.rm_rf(File.join(ClientSandbox.test_release_dir, '.blobs'))

      output = bosh_runner.run_in_current_dir("sync-blobs #{parallel}")
    end

    output
  end

  let(:blobs) { %w[test_blob_1 test_blob_2 test_blob_3] }

  context 'with parallel downloads' do
    let(:parallel) { '--parallel 5' }

    it 'properly outputs progress' do
      blobs.each do |blob_name|
        expect(sync_blobs_output).to match(/Blob download '#{blob_name}' .* started/)
        expect(sync_blobs_output).to match(/Blob download '#{blob_name}' .* finished/)
      end
    end
  end

  context 'with sequential downloads' do
    let(:parallel) { '--parallel 1' }

    it 'properly outputs progress' do
      expected_sequential_output = ''
      blobs.each do |blob_name|
        expected_sequential_output << "Blob download '#{blob_name}' .* started\n"
        expected_sequential_output << "Blob download '#{blob_name}' .* finished\n"
      end
      expected_regex = Regexp.new expected_sequential_output
      expect(sync_blobs_output).to match expected_regex
    end
  end
end
