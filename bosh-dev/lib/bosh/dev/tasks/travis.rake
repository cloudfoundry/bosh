namespace :travis do
  task :install_go do
    FileUtils.mkdir_p('tmp')
    sh 'curl https://go.googlecode.com/files/go1.2.linux-amd64.tar.gz > tmp/go.tgz'
    sh 'tar xzf tmp/go.tgz -C tmp'
    ENV['PATH'] = "#{File.absolute_path('tmp/go/bin')}:#{ENV['PATH']}"
  end
end
