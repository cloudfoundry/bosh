# Copyright (c) 2009-2012 VMware, Inc.

require 'bosh_agent'
require 'rbconfig'
require 'atmos'
require 'json'
require 'rugged'


namespace :stemcell do
  desc 'Build stemcell'
  task :basic, [:infrastructure, :version, :disk_size] do |t, args|
    options = default_options(args)
    options[:stemcell_name] ||= 'bosh-stemcell'
    options[:stemcell_version] ||= Bosh::Agent::VERSION

    if args[:version]
      options[:stemcell_version] = args[:version]
    end

    Rake::Task['all:finalize_release_directory'].invoke

    build("stemcell-#{args[:infrastructure]}", options)
  end

  desc 'Build micro bosh stemcell'
  task :micro, [:tarball, :infrastructure, :version, :disk_size] do |t, args|
    require 'bosh/dev/micro_bosh_release'

    manifest =
      File.join(
        File.expand_path(
          File.dirname(__FILE__)
        ), '..', '..', '..', '..', '..', 'release', 'micro', "#{args[:infrastructure]}.yml"
      )


    options = default_options(args)
    options[:stemcell_version] = args[:version] || micro_version
    if args[:tarball]
      release_tarball = args[:tarball]
      pipeline = Bosh::Dev::Pipeline.new
      options[:agent_gem_src_url] = pipeline.gems_dir_url
    else
      Rake::Task['all:finalize_release_directory'].invoke
      release = Bosh::Dev::MicroBoshRelease.new
      release_tarball = release.tarball
    end

    options[:stemcell_name] ||= 'micro-bosh-stemcell'

    options = options.merge(bosh_micro_options(manifest, release_tarball))
    options[:non_interactive] = true

    build("stemcell-#{args[:infrastructure]}", options)
  end

  desc 'Build Micro Cloud Foundry'
  task :mcf, [:infrastructure, :manifest, :tarball, :micro_src] => 'all:finalize_release_directory' do |t, args|
    options = default_options(args)
    options[:stemcell_name] ||= 'mcf-stemcell'
    options[:stemcell_version] ||= Bosh::Agent::VERSION
    options[:image_create_disk_size] = 16384
    options[:build_time] = ENV['BUILD_TIME'] || Time.now.strftime('%Y%m%d.%H%M%S')
    options[:version] = ENV['MCF_VERSION'] || "9.9.9_#{options[:build_time]}"
    options[:bosh_users_password] = 'micr0cloud'

    options = options.merge(bosh_micro_options(args[:manifest], args[:tarball]))
    options[:mcf_enabled] = 'yes'
    options[:micro_src] = args[:micro_src]

    build('stemcell-mcf', options)
  end

  namespace :public do

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

        if entry['sha'] == Digest::SHA1.file(stemcell_path).hexdigest
          puts('No action taken, files are identical.')
          exit(0)
        end

        if agree('Stemcell already uploaded.  Do you want to overwrite it? [yn]')
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
      cfg = Psych.load_file("#{INDEX_FILE_DIR}/public_stemcell_config.yml")

      [cfg['stemcells_index_id'], cfg['atmos_url'], cfg['expiration'], cfg['uid'], cfg['secret']]
    end

    # Gets the public stemcell index file from the blobstore.
    # @param [Atmos::Store] store The atmos store.
    # @param [String] stemcells_index_id The object ID of the index file.
    # @return [Array] An array of the index file and it's YAML as a Hash.
    def get_index_file(store, stemcells_index_id)
      index_file = store.get(:id => decode_object_id(stemcells_index_id)['oid'])
      index_yaml = Psych.load(index_file.data)
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
        file_info['url'] = file_info['url'].sub(/(https?:\/\/[^\/]*)/, url)
      end
      yaml
    end

    # Updates the index file in the blobstore and locally with the most recent
    # changes.
    # @param [Hash] yaml The index file as a hash.
    # @param [String] url The new URL.
    def update_index_file(stemcell_index, yaml, url)
      yaml = change_all_urls(yaml, url)
      yaml_dump = Psych.dump(yaml)

      File.open("#{INDEX_FILE_DIR}/#{INDEX_FILE_NAME}", 'w') do |f|
        f.write(yaml_dump)
      end

      stemcell_index.update(yaml_dump)
      puts("***Commit #{INDEX_FILE_DIR}/#{INDEX_FILE_NAME} to git repository immediately.***")
    end

    # A helper function to get the shareable URL for an entry in the blobstore.
    # @param [String] oid The object ID.
    # @param [String] sig The signature.
    # @param [String] url The base url (e.g. www.vmware.com).
    # @param [String] exp The expiration as an epoch time stamp.
    # @param [String] uid The user id.
    # @return [String] The shareable URL.
    def get_shareable_url(oid, sig, url, exp, uid)
      return url + "/rest/objects/#{oid}?uid=#{uid}&expires=#{exp}&signature=#{URI::escape(sig)}"
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

      if !object_info.kind_of?(Hash) || object_info['oid'].nil? || object_info['sig'].nil?
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
      URI::escape(Base64.encode64(JSON.dump(oid: object_id, sig: signature)))
    end

    INDEX_FILE_NAME = 'public_stemcells_index.yml'
    INDEX_FILE_DIR = 'stemcell_builder/.stemcell_builds'

    desc 'Deletes <stemcell_name> from the public repository.'
    task :delete, :stemcell_name do |t, args|
      stemcell_name = args[:stemcell_name]
      stemcells_index_id, url, expiration, uid, secret = load_stemcell_config

      store = Atmos::Store.new(url: url, uid: uid, secret: secret)

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

      encoded_id = index_yaml[stemcell_name]['object_id']
      begin
        output = store.get(:id => decode_object_id(encoded_id)['oid'])
        output.delete
      rescue => e

      end

      index_yaml.delete(stemcell_name)
      update_index_file(index_file, index_yaml, url)
      puts("Deleted #{stemcell_name}.")
    end

    desc 'Uploads <stemcell_path> to the public repository with optional space-separated tags.'
    task :upload, :stemcell_path, :tags do |t, args|
      stemcell_path = args[:stemcell_path]
      tags = args[:tags]
      tags = tags ? tags.downcase.split(' ') : []
      stemcells_index_id, url, expiration, uid, secret = load_stemcell_config

      store = Atmos::Store.new(url: url, uid: uid, secret: secret)
      index_file, index_yaml = get_index_file(store, stemcells_index_id)

      stemcell = File.open(stemcell_path, 'r')
      begin
        if is_update?(index_yaml, stemcell_path)
          entry = index_yaml[File.basename(stemcell_path)]
          key = entry['object_id']
          output = store.get(id: decode_object_id(key)['oid'])
          output.update(stemcell)
          puts("Updated #{stemcell_path}.")
        else
          output = store.create(data: stemcell, length: File.size(stemcell_path))
          puts("Uploaded #{stemcell_path}.")
        end
        encoded_id = encode_object_id(output.aoid, expiration, uid, secret)
        object_info = decode_object_id(encoded_id)
        oid = object_info['oid']
        sig = object_info['sig']

        index_yaml[File.basename(stemcell_path)] = {
          'object_id' => encoded_id,
          'url' => get_shareable_url(oid, sig, url, expiration, uid),
          'sha' => Digest::SHA1.file(stemcell_path).hexdigest,
          'size' => File.size(stemcell_path),
          'tags' => tags
        }
        update_index_file(index_file, index_yaml, url)
      ensure
        stemcell.close
      end
    end

    desc 'Sets the tags (space-separated) for a stemcell.'
    task :set_stemcell_tags, :stemcell_name, :tags do |t, args|
      stemcell_name = args[:stemcell_name]
      tags = args[:tags]
      tags = tags ? tags.downcase.split(' ') : []
      stemcells_index_id, url, expiration, uid, secret = load_stemcell_config

      store = Atmos::Store.new(url: url, uid: uid, secret: secret)

      index_file, index_yaml = get_index_file(store, stemcells_index_id)
      index_yaml[stemcell_name]['tags'] = tags
      update_index_file(index_file, index_yaml, url)
    end

    desc 'Uploads a new index file so dev can be done without modifying the public stemcell index file.'
    task :upload_dev_index, :index_path do |t, args|
      index_path = args[:index_path]
      unless File.exists?(index_path)
        raise "Index file at '#{index_path}' not found."
      end

      stemcells_index_id, url, expiration, uid, secret = load_stemcell_config
      index_file = File.open(index_path, 'r')
      store = Atmos::Store.new(url: url, uid: uid, secret: secret)
      output = store.create(data: index_file, length: File.size(index_path))
      puts("Uploaded #{index_path}.")

      encoded_id = encode_object_id(output.aoid, expiration, uid, secret)
      object_info = decode_object_id(encoded_id)
      puts("Put '#{encoded_id}' in '#{INDEX_FILE_DIR}/#{INDEX_FILE_NAME}' as stemcells_index_id.")

      oid = object_info['oid']
      sig = object_info['sig']
      share_url = get_shareable_url(oid, sig, url, expiration, uid)
      puts("The public URL for use in BOSH CLI is '#{share_url}'.")
    end

    desc "Updates all stemcell's base URL with whatever is in public_stemcell_config.yml."
    task :update_urls do
      stemcells_index_id, url, expiration, uid, secret = load_stemcell_config

      store = Atmos::Store.new(url: url, uid: uid, secret: secret)

      index_file, index_yaml = get_index_file(store, stemcells_index_id)

      update_index_file(index_file, index_yaml, url)
    end

    desc 'Downloads the index file for debugging.'
    task :download_index_file do
      stemcells_index_id, url, expiration, uid, secret = load_stemcell_config

      store = Atmos::Store.new(url: url, uid: uid, secret: secret)

      index_file, index_yaml = get_index_file(store, stemcells_index_id)

      File.open("#{INDEX_FILE_DIR}/#{INDEX_FILE_NAME}", 'w') do |f|
        f.write(Psych.dump(index_yaml))
      end

      puts("Downloaded to #{INDEX_FILE_DIR}/#{INDEX_FILE_NAME}.")
    end

    desc 'Uploads your local index file in case of emergency.'
    task :upload_index_file do
      if agree('Are you sure you want to upload your public_stemcell_config.yml over the existing one?')
        yaml = Psych.load_file("#{INDEX_FILE_DIR}/#{INDEX_FILE_NAME}")

        stemcells_index_id, url, expiration, uid, secret = load_stemcell_config

        store = Atmos::Store.new(url: url, uid: uid, secret: secret)
        index_file, index_yaml = get_index_file(store, stemcells_index_id)

        update_index_file(index_file, yaml, url)
      end
    end
  end

  # microBOSH version should reflect the version of all the BOSH components, not just the agent.
  def micro_version
    @micro_version ||= File.read("#{File.expand_path('../../../../../../', __FILE__)}/BOSH_VERSION").strip
  end

  def changes_in_bosh_agent?
    gem_components_changed?('bosh_agent') || component_changed?('stemcell_builder')
  end

  def changes_in_microbosh?
    microbosh_components = COMPONENTS - %w(bosh_cli bosh_cli_plugin_aws bosh_cli_plugin_micro)
    components_changed = microbosh_components.inject(false) do |changes, component|
      changes || gem_components_changed?(component)
    end
    components_changed || component_changed?('stemcell_builder')
  end

  def diff
    @diff ||= changed_components
  end

  def changed_components(new_commit_sha=ENV['GIT_COMMIT'], old_commit_sha=ENV['GIT_PREVIOUS_COMMIT'])
    repo = Rugged::Repository.new('.')
    old_trees = old_commit_sha ? repo.lookup(old_commit_sha).tree.to_a : []
    new_trees = repo.lookup(new_commit_sha || repo.head.target).tree.to_a
    (new_trees - old_trees).map { |entry| entry[:name] }
  end

  def component_changed?(path)
    diff.include?(path)
  end

  def gem_components_changed?(gem_name)
    gem = Gem::Specification.load(File.join(gem_name, "#{gem_name}.gemspec"))

    components =
      %w(Gemfile Gemfile.lock) + [gem_name] + gem.runtime_dependencies.map { |d| d.name }.select { |d| Dir.exists?(d) }

    components.inject(false) do |changes, component|
      changes || component_changed?(component)
    end
  end

  def default_options(args)
    infrastructure = args[:infrastructure]
    unless infrastructure
      STDERR.puts 'Please specify target infrastructure (vsphere, aws, openstack)'
      exit 1
    end

    options = {
      system_parameters_infrastructure: infrastructure,
      stemcell_name: ENV['STEMCELL_NAME'],
      stemcell_version: ENV['STEMCELL_VERSION'],
      stemcell_infrastructure: infrastructure,
      stemcell_hypervisor: get_hypervisor(infrastructure),
      bosh_protocol_version: Bosh::Agent::BOSH_PROTOCOL,
      UBUNTU_ISO: ENV['UBUNTU_ISO'],
      UBUNTU_MIRROR: ENV['UBUNTU_MIRROR'],
      TW_LOCAL_PASSPHRASE: ENV['TW_LOCAL_PASSPHRASE'],
      TW_SITE_PASSPHRASE: ENV['TW_SITE_PASSPHRASE'],
      ruby_bin: ENV['RUBY_BIN'] || File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']),
      bosh_release_src_dir: File.expand_path('../../../../../../release/src/bosh', __FILE__),
      bosh_agent_src_dir: File.expand_path('../../../../../../bosh_agent', __FILE__),
      mcf_enabled: 'no',
      image_create_disk_size: (args[:disk_size] || 2048).to_i
    }

    case infrastructure
      when 'vsphere'
        # Pass OVFTOOL environment variable when targeting vsphere
        options[:image_vsphere_ovf_ovftool_path] = ENV['OVFTOOL']
      when 'openstack'
        # Increase the disk size to 10Gb to deal with flavors that doesn't have ephemeral disk
        options[:image_create_disk_size] = 10240 unless args[:disk_size]
    end

    options
  end

  def bosh_micro_options(manifest, tarball)
    {
      bosh_micro_enabled: 'yes',
      bosh_micro_package_compiler_path: File.expand_path('../../../../../../package_compiler', __FILE__),
      bosh_micro_manifest_yml_path: manifest,
      bosh_micro_release_tgz_path: tarball,
    }
  end

  def get_working_dir
    ENV['BUILD_PATH'] || "/var/tmp/bosh/bosh_agent-#{Bosh::Agent::VERSION}-#{$$}"
  end

  def get_hypervisor(infrastructure)
    return ENV['STEMCELL_HYPERVISOR'] if ENV['STEMCELL_HYPERVISOR']

    case infrastructure
      when 'vsphere'
        hypervisor = 'esxi'
      when 'aws'
        hypervisor = 'xen'
      when 'openstack'
        hypervisor = 'kvm'
      else
        raise "Unknown infrastructure: #{infrastructure}"
    end
    hypervisor
  end

  def env
    keep = %w{
      HTTP_PROXY
      http_proxy
      NO_PROXY
      no_proxy
      }

    format_env(ENV.select { |k| keep.include?(k) })
  end

  # Format a hash as an env command.
  def format_env(h)
    'env ' + h.map { |k, v| "#{k}='#{v}'" }.join(' ')
  end

  def build(spec, options)
    root = get_working_dir
    mkdir_p root
    puts "MADE ROOT: #{root}"
    puts "PWD: #{Dir.pwd}"

    build_path = File.join(root, 'build')

    rm_rf "#{build_path}"
    mkdir_p build_path
    stemcell_build_dir = File.expand_path('../../../../../../stemcell_builder', __FILE__)
    cp_r Dir.glob("#{stemcell_build_dir}/*"), build_path, preserve: true

    work_path = ENV['WORK_PATH'] || File.join(root, 'work')
    mkdir_p work_path

    # Apply options
    settings_path = File.join(build_path, 'etc', 'settings.bash')
    File.open(settings_path, 'a') do |f|
      f.print "\n# %s\n\n" % ['=' * 20]
      options.each do |k, v|
        f.print "#{k}=#{v}\n"
      end
    end

    builder_path = File.join(build_path, 'bin', 'build_from_spec.sh')
    spec_path = File.join(build_path, 'spec', "#{spec}.spec")

    # Run builder
    STDOUT.puts "building in #{work_path}..."
    cmd = "sudo #{env} #{builder_path} #{work_path} #{spec_path} #{settings_path}"

    puts cmd
    sh(cmd)
  end
end
