module Bosh::Dev
  class StemcellVm
    def initialize(vm_name)
      @vm_name = vm_name
    end

    def run(cmd)
      Rake::FileUtilsExt.verbose(false)

      run_cmd = <<-BASH
        set -e

        pushd bosh-stemcell
        vagrant ssh -c "bash -l -c '#{cmd}'" #{vm_name}
        popd
      BASH
      Rake::FileUtilsExt.sh('bash', '-c', vagrant_up_cmd + run_cmd)
    ensure
      Rake::FileUtilsExt.sh('bash', '-c', vagrant_destroy_cmd)
    end

    private

    attr_reader :vm_name

    def provider
      case vm_name
        when 'remote' then 'aws'
        when 'local' then 'virtualbox'
        else raise "vm_name must be 'local' or 'remote'"
      end
    end

    def vagrant_up_cmd
      <<-BASH
        pushd bosh-stemcell
        [ -e .vagrant/machines/remote/aws/id ] && vagrant destroy #{vm_name} --force
        vagrant up #{vm_name} --provider #{provider}
        [ -e .vagrant/machines/remote/aws/id ] && cat .vagrant/machines/remote/aws/id
        popd
      BASH
    end

    def vagrant_destroy_cmd
      <<-BASH
        set -e

        pushd bosh-stemcell
        vagrant destroy #{vm_name} --force
        popd
      BASH
    end
  end
end
