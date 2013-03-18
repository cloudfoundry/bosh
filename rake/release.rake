namespace :release do
  desc 'Create bosh dev release'
  task :create_dev_release => :'all:finalize_release_directory' do
    create_release
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
