RSpec.configure do |config|
  config.before(:all, example_group: { file_path: /(spec|support)\/os_image/ }) do
    pending 'ENV["OS_IMAGE"] must be set to test OS images' unless ENV['OS_IMAGE']

    if ENV['OS_IMAGE']
      @os_image_dir = Dir.mktmpdir('os-image')
      Bosh::Core::Shell.new.run("sudo tar xf #{ENV['OS_IMAGE']} -C #{@os_image_dir}")
      SpecInfra::Backend::Exec.instance.chroot_dir = @os_image_dir
    end
  end

  config.after(:all, example_group: { file_path: /(spec|support)\/os_image/ }) do
    FileUtils.rm_rf(@os_image_dir) if ENV['OS_IMAGE']
  end
end
