require 'spec_helper'
require 'bosh/director/bounded_archive_extractor'

module Bosh::Director
  describe BoundedArchiveExtractor do
    around do |example|
      Dir.mktmpdir do |dir|
        @dir = dir
        @destination = File.join(dir, 'out')
        FileUtils.mkdir_p(@destination)
        example.run
      end
    end

    def archive(content)
      source = File.join(@dir, 'source')
      FileUtils.mkdir_p(source)
      File.binwrite(File.join(source, 'image'), content)
      path = File.join(@dir, 'stemcell.tar')
      _out, err, status = Open3.capture3('tar', '-cf', path, '-C', source, 'image')
      raise err unless status.success?
      path
    end

    def compressed(path)
      destination = path + '.gz'
      Zlib::GzipWriter.open(destination) { |gzip| gzip.write(File.binread(path)) }
      destination
    end

    it 'extracts an ordinary gzip archive' do
      path = compressed(archive('image-data'))
      _out, _err, status = described_class.extract(path, @destination, max_bytes: 100_000)
      expect(status.success?).to be(true)
      expect(File.binread(File.join(@destination, 'image'))).to eq('image-data')
    end

    it 'extracts an ordinary uncompressed tar archive' do
      path = archive('image-data')
      _out, _err, status = described_class.extract(path, @destination, max_bytes: 100_000)
      expect(status.success?).to be(true)
    end

    it 'rejects a small gzip archive with excessive decompressed content' do
      path = compressed(archive('x' * 1_000_000))
      expect(File.size(path)).to be < 10_000
      expect do
        described_class.extract(path, @destination, max_bytes: 10_000)
      end.to raise_error(StemcellInvalidArchive, /budget/)
      image = File.join(@destination, 'image')
      expect(File.exist?(image) ? File.size(image) : 0).to be <= 10_000
    end

    it 'emits bounded chunks even when compressed data has no newlines' do
      path = compressed(archive('x' * 1_000_000))
      sizes = []
      described_class.send(:stream_archive, path, 2_000_000) { |chunk| sizes << chunk.bytesize }
      expect(sizes.size).to be > 1
      expect(sizes.max).to be <= described_class::CHUNK_SIZE
    end

    it 'bounds gzip metadata before creating the decompressor' do
      path = File.join(@dir, 'metadata.gz')
      File.binwrite(path, [0x1f, 0x8b, 8, 8, 0, 0, 0, 0, 0, 0].pack('C*') + ('x' * 100_000))
      expect do
        described_class.extract(path, @destination, max_bytes: 100_000)
      end.to raise_error(StemcellInvalidArchive, /metadata/)
    end

    it 'rejects truncated gzip data' do
      path = compressed(archive('image-data'))
      File.truncate(path, File.size(path) - 10)
      expect do
        described_class.extract(path, @destination, max_bytes: 100_000)
      end.to raise_error(StemcellInvalidArchive)
    end

    it 'bounds the number of empty gzip members' do
      path = File.join(@dir, 'empty-members.gz')
      File.open(path, 'wb') do |file|
        1_025.times { Zlib::GzipWriter.new(file).finish }
      end
      expect do
        described_class.extract(path, @destination, max_bytes: 100_000)
      end.to raise_error(StemcellInvalidArchive, /Too many/)
    end

    it 'stops extraction when a task checkpoint raises' do
      path = compressed(archive('image-data'))
      expect do
        described_class.extract(path, @destination, max_bytes: 100_000) { raise TaskCancelled }
      end.to raise_error(TaskCancelled)
    end

    it 'counts concatenated gzip members together' do
      original = archive('x' * 20_000)
      bytes = File.binread(original)
      path = File.join(@dir, 'concatenated.gz')
      File.open(path, 'wb') do |file|
        [bytes.byteslice(0, 10_000), bytes.byteslice(10_000..)].each do |part|
          writer = Zlib::GzipWriter.new(file)
          writer.write(part)
          writer.finish
        end
      end
      expect do
        described_class.extract(path, @destination, max_bytes: 15_000)
      end.to raise_error(StemcellInvalidArchive, /budget/)
    end

    it 'rejects nested compression before tar can auto-decompress it' do
      path = compressed(compressed(archive('image-data')))
      expect do
        described_class.extract(path, @destination, max_bytes: 100_000)
      end.to raise_error(StemcellInvalidArchive, /uncompressed tar|complete tar header/)
      expect(Dir.children(@destination)).to be_empty
    end
  end
end
