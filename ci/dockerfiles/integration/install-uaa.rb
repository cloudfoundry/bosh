require 'yaml'
require 'json'
require 'fileutils'
require 'tmpdir'

uaa_archive_path = ARGV[0]

%w{
  /var/vcap/sys/run/uaa
  /var/vcap/sys/log/uaa
  /var/vcap/data/tmp
  /var/vcap/data/uaa
  /var/vcap/data/uaa/cert-cache
}.each {|path| FileUtils.mkdir_p path}

installed_uaa_job_path = File.join('/', 'var', 'vcap', 'jobs', 'uaa')

Dir.mktmpdir do |workspace|
  `tar xzf #{uaa_archive_path} -C #{workspace}`
  uaa_job_path = File.join(workspace, 'uaa')
  FileUtils.mkdir_p uaa_job_path
  `tar xzf #{File.join(workspace, 'jobs', 'uaa.tgz')} -C #{uaa_job_path}`
  uaa_job_spec_path = File.join(uaa_job_path, 'job.MF')
  job_spec = YAML.load_file(uaa_job_spec_path)
  job_spec['packages'].each do |package_name|
    package_path = File.join('/', 'var', 'vcap', 'packages', package_name)
    FileUtils.mkdir_p(package_path)
    `tar xzf #{File.join(workspace, 'compiled_packages', "#{package_name}.tgz")} -C #{package_path}`
  end
  context_path = File.join(workspace, 'context.json')
  context = {
    'default_properties' => job_spec['properties'].map { |key, value| [key, value['default']]}.to_h,
    'job_properties' => {
      'uaa' => {
        'allow_host_access': true,
        'debug_listen_address': '127.0.0.1:17013',
        'default_container_grace_time': '0',
        'destroy_containers_on_start': true,
        'graph_cleanup_threshold_in_mb': '0',
        'listen_address': '127.0.0.1:7777',
        'listen_network': 'tcp',
      }
    }
  }
  File.write(context_path, context.to_json)
  templates = job_spec['templates']
  templates.each do |src, dst|
    src_path = File.join(uaa_job_path, 'templates', src)
    dest_path = File.join(installed_uaa_job_path, dst)
    FileUtils.mkdir_p(File.dirname(dest_path))
    `ruby #{File.join(__dir__, 'template-renderer.rb')} #{context_path} #{src_path} #{dest_path}`
  end
end

`chmod +x #{File.join(installed_uaa_job_path, 'bin', '*')}`
