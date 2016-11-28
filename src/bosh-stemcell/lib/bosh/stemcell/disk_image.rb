require 'bosh/core/shell'
require 'bosh/stemcell/arch'
require 'tmpdir'

module Bosh::Stemcell
  class DiskImage

    attr_reader :image_mount_point

    def initialize(options)
      @image_file_path   = options.fetch(:image_file_path)
      @image_mount_point = options.fetch(:image_mount_point, Dir.mktmpdir)
      @verbose           = options.fetch(:verbose, false)
      @shell             = Bosh::Core::Shell.new
    end

    def mount
      device_path   = stemcell_loopback_device_name
      mount_command = "sudo mount #{device_path} #{image_mount_point}"
      shell.run(mount_command, output_command: verbose)
    rescue => e
      raise e unless e.message.include?(mount_command)

      sleep 0.5
      shell.run(mount_command, output_command: verbose)
    end

    def unmount
      shell.run("sudo umount #{image_mount_point}", output_command: verbose)
    ensure
      unmap_image
    end

    def while_mounted
      mount
      yield self
    ensure
      unmount
    end

    private

    attr_reader :image_file_path, :verbose, :shell, :device

    def stemcell_loopback_device_name
      split_output = map_image.split(' ')
      device_name  = split_output[2]

      File.join('/dev/mapper', device_name)
    end

    def map_image
      @device = shell.run("sudo losetup --show --find #{image_file_path}", output_command: verbose)
      if Bosh::Stemcell::Arch.ppc64le?
        # power8 guest images have a p1: PReP partition and p2: file system, we need loopp2 here
        shell.run("sudo kpartx -av #{device} | grep \"^add\" | grep \"p2 \"", output_command: verbose)
      else
        shell.run("sudo kpartx -av #{device}", output_command: verbose)
      end
    end

    def unmap_image
      shell.run("sudo kpartx -dv #{device}", output_command: verbose)
      shell.run("sudo losetup -dv #{device}", output_command: verbose)
    end
  end
end
