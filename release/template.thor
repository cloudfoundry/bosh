require "erb"
require "tmpdir"

require "bundler/setup"

class Template < Thor
  include Thor::Actions

  TEMPLATE_PATH = File.expand_path("../template", __FILE__)

  def self.source_root
    File.dirname(__FILE__)
  end

  attr_reader :template_args

  no_tasks do
    def run!(cmd)
      fork do
        exec cmd
      end
      Process.wait
    end
  end

  desc "create", "create a VM template"
  method_options :iso => :string, :ssh_key => :string
  def create
    # Find OVF tool
    ovftool_bin = ENV['OVFTOOL'] ||= '/usr/lib/vmware/ovftool/ovftool'
    unless File.file?(ovftool_bin)
      $stderr.puts "stemcell builder expects #{ovftool_bin} or the OVFTOOL environment variable to be set"
      exit 1
    end

    Dir.mktmpdir do |work_dir|
      @template_args = {
        :work_dir => work_dir,
        :firstboot => File.join(work_dir, 'build', 'firstboot.sh'),
        :copyin => File.join(work_dir, 'build', 'copy.in'),
        :execscript => File.join(work_dir, 'build', 'execscript.sh')
      }

      if options.ssh_key
        raise "Invalid ssh public key file specified" unless File.file?(options.ssh_key)
        @template_args[:ssh_key] = options.ssh_key
      end

      directory(TEMPLATE_PATH, work_dir)

      # Use ISO if provided
      if options.iso
        raise "Invalid Ubuntu ISO specified" unless File.file?(options.iso)
        iso_option = "--iso #{options.iso}"
      else
        iso_option = ""
      end

      inside(work_dir) do
        chmod("build/execscript.sh", 0755)
        chmod("instance/prepare_instance.sh", 0755)

        vmbuilder_args = [
          "--debug",
          "--mem 512",
          iso_option,
          "-c #{work_dir}/vmbuilder.cfg",
          "--templates #{work_dir}/build/templates",
          "--part #{work_dir}/build/part.in"
        ].join(" ")
        run!("sudo vmbuilder esxi ubuntu #{vmbuilder_args}")

        # Generate OVF image
        run!("#{ovftool_bin} ubuntu-esxi/ubuntu.vmx ubuntu-esxi/image.ovf")

        # Archive OVF image
        inside('ubuntu-esxi') do
          archive_path = File.expand_path("../image.ovf.tgz", __FILE__)
          run!("tar zcf #{archive_path} image*")
        end
      end
    end

  end
end
