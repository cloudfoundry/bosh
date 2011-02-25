task :default => [ :spec, :build ]

task :build do
  sh("cd cli && rake install")
end

task :bundle_install do
  bundle_cmd = "bundle --local install --without development production"
  sh(bundle_cmd)

  %w(director cli simple_blobstore_server).each do |component|
    sh("cd #{component} && #{bundle_cmd}")
  end
end

task :spec => [ :bundle_install ] do
  sh("cd spec && rake spec")
end

task "spec:ci" => [ :bundle_install ] do
  sh("cd spec && rake spec:ci")
end


