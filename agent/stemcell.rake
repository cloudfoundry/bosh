require File.join(File.dirname(__FILE__), "/lib/agent/version.rb")

require "erb"

namespace "ubuntu" do
  desc "Build Ubuntu stemcell"
  task "stemcell:build" do
    Rake::Task["ubuntu:cell"].invoke("stemcell")
  end

  # very much a hack that arequires to be run on Ubuntu with vmbuilder.
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
    ovftool_bin = ENV['OVFTOOL'] ||= '/usr/lib/vmware/ovftool/ovftool'
    unless File.exist?(ovftool_bin)
      puts "stemcell builder expects #{ovftool_bin} or the OVFTOOL environment variable to be set"
      exit 1
    end

    vmbuilder_cfg = ""
    File.open("misc/#{type}/vmbuilder.erb") do |f|
      vmbuilder_cfg = f.read # TODO won't read the whole file if it is large
    end

    args = {
      :firstboot => File.join(work_dir, 'build', 'firstboot.sh'),
      :copyin => File.join(work_dir, 'build', 'copy.in'),
      :execscript => File.join(work_dir, 'build', 'execscript.sh')
    }

    template = ERB.new(vmbuilder_cfg, 0, '%<>')
    result = template.result(binding)
    File.open(File.join(work_dir, 'vmbuilder.cfg'),'w') do |f|
      f.write(result)
    end

    mkdir_p File.join(work_dir, 'build')
    File.open(File.join(work_dir, 'build', 'copy.in'), 'w') do |f|
      f.puts("#{work_dir}/instance /var/vcap/bosh/src")
    end

    cp_r "misc/#{type}/build", work_dir
    cp_r "misc/#{type}/instance", work_dir
    chmod(0755, File.join(work_dir, 'build', 'execscript.sh'))
    chmod(0755, File.join(work_dir, 'instance', 'prepare_instance.sh'))

    instance_dir = File.join(work_dir, 'instance')

    File.open(File.join(instance_dir, "version"),'w') do |f|
      f.puts(version)
    end

    cp_r "lib", instance_dir
    cp_r "bin", instance_dir
    cp_r "vendor", instance_dir
    cp "Gemfile", instance_dir
    cp "Gemfile.lock", instance_dir

    iso_option = File.exist?('/var/tmp/ubuntu.iso') ? "--iso /var/tmp/ubuntu.iso" : ""

    Dir.chdir(work_dir) do
      vmbuilder_args = "--debug --mem 512 #{iso_option} -c #{work_dir}/vmbuilder.cfg"
      vmbuilder_args += " --templates #{work_dir}/build/templates --part #{work_dir}/build/part.in"
      sh "sudo vmbuilder esxi ubuntu #{vmbuilder_args}"

      # Generate stemcell image to be used with the esxcloud-cpi
      tmpdir = "#{type}-esxcloud-tmp"
      mkdir_p tmpdir
      Dir.chdir('ubuntu-esxi') do
        sh "tar zcf ../#{tmpdir}/image *.vmdk *.vmx"
      end

      File.open("#{tmpdir}/stemcell.MF", 'w') do |f|
        f.write("---\nname: #{stemcell_name}\nversion: #{version}\nbosh_protocol: #{bosh_protocol}\ncloud_properties: {}")
      end

      Dir.chdir(tmpdir) do
        sh "tar zcf ../bosh-esxcloud-#{type}-#{version}.tgz *"
      end
      FileUtils.rm_rf tmpdir

      # Generate stemcell image for the vSphere
      sh "#{ovftool_bin} ubuntu-esxi/ubuntu.vmx ubuntu-esxi/image.ovf"
      mkdir_p "#{type}"
      Dir.chdir('ubuntu-esxi') do
        sh "tar zcf ../#{type}/image image*"
      end

      File.open("#{type}/stemcell.MF", 'w') do |f|
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
