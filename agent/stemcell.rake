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

  def get_infrastructure_name
    # VSphere is the default
    @infrastructure_name || "vsphere"
  end

  def get_ovftool_bin
    ovftool_bin = ENV["OVFTOOL"] ||= "/usr/lib/vmware/ovftool/ovftool"
    unless File.exist?(ovftool_bin)
      puts "stemcell builder expects #{ovftool_bin} or the OVFTOOL environment variable to be set"
      exit 1
    end
    ovftool_bin
  end

  def generate_agent_run_config(infrastructure_name)
    work_dir = get_working_dir
    File.open(File.join(work_dir, "instance/runit/agent/run"), "w") do |f|
      agent_run_config = ERB.new(File.read("misc/stemcell/agent_run.erb")).result(binding)
      f.write(agent_run_config)
    end
  end

  def sudo
    "sudo env http_proxy=#{ENV["http_proxy"]}"
  end

  def build_chroot
    work_dir = get_working_dir
    mkdir_p(work_dir)

    cp("misc/stemcell/build/vmbuilder.cfg", work_dir, :preserve => true)
    cp_r("misc/stemcell/build", work_dir, :preserve => true)
    cp_r("misc/stemcell/instance", work_dir, :preserve => true)

    # Generate agent run config for given infrastructure
    generate_agent_run_config(get_infrastructure_name)

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

    sh "#{sudo} #{chroot_script_dir}/00_base.sh #{chroot_dir} #{iso}"
    sh "#{sudo} #{chroot_script_dir}/01_warden.sh #{chroot_dir}"
    sh "#{sudo} #{chroot_script_dir}/20_bosh.sh #{chroot_dir} #{instance_dir}"
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

    part_in = options[:part_in] || @part_in

    # Update root partition size
    cp part_in, "#{work_dir}/build/part.in" if part_in && File.exist?(part_in)

    Dir.chdir(work_dir) do
      vmbuilder_args = "--debug --mem 512 --existing-chroot #{chroot_dir} -c #{work_dir}/vmbuilder.cfg"
      vmbuilder_args += " --templates #{work_dir}/build/templates --part #{work_dir}/build/part.in"
      sh("#{sudo} vmbuilder #{hypervisor} ubuntu --debug #{vmbuilder_args}")

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
                sh("#{sudo} e2label root.img stemcell_root")
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

      sh("#{sudo} cp #{chroot_dir}/var/vcap/bosh/stemcell_dpkg_l.out " +
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
        sh "#{sudo} ln -s #{chroot} chroot" unless File.exists?("chroot")
      else
        sh "#{sudo} tar zxf #{chroot}"
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
    cp_r("misc/#{component}", instance_dir, :preserve => true)
    component_dir = File.join(instance_dir, component)
    cp_r("../package_compiler", component_dir, :preserve => true)
    cp_r("misc/stemcell/build/chroot/skeleton", component_dir, :preserve => true)
    cp_r("misc/stemcell/build/chroot/lib/helpers.sh", File.join(component_dir, "lib"), :preserve => true)

    # Copy release artifacts
    component_release_dir = File.join(instance_dir, "#{component}_release")
    FileUtils.mkdir_p(component_release_dir)
    cp manifest, "#{component_release_dir}/release.yml"
    cp tarball, "#{component_release_dir}/release.tgz"

    # Execute custom scripts
    component_script_dir = File.join(component_dir, "stages")
    Dir.glob(File.join(component_script_dir, "*")).sort.each do |script|
      sh "#{sudo} #{script} #{chroot_dir} #{instance_dir} #{package_dir}"
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

  desc "Build chroot tgz [infrastructure] - optional argument: vsphere (default) or aws"
  task "chroot_tgz", :infrastructure do |t, args|
    if args[:infrastructure]
      INFRASTRUCTURES = %w[vsphere aws]
      unless INFRASTRUCTURES.include?(args[:infrastructure])
        puts "Please specify an infrastructure. Supported infrastructures are #{INFRASTRUCTURES}"
        exit 1
      end
      @infrastructure_name = args[:infrastructure]
      chroot_tgz = "chroot-#{@infrastructure_name}.tgz"
    else
      chroot_tgz = "chroot.tgz"
    end
    setup_chroot_dir
    Dir.chdir(get_working_dir) do
      sh "#{sudo} tar zcf #{chroot_tgz} chroot"
    end
    puts "chroot directory is #{get_chroot_dir}"
    puts "Generated chroot tgz: #{File.join(get_working_dir, chroot_tgz)}"
  end

  # Takes in an optional argument "chroot_dir"
  desc "Build aws stemcell [chroot_dir|chroot_tgz] - optional argument chroot dir or chroot tgz"
  task "aws", :chroot do |t, args|
    @infrastructure_name = "aws"

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

    sh("#{sudo} #{stages_dir}/30_aws.sh #{chroot_dir} #{lib_dir}")

    # Build stemcell
    build_vm_image(:hypervisor => "xen")
  end

  # TODO add micro cloud i.e "Build micro <cloud|bosh> ..."
  desc "Build micro bosh <manifest_file> <tarball> [chroot_dir|chroot_tgz]"
  task "micro", :component, :manifest, :tarball, :chroot do |t, args|
    # Verify component
    COMPONENTS = %w[micro_bosh]
    component, @infrastructure_name = args[:component].split(":", 2)
    manifest = File.expand_path(args[:manifest])
    tarball = File.expand_path(args[:tarball])
    @part_in = "misc/#{component}/part.in"

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
    case get_infrastructure_name
    when "vsphere"
      build_vm_image
    when "aws"
      Rake::Task["stemcell:aws"].invoke(get_chroot_dir)
    else
      puts "Unsupported infrastructure: #{@infrastructure_name}"
      exit 1
    end
  end

  namespace "public" do

    # If the user is trying to upload a new file to the public repository then
    # this function will determine if the file is already uploaded. If it is
    # and the file to upload is an exact duplicate, the program will exit.  If
    # it exists but the user is trying to upload a new version it will prompt
    # the user to overwrite the existing one.
    # @param [Hash] index_yaml The index file as a Hash.
    # @param [String] stemcell_path The path to the stemcell the user wants to
    #     upload.
    # @return [Boolean] Returns whether this upload is an update operation.
    def is_update?(index_yaml, stemcell_path)
      if index_yaml.has_key?(File.basename(stemcell_path))
        entry = index_yaml[File.basename(stemcell_path)]
        if entry["sha"] == Digest::SHA1.file(stemcell_path).hexdigest
          puts("No action taken, files are identical.")
          exit(0)
        end
        if agree("Stemcell already uploaded.  Do you want to overwrite it? " +
                 "[yn]")
          return true
        else
          exit(0)
        end
      end
      return false
    end

    # Loads the public stemcell uploader configuration file.
    # @return [Array] An array of the pertinent configuration file parameters:
    # stemcells_index_id, atmos_url, expiration, uid, secret
    def load_stemcell_config
      unless File.exists?("#{INDEX_FILE_DIR}/public_stemcell_config.yml")
        raise "#{INDEX_FILE_DIR}/public_stemcell_config.yml does not exist."
      end
      cfg = YAML.load_file("#{INDEX_FILE_DIR}/public_stemcell_config.yml")
      [cfg["stemcells_index_id"], cfg["atmos_url"], cfg["expiration"],
       cfg["uid"], cfg["secret"]]
    end

    # Gets the public stemcell index file from the blobstore.
    # @param [Atmos::Store] store The atmos store.
    # @param [String] stemcells_index_id The object ID of the index file.
    # @return [Array] An array of the index file and it's YAML as a Hash.
    def get_index_file(store, stemcells_index_id)
      index_file = store.get(:id => decode_object_id(stemcells_index_id)["oid"])
      index_yaml = YAML.load(index_file.data)
      index_yaml = index_yaml.is_a?(Hash) ? index_yaml : {}
      [index_file, index_yaml]
    end

    # Changes all of the base shareable URLs in the index file.  E.x. if the
    # index file has www.vmware.com and the configuration file has 172.168.1.1
    # then it will all be changed to 172.168.1.1 urls.
    # @param [Hash] yaml The index file as a hash.
    # @param [String] url The new URL.
    # @return [Hash] The new YAML as a Hash.
    def change_all_urls(yaml, url)
      yaml.each do |filename, file_info|
        file_info["url"] = file_info["url"].sub(/(https?:\/\/[^\/]*)/, url)
      end
      yaml
    end

    # Updates the index file in the blobstore and locally with the most recent
    # changes.
    # @param [Hash] yaml The index file as a hash.
    # @param [String] url The new URL.
    def update_index_file(stemcell_index, yaml, url)
      yaml = change_all_urls(yaml, url)
      yaml_dump = YAML.dump(yaml)

      File.open("#{INDEX_FILE_DIR}/#{INDEX_FILE_NAME}", "w") do |f|
        f.write(yaml_dump)
      end

      stemcell_index.update(yaml_dump)
      puts("***Commit #{INDEX_FILE_DIR}/#{INDEX_FILE_NAME} to git repository " +
           "immediately.***")
    end

    # A helper function to get the shareable URL for an entry in the blobstore.
    # @param [String] oid The object ID.
    # @param [String] sig The signature.
    # @param [String] url The base url (e.g. www.vmware.com).
    # @param [String] exp The expiration as an epoch time stamp.
    # @param [String] uid The user id.
    # @return [String] The shareable URL.
    def get_shareable_url(oid, sig, url, exp, uid)
      return url + "/rest/objects/#{oid}?uid=#{uid}&expires=#{exp}&signature=" +
          "#{URI::escape(sig)}"
    end

    # Decodes the object ID.
    # @param [String] object_id The object ID.
    # @return [Hash] A hash with the oid and sig for the object_id.
    def decode_object_id(object_id)
      begin
        object_info = JSON.load(Base64.decode64(URI::unescape(object_id)))
      rescue JSON::ParserError => e
        raise "Failed to parse object_id '#{object_id}'"
      end

      if !object_info.kind_of?(Hash) || object_info["oid"].nil? ||
          object_info["sig"].nil?
        raise "Failed to parse object_id '#{object_id}'"
      end
      object_info
    end

    # Encodes an object ID with an expiration, uid and secret.
    # @param [String] object_id The object ID.
    # @param [String] exp The expiration as an epoch time stamp.
    # @param [String] uid The user id.
    # @param [String] secret The secret.
    # @return [String] The encoded object_id.
    def encode_object_id(object_id, exp, uid, secret)
      hash_string = "GET\n/rest/objects/#{object_id}\n#{uid}\n#{exp.to_s}"
      sig = HMAC::SHA1.digest(Base64.decode64(secret), hash_string)
      signature = Base64.encode64(sig.to_s).chomp
      URI::escape(Base64.encode64(JSON.dump(:oid => object_id,
                                            :sig => signature)))
    end

    INDEX_FILE_NAME = "public_stemcells_index.yml"
    INDEX_FILE_DIR = ".stemcell_builds"

    desc "Deletes <stemcell_name> from the public repository."
    task "delete", :stemcell_name do |t, args|
      stemcell_name = args[:stemcell_name]
      stemcells_index_id, url, expiration, uid, secret = load_stemcell_config

      store = Atmos::Store.new(:url => url, :uid => uid, :secret => secret)

      (index_file, index_yaml) = get_index_file(store, stemcells_index_id)

      unless index_yaml.has_key?(File.basename(stemcell_name))
        names = []
        index_yaml.each do |k, v|
          names << k
        end
        puts("Stemcell '#{stemcell_name}' is not in [#{names.join(', ')}]")
        return
      end

      if stemcell_name[INDEX_FILE_NAME]
        puts("Nice try knucklehead.  You can't delete this.'")
        return
      end

      encoded_id = index_yaml[stemcell_name]["object_id"]
      begin
        output = store.get(:id => decode_object_id(encoded_id)["oid"])
        output.delete
      rescue => e

      end
      index_yaml.delete(stemcell_name)
      update_index_file(index_file, index_yaml, url)
      puts("Deleted #{stemcell_name}.")
    end

    desc "Uploads <stemcell_path> to the public repository."
    task "upload", :stemcell_path do |t, args|
      stemcell_path = args[:stemcell_path]

      stemcells_index_id, url, expiration, uid, secret = load_stemcell_config

      store = Atmos::Store.new(:url => url, :uid => uid, :secret => secret)

      index_file, index_yaml = get_index_file(store, stemcells_index_id)

      stemcell = File.open(stemcell_path, "r")
      begin
        if is_update?(index_yaml, stemcell_path)
          entry = index_yaml[File.basename(stemcell_path)]
          key = entry["object_id"]
          output = store.get(:id => decode_object_id(key)["oid"])
          output.update(stemcell)
          puts("Updated #{stemcell_path}.")
        else
          output = store.create(:data => stemcell,
                                :length => File.size(stemcell_path))
          puts("Uploaded #{stemcell_path}.")
        end
        encoded_id = encode_object_id(output.aoid, expiration, uid, secret)
        object_info = decode_object_id(encoded_id)
        oid = object_info["oid"]
        sig = object_info["sig"]

        index_yaml[File.basename(stemcell_path)] = {
            "object_id" => encoded_id,
            "url" => get_shareable_url(oid, sig, url, expiration, uid),
            "sha" => Digest::SHA1.file(stemcell_path).hexdigest,
            "size" => File.size(stemcell_path)
        }

        update_index_file(index_file, index_yaml, url)
      ensure
        stemcell.close
      end
    end

    desc "Updates all stemcell's base URL with whatever is in " +
         "public_stemcell_config.yml."
    task "update_urls" do
      stemcells_index_id, url, expiration, uid, secret = load_stemcell_config

      store = Atmos::Store.new(:url => url, :uid => uid, :secret => secret)

      index_file, index_yaml = get_index_file(store, stemcells_index_id)

      update_index_file(index_file, index_yaml, url)
    end

    desc "Downloads the index file for debugging."
    task "download_index_file" do
      stemcells_index_id, url, expiration, uid, secret = load_stemcell_config

      store = Atmos::Store.new(:url => url, :uid => uid, :secret => secret)

      index_file, index_yaml = get_index_file(store, stemcells_index_id)

      File.open("#{INDEX_FILE_DIR}/#{INDEX_FILE_NAME}", "w") do |f|
        f.write(YAML.dump(index_yaml))
      end

      puts("Downloaded to #{INDEX_FILE_DIR}/#{INDEX_FILE_NAME}.")
    end

    desc "Uploads your local index file in case of emergency."
    task "upload_index_file" do
      if agree("Are you sure you want to upload your " +
          "public_stemcell_config.yml over the existing one?")
        yaml = YAML.load_file("#{INDEX_FILE_DIR}/#{INDEX_FILE_NAME}")
        stemcells_index_id, url, expiration, uid, secret = load_stemcell_config
        store = Atmos::Store.new(:url => url, :uid => uid, :secret => secret)
        index_file, index_yaml = get_index_file(store, stemcells_index_id)
        update_index_file(index_file, yaml, url)
      end
    end
  end
end
