def build_micro_bosh_release
  Dir.chdir('release') do
    sh('cp config/microbosh-dev-template.yml config/dev.yml')
    sh('bosh create release --force --with-tarball')
  end

  release_tarball = `ls -1t release/dev_releases/micro-bosh*.tgz | head -1`.chomp
  File.join(File.expand_path(File.dirname(__FILE__)), "..", "..", release_tarball)
end

def update_bosh_version(version_number)
  file_contents = File.read("BOSH_VERSION")
  file_contents.gsub!(/^([\d\.]+)\.pre\.\d+$/, "\\1.pre.#{version_number}")
  File.open("BOSH_VERSION", 'w') { |f| f.write file_contents }
end