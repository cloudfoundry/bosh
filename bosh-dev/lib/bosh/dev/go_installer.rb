require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev
  class GoInstaller

    GO_URLS = {
      '1.1.2' => {
        macosx: {
          '386' => 'https://go.googlecode.com/files/go1.1.2.darwin-386.tar.gz',
          'amd64' => 'https://go.googlecode.com/files/go1.1.2.darwin-amd64.tar.gz',
        },
        linux: {
          '386' => 'https://go.googlecode.com/files/go1.1.2.linux-386.tar.gz',
          #'amd64' => 'https://go.googlecode.com/files/go1.1.2.linux-amd64.tar.gz'
          'amd64' => 'https://s3.amazonaws.com/bosh-dependencies/go1.2.linux-amd64.tar.gz',
        },
        bsd: {
          '386' => 'https://go.googlecode.com/files/go1.1.2.freebsd-386.tar.gz',
          'amd64' => 'https://go.googlecode.com/files/go1.1.2.freebsd-amd64.tar.gz',
        },
      },
      '1.2.2' => {
        macosx: {
          '386' => 'https://storage.googleapis.com/golang/go1.2.2.darwin-386-osx10.8.tar.gz',
          'amd64' => 'https://storage.googleapis.com/golang/go1.2.2.darwin-amd64-osx10.8.tar.gz',
        },
        linux: {
          '386' => 'https://storage.googleapis.com/golang/go1.2.2.linux-386.tar.gz',
          'amd64' => 'https://storage.googleapis.com/golang/go1.2.2.linux-amd64.tar.gz',
        },
        bsd: {
          '386' => 'https://storage.googleapis.com/golang/go1.2.2.freebsd-386.tar.gz',
          'amd64' => 'https://storage.googleapis.com/golang/go1.2.2.freebsd-amd64.tar.gz',
        },
      },
      '1.3.3' => {
        macosx: {
          '386' => 'https://storage.googleapis.com/golang/go1.3.3.darwin-386-osx10.8.tar.gz',
          'amd64' => 'https://storage.googleapis.com/golang/go1.3.3.darwin-amd64-osx10.8.tar.gz',
        },
        linux: {
          '386' => 'https://storage.googleapis.com/golang/go1.3.3.linux-386.tar.gz',
          'amd64' => 'https://storage.googleapis.com/golang/go1.3.3.linux-amd64.tar.gz',
        },
        bsd: {
          '386' => 'https://storage.googleapis.com/golang/go1.3.3.freebsd-386.tar.gz',
          'amd64' => 'https://storage.googleapis.com/golang/go1.3.3.freebsd-amd64.tar.gz',
        },
      },
      '1.4.2' => {
        macosx: {
          '386' => 'https://storage.googleapis.com/golang/go1.4.2.darwin-386-osx10.8.tar.gz',
          'amd64' => 'https://storage.googleapis.com/golang/go1.4.2.darwin-amd64-osx10.8.tar.gz',
        },
        linux: {
          '386' => 'https://storage.googleapis.com/golang/go1.4.2.linux-386.tar.gz',
          'amd64' => 'https://storage.googleapis.com/golang/go1.4.2.linux-amd64.tar.gz',
        }
      }
    }

    def initialize(version='1.3.3', location='tmp')
      @version = version
      @location = location
    end

    def install
      tarball_path = File.join(@location, 'go.tgz')
      RakeFileUtils.sh("curl #{tarball_url} > #{tarball_path}")
      RakeFileUtils.sh("tar xzf #{tarball_path} -C #{@location}")
    end

    def tarball_url
      unless GO_URLS[@version]
        raise "Go version unsupported: #{@version}"
      end
      unless GO_URLS[@version][os] && GO_URLS[@version][os][platform_arch]
        raise "Platform unsupported: #{os}-#{platform_arch}"
      end
      GO_URLS[@version][os][platform_arch]
    end

    def os
      @os ||= (
      host_os = RbConfig::CONFIG['host_os']
      case host_os
        when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
          :windows
        when /darwin|mac os/
          :macosx
        when /linux/
          :linux
        when /bsd/
          :bsd
        when /solaris/
          :solaris
        else
          raise "Unknown OS: #{host_os.inspect}"
      end
      )
    end

    def platform_arch
      @platform_arch ||= ['a'].pack('P').length > 4 ? 'amd64' : '386'
    end
  end
end
