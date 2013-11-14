module Bosh::Cli
  class DownloadWithProgress
    def initialize(url, size)
      @url = url
      @size = size
      @filename = File.basename(@url)
    end

    def perform
      progress_bar = ProgressBar.new(@filename, @size)
      progress_bar.file_transfer_mode
      download_in_chunks { |chunk| progress_bar.inc(chunk.size) }
      progress_bar.finish
    end

    def sha1?(sha1)
      file_sha1 = Digest::SHA1.file(@filename).hexdigest
      file_sha1 == sha1
    end

    private

    def download_in_chunks
      File.open(@filename, 'w') do |file|
        http_client = HTTPClient.new
        http_client.get(@url) do |chunk|
          file.write(chunk)
          yield chunk
        end
      end
    end
  end
end
