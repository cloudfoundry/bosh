require 'spec_helper'
require 'bosh/stemcell/disk_image'

describe 'OpenStack Stemcell' do
  before(:all) do
    pending 'ENV["STEMCELL_IMAGE"] must be set to test Stemcells' unless ENV['STEMCELL_IMAGE']
  end

  around do |example|
    if ENV['STEMCELL_IMAGE']
      Bosh::Stemcell::DiskImage.new(image_file_path: ENV['STEMCELL_IMAGE']).while_mounted do |disk_image|
        Serverspec::Backend::Exec.instance.chroot_dir = disk_image.image_mount_point
        example.run
      end
    else
      example.run
    end
  end

  context 'installed by system_parameters' do
    describe file('/etc/infrastructure') do
      it { should contain('openstack') }
    end
  end
end
