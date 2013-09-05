require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Stemcell
  module StageCollection
    def self.for(infrastructure, operating_system)
      case infrastructure
        when Infrastructure::Aws then
          case operating_system
            when OperatingSystem::Ubuntu then AwsUbuntu.new
            else raise ArgumentError.new("'#{infrastructure.name}' does not support '#{operating_system.name}'")
          end
        when Infrastructure::OpenStack then
          case operating_system
            when OperatingSystem::Ubuntu then OpenstackUbuntu.new
            else raise ArgumentError.new("'#{infrastructure.name}' does not support '#{operating_system.name}'")
          end
        when Infrastructure::Vsphere then
          case operating_system
            when OperatingSystem::Centos then VsphereCentos.new
            when OperatingSystem::Ubuntu then VsphereUbuntu.new
          end
      end
    end

    class Base
      attr_reader :stages

      def initialize(options)
        @stages = options.fetch(:stages)
      end
    end

    class AwsUbuntu < Base
      STAGES = [
        # Setup base chroot
        :base_debootstrap,
        :base_apt,
        # Bosh steps
        :bosh_users,
        :bosh_debs,
        :bosh_monit,
        :bosh_ruby,
        :bosh_agent,
        :bosh_sysstat,
        :bosh_sysctl,
        :bosh_ntpdate,
        :bosh_sudoers,
        # Micro BOSH
        :bosh_micro,
        # Install GRUB/kernel/etc
        :system_grub,
        :system_kernel,
        # Misc
        :system_aws_network,
        :system_aws_clock,
        :system_aws_modules,
        :system_parameters,
        # Finalisation
        :bosh_clean,
        :bosh_harden,
        :bosh_harden_ssh,
        :bosh_tripwire,
        :bosh_dpkg_list,
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_aws_update_grub,
        :image_aws_prepare_stemcell,
        # Final stemcell
        :stemcell
      ]

      def initialize
        super(stages: STAGES)
      end
    end

    class OpenstackUbuntu < Base
      STAGES = [
        # Setup base chroot
        :base_debootstrap,
        :base_apt,
        # Bosh steps
        :bosh_users,
        :bosh_debs,
        :bosh_monit,
        :bosh_ruby,
        :bosh_agent,
        :bosh_sysstat,
        :bosh_sysctl,
        :bosh_ntpdate,
        :bosh_sudoers,
        # Micro BOSH
        :bosh_micro,
        # Install GRUB/kernel/etc
        :system_grub,
        :system_kernel,
        # Misc
        :system_openstack_network,
        :system_openstack_clock,
        :system_openstack_modules,
        :system_parameters,
        # Finalisation,
        :bosh_clean,
        :bosh_harden,
        :bosh_harden_ssh,
        :bosh_tripwire,
        :bosh_dpkg_list,
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_openstack_qcow2,
        :image_openstack_prepare_stemcell,
        # Final stemcell
        :stemcell_openstack
      ]

      def initialize
        super(stages: STAGES)
      end
    end

    class VsphereCentos < Base
      STAGES = [
        # Setup base chroot
        :base_centos,
        :base_yum,
        # Bosh steps
        :bosh_users,
        #:bosh_monit,
        #:bosh_ruby,
        #:bosh_agent,
        #:bosh_sysstat,
        #:bosh_sysctl,
        #:bosh_ntpdate,
        #:bosh_sudoers,
        # Micro BOSH
        #:bosh_micro,
        # Install GRUB/kernel/etc
        :system_grub,
        #:system_kernel,
        #:system_open_vm_tools,
        # Misc
        :system_parameters,
        # Finalisation
        :bosh_clean,
        #:bosh_harden,
        #:bosh_tripwire,
        #:bosh_dpkg_list,
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_vsphere_vmx,
        :image_vsphere_ovf,
        :image_vsphere_prepare_stemcell,
        # Final stemcell
        :stemcell
      ]

      def initialize
        super(stages: STAGES)
      end
    end

    class VsphereUbuntu < Base
      STAGES = [
        # Setup base chroot
        :base_debootstrap,
        :base_apt,
        # Bosh steps
        :bosh_users,
        :bosh_debs,
        :bosh_monit,
        :bosh_ruby,
        :bosh_agent,
        :bosh_sysstat,
        :bosh_sysctl,
        :bosh_ntpdate,
        :bosh_sudoers,
        # Micro BOSH
        :bosh_micro,
        # Install GRUB/kernel/etc
        :system_grub,
        :system_kernel,
        :system_open_vm_tools,
        # Misc
        :system_parameters,
        # Finalisation
        :bosh_clean,
        :bosh_harden,
        :bosh_tripwire,
        :bosh_dpkg_list,
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_vsphere_vmx,
        :image_vsphere_ovf,
        :image_vsphere_prepare_stemcell,
        # Final stemcell
        :stemcell
      ]

      def initialize
        super(stages: STAGES)
      end
    end
  end
end
