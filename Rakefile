task :default => [ :spec, :build ]

task :build do
  sh("cd cli && rake install")
end

task :bundle_install do
  sh("bundle --local install")
  sh("cd director && bundle --local install")
  sh("cd cli && bundle --local install")
  sh("cd simple_blobstore_server && bundle --local install")
end

task :spec => [ :bundle_install ] do
  sh("cd spec && rake spec")
end

task "spec:ci" => [ :bundle_install ] do
  sh("cd spec && rake spec:ci")
end


