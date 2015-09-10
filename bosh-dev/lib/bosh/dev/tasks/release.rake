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
      sh("bosh -n upload release #{rebase_arg}")
    end
  end

  def create_release(options={})
    name = options[:name] || 'bosh'
    final = options[:final] || false
    release_dir = options[:release_dir] || 'release'

    Dir.chdir(release_dir) do
      if final
        sh('bosh create release --final')
      else
        File.open('config/dev.yml', 'w+') { |f| f.write("---\ndev_name: #{name}\n") }
        sh('bosh create release --force')
      end
    end
  end
end
