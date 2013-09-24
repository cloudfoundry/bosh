require 'bosh/stemcell/disk_image'

RSpec.configure do |config|
  config.before(:all, example_group: { file_path: /spec\/stemcells/ }) do
    pending 'ENV["STEMCELL_IMAGE"] must be set to test Stemcells' unless ENV['STEMCELL_IMAGE']
  end

  config.around(example_group: { file_path: /spec\/stemcells/ }) do |example|
    if ENV['STEMCELL_IMAGE']
      Bosh::Stemcell::DiskImage.new(image_file_path: ENV['STEMCELL_IMAGE']).while_mounted do |disk_image|
        Serverspec::Backend::Exec.instance.chroot_dir = disk_image.image_mount_point
        example.run
      end
    else
      example.run
    end
  end
end
