module Bosh::Dev
  class StemcellVm
    def initialize(options)
      @vm_name = options.fetch(:vm_name)
      @infrastructure_name = options.fetch(:infrastructure_name)
      @operating_system_name = options.fetch(:operating_system_name)
    end

    def publish
      Rake::FileUtilsExt.sh <<-BASH
        cd bosh-stemcell
        vagrant up #{vm_name} --provider #{provider}
        time vagrant ssh -c "
          set -eu
          cd /bosh
          bundle install --local

          #{exports.join("\n")}

          time bundle exec rake ci:publish_stemcell[#{infrastructure_name},#{operating_system_name}]
        " #{vm_name}
      BASH
    ensure
      Rake::FileUtilsExt.sh <<-BASH
        set -eu
        cd bosh-stemcell
        vagrant destroy #{vm_name} --force
      BASH
    end

    private

    attr_reader :vm_name, :infrastructure_name, :operating_system_name

    def provider
      vm_name == 'remote' ? 'aws' : 'virtualbox'
    end

    def exports
      env = ENV.to_hash
      required_exports = %w[
        CANDIDATE_BUILD_NUMBER
        BOSH_AWS_ACCESS_KEY_ID
        BOSH_AWS_SECRET_ACCESS_KEY
        AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT
        AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT
      ]

      optional_exports = %w[
        UBUNTU_ISO
      ]

      required_exports.map do |env_var|
        "export #{env_var}='#{env.fetch(env_var)}'"
      end + optional_exports.map do |env_var|
        "export #{env_var}='#{env.fetch(env_var)}'" if env[env_var]
      end
    end
  end
end
