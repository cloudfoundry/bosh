def build_micro_bosh_release
  Dir.chdir('release') do
    sh('cp config/microbosh-dev-template.yml config/dev.yml')
    sh('bosh create release --force --with-tarball')
  end

  release_tarball = `ls -1t release/dev_releases/micro-bosh*.tgz | head -1`.chomp
  File.join(File.expand_path(File.dirname(__FILE__)), "..", "..", release_tarball)
end

def install_ci_cli_gems
  cli_gems = %w[bosh_cli bosh_cli_plugin_micro bosh_cli_plugin_aws].join(" ")
  `gem install --source 'https://s3.amazonaws.com/bosh-ci-pipeline/gems/' --source https://rubygems.org #{cli_gems} --pre`
  bosh_version = `bosh -v`.chomp
  unless bosh_version.match(/BOSH.*\.(\d+)$/)[1] == ENV['FLOW_NUMBER']
    raise StandardError, "#{bosh_version} installed, but #{ENV['FLOW_NUMBER']} expected"
  end
end