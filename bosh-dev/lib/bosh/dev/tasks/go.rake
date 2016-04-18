require 'bosh/dev/go_installer'

namespace :go do
  task :all => [
    'go:install',
    'go:set_path',
    'go:set_bin',
    'go:install_golint',
  ]

  desc 'Download & Install Go'
  task :install do
    require 'bosh/dev/go_installer'

    FileUtils.mkdir_p('tmp')

    Bosh::Dev::GoInstaller.new('1.5.1', 'tmp').install

    ENV['GOROOT'] = File.absolute_path('tmp/go')
    ENV['PATH'] = "#{File.absolute_path('tmp/go/bin')}:#{ENV['PATH']}"
  end

  desc 'Set the Go workspace path to ./go'
  task :set_path do
    # go workspace
    ENV['GOPATH'] = File.absolute_path('go')
  end

  desc 'Set the Go binary application path to ./go/gobin'
  task :set_bin do
    # go installed applications
    ENV['GOBIN'] = File.absolute_path('go/gobin')
    ENV['PATH'] = "#{File.absolute_path('go/gobin')}:#{ENV['PATH']}"
  end

  desc 'Install GoLint'
  task :install_golint do
    golint_repo = 'github.com/golang/lint/golint'
    sh("go get #{golint_repo}")
    sh("go install #{golint_repo}")
  end
end

desc 'Install Go and Go Tools'
task :go => %w(go:all)
