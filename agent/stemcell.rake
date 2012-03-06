# Copyright (c) 2009-2012 VMware, Inc.

require File.join(File.dirname(__FILE__), "/lib/agent/version.rb")

require "erb"
require "yaml"

namespace "ubuntu" do
  desc "Build Ubuntu stemcell"
  task "stemcell:build" do
    Rake::Task["ubuntu:cell"].invoke("stemcell")
  end

  # very much a hack that requires to be run on Ubuntu with vmbuilder.
  # Don't do this remote as it probably will kill your sshd.
  desc "Build Ubuntu cell"
  task "cell", :type do |t, args|
    stemcell_name = ENV["STEMCELL_NAME"] || "bosh-stemcell"

    type = args[:type]
    version = Bosh::Agent::VERSION
    bosh_protocol = Bosh::Agent::BOSH_PROTOCOL

    work_dir = "/var/tmp/bosh/agent-#{version}-#{$$}"
    mkdir_p work_dir

    # fail sooner rather than later
    ovftool_bin = ENV["OVFTOOL"] ||= "/usr/lib/vmware/ovftool/ovftool"
    unless File.exist?(ovftool_bin)
      puts "stemcell builder expects #{ovftool_bin} or the OVFTOOL environment variable to be set"
      exit 1
    end

    vmbuilder_cfg = ""
    File.open("misc/#{type}/vmbuilder.erb") do |f|
      vmbuilder_cfg = f.read # TODO won't read the whole file if it is large
    end

    args = {
      :firstboot => File.join(work_dir, "build", "firstboot.sh"),
      :copyin => File.join(work_dir, "build", "copy.in"),
      :execscript => File.join(work_dir, "build", "execscript.sh")
    }

    template = ERB.new(vmbuilder_cfg, 0, "%<>")
    result = template.result(binding)
    File.open(File.join(work_dir, "vmbuilder.cfg"), "w") do |f|
      f.write(result)
    end

    mkdir_p File.join(work_dir, "build")
    File.open(File.join(work_dir, "build", "copy.in"), "w") do |f|
      f.puts("#{work_dir}/instance /var/vcap/bosh/src")
    end

    cp_r "misc/#{type}/build", work_dir
    cp_r "misc/#{type}/instance", work_dir
    chmod(0755, File.join(work_dir, "build", "execscript.sh"))
    chmod(0755, File.join(work_dir, "instance", "prepare_instance.sh"))

    instance_dir = File.join(work_dir, "instance")

    File.open(File.join(instance_dir, "version"), "w") do |f|
      f.puts(version)
    end

    cp_r "lib", instance_dir
    cp_r "bin", instance_dir
    cp_r "vendor", instance_dir
    cp "Gemfile", instance_dir
    cp "Gemfile.lock", instance_dir

    iso_option = File.exist?("/var/tmp/ubuntu.iso") ? "--iso /var/tmp/ubuntu.iso" : ""

    Dir.chdir(work_dir) do
      vmbuilder_args = "--debug --mem 512 #{iso_option} -c #{work_dir}/vmbuilder.cfg"
      vmbuilder_args += " --templates #{work_dir}/build/templates --part #{work_dir}/build/part.in"
      sh "sudo vmbuilder esxi ubuntu #{vmbuilder_args}"

      # Generate stemcell image to be used with the esxcloud-cpi
      tmpdir = "#{type}-esxcloud-tmp"
      mkdir_p tmpdir
      Dir.chdir("ubuntu-esxi") do
        sh "tar zcf ../#{tmpdir}/image *.vmdk *.vmx"
      end

      File.open("#{tmpdir}/stemcell.MF", "w") do |f|
        f.write("---\nname: #{stemcell_name}\nversion: #{version}\nbosh_protocol: #{bosh_protocol}\ncloud_properties: {}")
      end

      Dir.chdir(tmpdir) do
        sh "tar zcf ../bosh-esxcloud-#{type}-#{version}.tgz *"
      end
      FileUtils.rm_rf tmpdir

      # Generate stemcell image for the vSphere
      sh "#{ovftool_bin} ubuntu-esxi/ubuntu.vmx ubuntu-esxi/image.ovf"
      mkdir_p "#{type}"
      Dir.chdir("ubuntu-esxi") do
        sh "tar zcf ../#{type}/image image*"
      end

      File.open("#{type}/stemcell.MF", "w") do |f|
        f.write("---\nname: #{stemcell_name}\nversion: #{version}\nbosh_protocol: #{bosh_protocol}\ncloud_properties: {}")
      end

      cp("stemcell_dpkg_l.out", "#{type}/stemcell_dpkg_l.txt")

      Dir.chdir("#{type}") do
        sh "tar zcf ../bosh-#{type}-#{version}.tgz *"
      end

    end
    # TODO: guesthw version 7 for esx4
    # TODO: install bin wrapper
    # TODO: change location of agent install w/symlink strategy
    # TODO clean up lingering ISO mount which vmbuilder leaves behind
    puts "Generated #{type}: #{work_dir}/bosh-#{type}-#{version}.tgz"
    puts "Generated esxcloud #{type}: #{work_dir}/bosh-esxcloud-#{type}-#{version}.tgz"
    puts "Check #{work_dir} for build artifacts"
  end
end
namespace "stemcell" do
  def version
    Bosh::Agent::VERSION
  end

  def bosh_protocol
    Bosh::Agent::BOSH_PROTOCOL
  end

  def get_working_dir
    "/var/tmp/bosh/agent-#{version}-#{$$}"
  end

  def get_chroot_dir
    File.join(get_working_dir, "chroot")
  end

  def get_instance_dir
    File.join(get_working_dir, "instance")
  end

  def get_package_dir
    File.join(get_working_dir, "stemcell-package")
  end

  def get_ovftool_bin
    ovftool_bin = ENV["OVFTOOL"] ||= "/usr/lib/vmware/ovftool/ovftool"
    unless File.exist?(ovftool_bin)
      puts "stemcell builder expects #{ovftool_bin} or the OVFTOOL environment variable to be set"
      exit 1
    end
    ovftool_bin
  end

  def build_chroot
    work_dir = get_working_dir
    mkdir_p(work_dir)

    cp("misc/stemcell/build/vmbuilder.cfg", work_dir, :preserve => true)
    cp_r("misc/stemcell/build", work_dir, :preserve => true)
    cp_r("misc/stemcell/instance", work_dir, :preserve => true)

    # instance dir will be copied into /var/vcap/bosh/src in the chroot
    instance_dir = get_instance_dir

    File.open(File.join(instance_dir, "version"), "w") do |f|
      f.puts(version)
    end

    # Copy the BOSH agent
    cp_r("lib", instance_dir, :preserve => true)
    cp_r("bin", instance_dir, :preserve => true)
    cp_r("vendor", instance_dir, :preserve => true)
    cp("Gemfile", instance_dir, :preserve => true)
    cp("Gemfile.lock", instance_dir, :preserve => true)

    # Generate the chroot
    chroot_dir = get_chroot_dir
    chroot_script_dir = File.expand_path("build/chroot/stages", work_dir)

    if ENV["VMBUILDER_ISO"]
      iso = ENV["VMBUILDER_ISO"]
      fail("Could not find iso: #{iso}") unless File.exist?(iso)
    elsif File.exist?("/var/tmp/ubuntu.iso")
      iso = "/var/tmp/ubuntu.iso"
    else
      iso = ""
    end

    sh "sudo #{chroot_script_dir}/00_base.sh #{chroot_dir} #{iso}"
    sh "sudo #{chroot_script_dir}/01_warden.sh #{chroot_dir}"
    sh "sudo #{chroot_script_dir}/20_bosh.sh #{chroot_dir} #{instance_dir}"
  end

  def build_vm_image(options = {})
    work_dir = get_working_dir
    chroot_dir = get_chroot_dir
    package_dir = get_package_dir
    mkdir_p package_dir
    stemcell_name = ENV["STEMCELL_NAME"] || "bosh-stemcell"

    hypervisor = options[:hypervisor] || "esxi"
    format = options[:format]
    ovftool_bin = nil
    case hypervisor
      when "esxi"
        format ||= "ovf"
        # Check for OVFTOOL so we can fail fast when it's not found
        ovftool_bin = get_ovftool_bin if format == "ovf"
      when "xen"
        format ||= "aws"
      else
        raise "Unknown hypervisor: #{hypervisor}"
    end

    cp "misc/stemcell/build/vmbuilder.cfg", work_dir unless File.exist?(File.join(work_dir, "vmbuilder.cfg"))
    cp_r "misc/stemcell/build", work_dir unless File.exists?(File.join(work_dir, "build"))

    part_in = options[:part_in]

    # Update root partition size
    cp part_in, "#{work_dir}/build/part.in" if part_in && File.exist?(part_in)

    Dir.chdir(work_dir) do
      vmbuilder_args = "--debug --mem 512 --existing-chroot #{chroot_dir} -c #{work_dir}/vmbuilder.cfg"
      vmbuilder_args += " --templates #{work_dir}/build/templates --part #{work_dir}/build/part.in"
      sh("sudo vmbuilder #{hypervisor} ubuntu --debug #{vmbuilder_args}")

      manifest = {
        "name" => stemcell_name,
        "version" => version,
        "bosh_protocol" => bosh_protocol,
        "cloud_properties" => {}
      }

      mkdir_p("stemcell")

      case hypervisor
        when "esxi"
          case format
            when "ovf"
              sh "#{ovftool_bin} ubuntu-esxi/ubuntu.vmx ubuntu-esxi/image.ovf"
              Dir.chdir("ubuntu-esxi") do
                sh("tar zcf ../stemcell/image image*")
              end
            when "vmdk"
              Dir.chdir("ubuntu-esxi") do
                sh("tar zcf ../stemcell/image *.vmdk *.vmx")
              end
            else
              fail("Unknown format: #{format}")
          end

        when "xen"
          case format
            when "aws"
              Dir.chdir("ubuntu-xen") do
                files = Dir.glob("*")
                files.delete("xen.conf")
                raise "Found more than one image: #{files}" unless files.length == 1
                root_image = files.first
                mv(root_image, "root.img")
                sh("sudo e2label root.img stemcell_root")
                sh("tar zcf ../stemcell/image root.img")
              end
            else
              fail("Unknown format: #{format}")
          end
        else
          raise "Unknown hypervisor: #{hypervisor}"
      end

      File.open("stemcell/stemcell.MF", "w") do |f|
        f.write(YAML.dump(manifest))
      end

      sh("sudo cp #{chroot_dir}/var/vcap/bosh/stemcell_dpkg_l.out " +
             "stemcell/stemcell_dpkg_l.txt")

      out_filename = "bosh-stemcell-#{format}-#{version}.tgz"

      Dir.chdir("stemcell") do
        cp_r(Dir.glob("#{package_dir}/*"), ".")
        sh "tar zcf ../#{out_filename} *"
      end

      puts "Generated stemcell: #{work_dir}/#{out_filename}"
    end
    # TODO: guesthw version 7 for esx4
    # TODO: install bin wrapper
    # TODO: change location of agent install w/symlink strategy
    # TODO clean up lingering ISO mount which vmbuilder leaves behind
    puts "Check #{work_dir} for build artifacts"
  end

  def setup_chroot_dir(chroot=nil)
    return build_chroot if !chroot

    # put the user specified chroot directory or tgz under the working directory
    chroot = File.expand_path(chroot)

    work_dir = get_working_dir
    FileUtils.mkdir_p(work_dir)

    Dir.chdir(work_dir) do
      if File.directory?(chroot)
        sh "sudo ln -s #{chroot} chroot"
      else
        sh "sudo tar zxf #{chroot}"
        if !File.exists?("chroot")
          puts "Unrecognized format of the chroot tgz file: #{chroot}"
          exit 1
        end
      end
    end
  end

  def customize_chroot(component, manifest, tarball)
    chroot_dir = get_chroot_dir
    instance_dir = File.join(get_working_dir, "instance")
    package_dir = get_package_dir
    work_dir = get_working_dir
    FileUtils.mkdir_p(instance_dir)
    FileUtils.mkdir_p(package_dir)

    # Setup instance directory with code to build component.
    # Some helper code like "helpers.sh" and "skeleton" is copied as well.
    cp_r "misc/#{component}", instance_dir
    component_dir = File.join(instance_dir, component)
    cp_r "../package_compiler", component_dir
    cp_r "misc/stemcell/build/chroot/skeleton", component_dir
    cp_r "misc/stemcell/build/chroot/lib/helpers.sh", File.join(component_dir, "lib")

    # Copy release artifacts
    component_release_dir = File.join(instance_dir, "#{component}_release")
    FileUtils.mkdir_p(component_release_dir)
    cp manifest, "#{component_release_dir}/release.yml"
    cp tarball, "#{component_release_dir}/release.tgz"

    # Execute custom scripts
    component_script_dir = File.join(component_dir, "stages")
    Dir.glob(File.join(component_script_dir, "*")).sort.each do |script|
      sh "sudo #{script} #{chroot_dir} #{instance_dir} #{package_dir}"
    end
  end

  # Takes in an optional argument "chroot_dir"
  desc "Build stemcell [chroot_dir|chroot_tgz] - optional argument chroot dir or chroot tgz"
  task "basic", :chroot do |t, args|
    # Create/Setup chroot directory
    setup_chroot_dir(args[:chroot])

    # Build stemcell
    build_vm_image(:hypervisor => "esxi")
  end

  desc "Build chroot tgz"
  task "chroot_tgz" do
    setup_chroot_dir
    Dir.chdir(get_working_dir) do
      sh "sudo tar zcf chroot.tgz chroot"
    end
    puts "chroot directory is #{get_chroot_dir}"
    puts "Generated chroot tgz: #{File.join(get_working_dir, "chroot.tgz")}"
  end

  # Takes in an optional argument "chroot_dir"
  desc "Build aws stemcell [chroot_dir|chroot_tgz] - optional argument chroot dir or chroot tgz"
  task "aws", :chroot do |t, args|
    # Create/Setup chroot directory
    setup_chroot_dir(args[:chroot])

    work_dir = get_working_dir
    unless File.exists?(File.join(work_dir, "build"))
      cp_r("misc/stemcell/build", work_dir, :preserve => true)
    end

    lib_dir = File.join(work_dir, "build/chroot/lib")
    aws_lib_dir = File.join(lib_dir, "aws")
    stages_dir = File.join(work_dir, "build/chroot/stages")
    templates_dir = File.join(work_dir, "build/templates")

    cp_r("misc/aws/lib", aws_lib_dir, :preserve => true)
    cp_r("misc/aws/stages/.", stages_dir, :preserve => true)
    cp_r("misc/aws/templates/.", templates_dir, :preserve => true)

    # Generate the chroot
    chroot_dir = get_chroot_dir

    sh("sudo #{stages_dir}/30_aws.sh #{chroot_dir} #{lib_dir}")

    # Build stemcell
    build_vm_image(:hypervisor => "xen")
  end

  # TODO add micro cloud i.e "Build micro <cloud|bosh> ..."
  desc "Build micro bosh <manifest_file> <tarball> [chroot_dir|chroot_tgz]"
  task "micro", :component, :manifest, :tarball, :chroot do |t, args|
    # Verify component
    COMPONENTS = %w[micro_bosh]
    component = args[:component]
    manifest = File.expand_path(args[:manifest])
    tarball = File.expand_path(args[:tarball])

    unless COMPONENTS.include?(component)
      puts "Please specify a component to build. Supported components are #{COMPONENTS}"
      exit 1
    end

    unless manifest && tarball
      puts "Please specify a manifest and tarball for building component #{component}"
      exit 1
    end

    # Create/Setup chroot directory
    setup_chroot_dir(args[:chroot])

    # Customize chroot directory
    customize_chroot(component, manifest, tarball)

    # Create vm image
    build_vm_image(:part_in => "misc/#{component}/part.in")
  end
end
