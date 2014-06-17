RealFile            = File
RealFileTest        = FileTest
RealFileUtils       = FileUtils
RealDir             = Dir
RealPathname        = Pathname

def RealPathname(*args)
  RealPathname.new(*args)
end

if RUBY_VERSION >= "1.9.3"
  def Pathname(*args)
    Pathname.new(*args)
  end
end

module FakeFS
  @activated = false
  class << self
    def activated?
      @activated
    end

    def activate!
      @activated = true
      Object.class_eval do
        remove_const(:Dir)
        remove_const(:File)
        remove_const(:FileTest)
        remove_const(:FileUtils)
        remove_const(:Pathname) if RUBY_VERSION >= "1.9.3"

        const_set(:Dir,       FakeFS::Dir)
        const_set(:File,      FakeFS::File)
        const_set(:FileUtils, FakeFS::FileUtils)
        const_set(:FileTest,  FakeFS::FileTest)
        const_set(:Pathname,  FakeFS::Pathname) if RUBY_VERSION >= "1.9.3"
      end
      true
    end

    def deactivate!
      @activated = false

      Object.class_eval do
        remove_const(:Dir)
        remove_const(:File)
        remove_const(:FileTest)
        remove_const(:FileUtils)
        remove_const(:Pathname) if RUBY_VERSION >= "1.9.3"

        const_set(:Dir,       RealDir)
        const_set(:File,      RealFile)
        const_set(:FileTest,  RealFileTest)
        const_set(:FileUtils, RealFileUtils)
        const_set(:Pathname,  RealPathname) if RUBY_VERSION >= "1.9.3"
      end
      true
    end

    def with
      if activated?
        yield
      else
        begin
          activate!
          yield
        ensure
          deactivate!
        end
      end
    end

    def without
      if !activated?
        yield
      else
        begin
          deactivate!
          yield
        ensure
          activate!
        end
      end
    end
  end
end

def FakeFS(&block)
  return ::FakeFS unless block
  ::FakeFS.with(&block)
end
