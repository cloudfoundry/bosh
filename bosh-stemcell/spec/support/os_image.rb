require 'rspec/core/formatters/console_codes'

RSpec.configure do |config|
  if ENV['OS_IMAGE']
    config.before(:all) do
      @os_image_dir = Dir.mktmpdir('os-image-rspec')
      Bosh::Core::Shell.new.run("sudo tar xf #{ENV['OS_IMAGE']} -C #{@os_image_dir}")
      SpecInfra::Backend::Exec.instance.chroot_dir = @os_image_dir
    end

    config.after(:all) do
      Bosh::Core::Shell.new.run("sudo rm -rf #{@os_image_dir}")
    end
  else
    # when running stemcell testings, we need also run the os image testings again
    unless ENV["STEMCELL_IMAGE"]
      warning = 'Both ENV["OS_IMAGE"] and ENV["STEMCELL_IMAGE"] are not set, os_image test cases are being skipped.'
      puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
      config.filter_run_excluding os_image: true
    end
  end
end
