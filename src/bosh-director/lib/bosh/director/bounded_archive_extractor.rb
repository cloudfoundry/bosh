require 'open3'
require 'zlib'

module Bosh::Director
  class BoundedArchiveExtractor
    OUTPUT_LIMIT = 65_536
    CHUNK_SIZE = 65_536

    def self.extract(archive_path, destination, max_bytes:)
      result = nil
      Open3.popen3('tar', '-C', destination, '-xf', '-') do |input, output, error, process|
        output_reader = Thread.new { collect_output(output) }
        error_reader = Thread.new { collect_output(error) }
        streamed = false
        begin
          stream_archive(archive_path, max_bytes) do |chunk|
            yield if block_given?
            input.write(chunk)
          end
          streamed = true
        rescue Errno::EPIPE
          # tar rejected the input; retain its status and bounded diagnostics.
          streamed = true
        ensure
          terminate(process.pid) unless streamed
          input.close unless input.closed?
          out = output_reader.value
          err = error_reader.value
        end
        result = [out, err, process.value]
      end
      result
    rescue Zlib::Error, EOFError, ArgumentError => error
      raise StemcellInvalidArchive, "Invalid stemcell archive: #{error.class}"
    end

    def self.stream_archive(path, max_bytes)
      size = 0
      header = ''.b
      header_verified = false
      consume = proc do |chunk|
        size += chunk.bytesize
        raise StemcellInvalidArchive, 'Stemcell archive exceeds the available extraction budget' if size > max_bytes
        unless header_verified
          header << chunk
          next if header.bytesize < 512
          validate_header!(header.byteslice(0, 512))
          chunk = header
          header_verified = true
          header = nil
        end
        yield chunk
      end

      File.open(path, 'rb') do |file|
        gzip = file.read(2) == "\x1f\x8b".b
        file.rewind
        if gzip
          each_gzip_chunk(file, &consume)
        else
          while (chunk = file.read(CHUNK_SIZE))
            consume.call(chunk)
          end
        end
      end
      raise StemcellInvalidArchive, 'Stemcell archive has no complete tar header' unless header_verified
    end

    def self.each_gzip_chunk(file)
      members = 0
      while file.pos < file.size
        members += 1
        raise StemcellInvalidArchive, 'Too many gzip members' if members > 1_024
        validate_gzip_header!(file)
        reader = Zlib::GzipReader.new(file)
        unused = nil
        begin
          loop do
            begin
              chunk = reader.readpartial(CHUNK_SIZE)
            rescue EOFError
              break
            end
            yield chunk
          end
          unused = reader.unused
        ensure
          reader.finish
        end
        file.seek(-unused.bytesize, IO::SEEK_CUR) if unused
      end
    end

    def self.validate_gzip_header!(file)
      position = file.pos
      header = file.read(10)
      unless header&.bytesize == 10 && header.byteslice(0, 3) == "\x1f\x8b\x08".b && (header.getbyte(3) & 0xe0).zero?
        raise StemcellInvalidArchive, 'Invalid gzip header'
      end
      flags = header.getbyte(3)
      if (flags & 4).positive?
        length = file.read(2)
        raise StemcellInvalidArchive, 'Invalid gzip extra field' unless length&.bytesize == 2
        file.seek(length.unpack1('v'), IO::SEEK_CUR)
      end
      [8, 16].each do |flag|
        next if (flags & flag).zero?
        loop do
          raise StemcellInvalidArchive, 'Gzip metadata exceeds the supported size' if file.pos - position > OUTPUT_LIMIT
          byte = file.getbyte
          raise StemcellInvalidArchive, 'Incomplete gzip metadata' if byte.nil?
          break if byte.zero?
        end
      end
      file.seek(2, IO::SEEK_CUR) if (flags & 2).positive?
      raise StemcellInvalidArchive, 'Gzip metadata exceeds the supported size' if file.pos - position > OUTPUT_LIMIT
    ensure
      file.seek(position)
    end

    def self.validate_header!(header)
      return if header.bytes.all?(&:zero?)

      field = header.byteslice(148, 8).delete(" \0")
      valid_field = /\A[0-7]+\z/.match?(field)
      checksum = header.bytes.each_with_index.sum { |byte, index| (148...156).cover?(index) ? 32 : byte }
      signed_checksum = header.bytes.each_with_index.sum { |byte, index| (148...156).cover?(index) ? 32 : (byte >= 128 ? byte - 256 : byte) }
      unless valid_field && [checksum, signed_checksum].include?(field.to_i(8))
        raise StemcellInvalidArchive, 'Stemcell archive must contain an uncompressed tar stream'
      end
    end

    def self.terminate(pid)
      Process.kill('TERM', pid)
    rescue Errno::ESRCH
      # tar has already exited.
    end

    def self.collect_output(io)
      result = ''.b
      while (chunk = io.read(4096))
        remaining = OUTPUT_LIMIT - result.bytesize
        result << chunk.byteslice(0, remaining) if remaining.positive?
      end
      result
    end
    private_class_method :stream_archive, :each_gzip_chunk, :validate_gzip_header!, :validate_header!, :terminate, :collect_output
  end
end
