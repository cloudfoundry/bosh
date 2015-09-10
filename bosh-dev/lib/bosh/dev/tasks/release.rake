namespace :release do
  desc 'Create BOSH dev release'
  task :create_dev_release do
    require 'bosh/dev/build'
    require 'bosh/dev/gem_components'

    build = Bosh::Dev::Build.candidate
    gem_components = Bosh::Dev::GemComponents.new(build.number)
    gem_components.build_release_gems
    create_release
  end

  desc 'Upload BOSH dev release'
  task :upload_dev_release, [:rebase] => :create_dev_release do |_, args|
    args.with_defaults(rebase: false)

    rebase_arg = args[:rebase] ? '--rebase' : ''

    Dir.chdir('release') do
      shell("bosh -n upload release #{rebase_arg}")
    end
  end

  private

  def create_release(options={})
    name = options[:name] || 'bosh'
    final = options[:final] || false
    release_dir = options[:release_dir] || 'release'

    Dir.chdir(release_dir) do
      if final
        shell('bosh create release --final')
      else
        File.open('config/dev.yml', 'w+') { |f| f.write("---\ndev_name: #{name}\n") }
        shell('bosh create release --force')
      end
    end
  end

  def has_chruby?
    out, status = Open3.capture2e('chruby-exec --help')
    status.success?
  rescue
      false
  end

  def runner_ruby
    ENV['CLI_RUBY_VERSION'] || begin
      bosh_base = File.expand_path('../../../../../..', __FILE__)
      ruby_spec = YAML.load_file(File.join(bosh_base, 'release/packages/ruby/spec'))
      ruby_spec['files'].find { |f| f =~ /ruby-(.*).tar.gz/ }
      $1
    end
  end

  def shell(command)
    if has_chruby?
      sh("chruby-exec #{runner_ruby} -- bundle exec #{command}")
    else
      # this one with 2.1.6 and 1.9.3
      sh("bundle exec #{command}")
    end
  end
end
