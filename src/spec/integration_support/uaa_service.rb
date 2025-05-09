require 'erb'
require 'fileutils'
require 'json'
require 'logging'
require 'tmpdir'
require 'yaml'

require 'bosh/common/template/evaluation_context'

require 'integration_support/constants'
require 'integration_support/service'

module IntegrationSupport
  class UaaService
    attr_reader :port

    COMPILED_UAA_RELEASE_PATH = '/usr/local/uaa.tgz'.freeze
    UAA_BIN_PATH = '/var/vcap/jobs/uaa/bin/'.freeze

    # Keys and Certs
    ROOT_CERT = File.join(IntegrationSupport::Constants::SANDBOX_CERTS_DIR, 'rootCA.pem')
    ROOT_KEY = File.join(IntegrationSupport::Constants::SANDBOX_CERTS_DIR, 'rootCA.key')
    SERVER_CERT = File.join(IntegrationSupport::Constants::SANDBOX_CERTS_DIR, 'server.crt')
    SERVER_KEY = File.join(IntegrationSupport::Constants::SANDBOX_CERTS_DIR, 'server.key')

    def initialize(uaa_root:)
      FileUtils.mkdir_p(uaa_root)

      @logger = Logging.logger(File.open(File.join(uaa_root, 'uaa_service.log'), 'w+'))

      @uaa_process = initialize_uaa_process(uaa_root, @logger)
    end

    def self.install(db_config:)
      return if File.exist?(File.join(UAA_BIN_PATH, 'uaa'))

      %w{
        /var/vcap/sys/run/uaa
        /var/vcap/sys/log/uaa
        /var/vcap/data/tmp
        /var/vcap/data/uaa
        /var/vcap/data/uaa/cert-cache
      }.each {|path| FileUtils.mkdir_p path}

      installed_uaa_job_path = File.join('/', 'var', 'vcap', 'jobs', 'uaa')

      Dir.mktmpdir do |workspace|
        `tar xzf #{COMPILED_UAA_RELEASE_PATH} -C #{workspace}`
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

        context = {
          'properties' => {
            'uaa' => {
              'sslCertificate' => File.read(SERVER_CERT),
              'sslPrivateKey' => File.read(SERVER_KEY)
            }
          }
        }

        job_spec['properties'].map do |properties_key, value|
          next unless value.has_key?('default')
          keys = properties_key.split('.')
          hash_segment = context['properties']
          keys.each_with_index do |key, index|
            if index == keys.length - 1
              hash_segment[key] ||= value['default']
            else
              hash_segment[key] ||= {}
            end
            hash_segment = hash_segment[key]
          end
        end

        context['properties'].deep_merge!(
          YAML.load_file(File.join(IntegrationSupport::Constants::BOSH_REPO_SRC_DIR, 'spec', 'assets', 'uaa_config', 'asymmetric', 'uaa.yml'))
        )

        context['properties']['uaadb'] = {
          'address' => db_config[:db_host],
          'databases' => [
            {
              'name' => 'uaa',
              'tag' => 'uaa'
            }
          ],
          'db_scheme' => db_config[:db_type],
          'port' => db_config[:db_port],
          'roles' => [
            {
              'tag' => 'admin',
              'name' => db_config[:db_user],
              'password' => db_config[:db_pass],
            }
          ],
          'tls' => 'enabled_skip_all_validation'
        }
        templates = job_spec['templates']
        templates.each do |src, dst|
          src_path = File.join(uaa_job_path, 'templates', src)
          dest_path = File.join(installed_uaa_job_path, dst)
          FileUtils.mkdir_p(File.dirname(dest_path))

          evaluation_context = Bosh::Common::Template::EvaluationContext.new(context, nil)
          template = ERB.new(File.read(src_path), trim_mode: "-")
          template_result = template.result(evaluation_context.get_binding)
          File.write(dest_path, template_result)
        end
      end

      `chmod +x #{File.join(installed_uaa_job_path, 'bin', '*')}`
    end

    def start
      system('useradd -ms /bin/bash vcap')
      system(File.join(UAA_BIN_PATH, 'pre-start')) || raise
      @uaa_process.start

      begin
        system(File.join(UAA_BIN_PATH, 'post-start')) || raise
      rescue StandardError
        output_service_log(@uaa_process.description, @uaa_process.stdout_contents, @uaa_process.stderr_contents)
        raise
      end
      @running_mode = @current_uaa_config_mode
    end

    def stop
      @uaa_process.stop
      @running_mode = 'stopped'
    end

    private

    def initialize_uaa_process(uaa_dir, logger)
      write_config_path(uaa_dir)

      opts = {
        'uaa.access_log_dir' => uaa_dir,
        'securerandom.source' => 'file:/dev/urandom',
      }

      catalina_opts = ' -Xms512M -Xmx512M '
      catalina_opts += opts.map { |key, value| "-D#{key}=#{value}" }.join(' ')

      Service.new(
        [File.join(UAA_BIN_PATH, 'uaa')],
        {
          working_dir: uaa_dir,
          output: File.join(uaa_dir, 'uaa.out'),
          env: {
            'CATALINA_OPTS' => catalina_opts,
            'CATALINA_BASE' => '/var/vcap/data/uaa/tomcat',
            'CATALINA_HOME' => '/var/vcap/data/uaa/tomcat',
            'CLOUDFOUNDRY_CONFIG_PATH' => '/var/vcap/jobs/uaa/config',
            'CLOUDFOUNDRY_LOG_PATH' => '/var/vcap/sys/log/uaa',
            'JAVA_HOME' => ''
          },
        },
        logger,
      )
    end

    def working_dir
      File.join(IntegrationSupport::Constants::BOSH_REPO_SRC_DIR, 'spec', 'assets', 'uaa')
    end

    def write_config_path(config_dir)
      FileUtils.cp(
        File.join(IntegrationSupport::Constants::BOSH_REPO_SRC_DIR, 'spec', 'assets', 'uaa_config', 'asymmetric', 'uaa.yml'),
        config_dir,
      )
      @current_uaa_config_mode = 'asymmetric'
    end

    DEBUG_HEADER = '*' * 20

    def output_service_log(description, stdout_contents, stderr_contents)
      @logger.error("#{DEBUG_HEADER} start #{description} stdout #{DEBUG_HEADER}")
      @logger.error(stdout_contents)
      @logger.error("#{DEBUG_HEADER} end #{description} stdout #{DEBUG_HEADER}")

      @logger.error("#{DEBUG_HEADER} start #{description} stderr #{DEBUG_HEADER}")
      @logger.error(stderr_contents)
      @logger.error("#{DEBUG_HEADER} end #{description} stderr #{DEBUG_HEADER}")
    end
  end
end
