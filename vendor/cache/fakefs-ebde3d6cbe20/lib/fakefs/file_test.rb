module FakeFS
  module FileTest
    extend self

    def exist?(file_name)
      File.exist?(file_name)
    end

    def directory?(file_name)
      File.directory?(file_name)
    end

    def file?(file_name)
      File.file?(file_name)
    end

    def writable?(file_name)
      File.writable?(file_name)
    end
  end
end
