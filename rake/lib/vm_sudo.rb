module Bosh
  class VmSudo < Struct.new(:vm, :gw_user, :gw_host)
    include Rake::FileUtilsExt

    def run(command)
      ip = `bosh vms | grep #{vm} | cut -d "|" -f 5 | cut -d "," -f 1`.strip

      sh %{ssh -A #{gw_user}@#{gw_host} 'ssh #{gw_user}@#{ip} -o StrictHostKeyChecking=no "echo c1oudc0w | sudo -S #{command}"'}
    end
  end
end
