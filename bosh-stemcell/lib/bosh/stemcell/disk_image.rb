require 'bosh/core/shell'

module Bosh::Stemcell
  class DiskImage
    def initialize(options)
      @image_file_path = options.fetch(:image_file_path)
      @image_mount_point = options.fetch(:image_mount_point)
      @shell = Bosh::Core::Shell.new
    end

    def mount
      shell.run("sudo mount #{stemcell_loopback_device_name} #{image_mount_point}", output_command: true)
    end

    def unmount
      shell.run("sudo umount #{image_mount_point}", output_command: true)
      unmap_image
    end

    private

    attr_reader :image_file_path, :image_mount_point, :shell

    def stemcell_loopback_device_name
      "/dev/mapper/#{map_image}"
    end

    def map_image
      unless @image_device
        output = shell.run("sudo kpartx -av #{image_file_path}", output_command: true)
        @image_device = output.split(' ')[2]
      end
      @image_device
    end

    def unmap_image
      shell.run("sudo kpartx -dv #{image_file_path}", output_command: true)
    end
  end
end
