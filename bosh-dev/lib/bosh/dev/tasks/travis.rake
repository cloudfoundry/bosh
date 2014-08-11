namespace :travis do
  task :install_go do
    FileUtils.mkdir_p('tmp')
    sh('curl https://s3.amazonaws.com/bosh-dependencies/go1.2.linux-amd64.tar.gz > tmp/go.tgz')
    sh('tar xzf tmp/go.tgz -C tmp')

    ENV['PATH'] = "#{File.absolute_path('tmp/go/bin')}:#{ENV['PATH']}"
    ENV['GOROOT'] = File.absolute_path('tmp/go')

    vet_repo = 'code.google.com/p/go.tools/cmd/vet'
    sh("go get #{vet_repo}")
    sh("go install #{vet_repo}")

    golint_repo = 'github.com/golang/lint/golint'
    sh("go get #{golint_repo}")
    sh("go install #{golint_repo}")
  end
end
