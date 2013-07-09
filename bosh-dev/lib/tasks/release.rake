namespace :release do
  desc 'Create BOSH dev release'
  task :create_dev_release => :'all:finalize_release_directory' do
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
    name = options[:name] || "bosh"
    final = options[:final] || false
    Dir.chdir('release') do
      if final
        sh('bosh create release --final')
      else
        File.open('config/dev.yml', 'w+') { |f| f.write("---\ndev_name: #{name}\n") }
        sh('bosh create release --force')
      end
    end
  end
end
