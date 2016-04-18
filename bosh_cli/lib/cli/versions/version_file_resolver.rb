module Bosh::Cli::Versions
  class VersionFileResolver

    def initialize(storage, blobstore, tmpdir=Dir.tmpdir)
      @storage = storage
      @blobstore = blobstore
      @tmpdir = tmpdir
    end

    def find_file(blobstore_id, sha1, desc)
      if @storage.has_file?(sha1)
        file_path = @storage.get_file(sha1)
        file_sha1 = Digest::SHA1.file(file_path).hexdigest
        if file_sha1 == sha1
          return file_path
        end
        say("SHA1 '#{file_sha1}' of #{desc} does not match expected SHA1 '#{sha1}'".make_red)
      end

      if blobstore_id.nil?
        err("Cannot find #{desc}")
      end

      say("Downloading from blobstore (id=#{blobstore_id})...".make_green)

      tmp_file_path = File.join(@tmpdir, "bosh-tmp-file-#{SecureRandom.uuid}")
      begin
        File.open(tmp_file_path, 'wb') do |tmp_file|
          @blobstore.get(blobstore_id, tmp_file, sha1: sha1)
        end

        @storage.put_file(sha1, tmp_file_path)
      ensure
        FileUtils.rm(tmp_file_path, :force => true)
      end
    end
  end
end
