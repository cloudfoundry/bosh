require 'bosh/stemcell/disk_image'

def wrap_server_spec_example(example)
  if ENV['STEMCELL_IMAGE']
    Bosh::Stemcell::DiskImage.new(image_file_path: ENV['STEMCELL_IMAGE']).while_mounted do |disk_image|
      SpecInfra::Backend::Exec.instance.chroot_dir = disk_image.image_mount_point
      example.run
    end
  else
    example.run
  end
end

RSpec.configure do |config|
  config.before(:all, example_group: { file_path: /spec\/stemcells/ }) do
    pending 'ENV["STEMCELL_IMAGE"] must be set to test Stemcells' unless ENV['STEMCELL_IMAGE']
  end

  config.around(example_group: { file_path: /spec\/stemcells/ }) do |example|
    wrap_server_spec_example(example)
  end

  config.around(example_group: { file_path: /support\/stemcell_shared_example/ }) do |example|
    wrap_server_spec_example(example)
  end
end
