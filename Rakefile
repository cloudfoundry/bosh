task :default => [ :spec, :build ]

desc "build and install the bosh cli gem"
task :build do
  sh("cd cli && bundle exec rake install")
end

desc "install all gem dependencies"
task :bundle_install do
  bundle_cmd = "cd spec && bundle --local install --without development production"
  sh(bundle_cmd)

  %w(director cli simple_blobstore_server agent health_monitor).each do |component|
    sh("cd #{component} && #{bundle_cmd}")
  end
end

desc "run spec tests"
task :spec => [ :bundle_install ] do
  sh("cd spec && bundle exec rake spec")
end

desc "run CI spec tests"
task "spec:ci" => [ :bundle_install ] do
  sh("cd spec && bundle exec rake spec:ci")
end


