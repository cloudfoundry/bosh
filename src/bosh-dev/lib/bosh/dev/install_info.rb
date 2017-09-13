module Bosh::Dev
  class InstallInfo < Struct.new(:name, :rev, :darwin_sha256, :linux_sha256)
    def sha256
      darwin? ? darwin_sha256 : linux_sha256
    end

    def platform
      darwin? ? 'darwin' : 'linux'
    end

    def file_name_to_download
      "#{name}-#{rev}-#{platform}-amd64"
    end

    private

    def darwin?
      RUBY_PLATFORM =~ /darwin/
    end
  end
end
