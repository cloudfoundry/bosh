require 'bosh/cpi/compatibility_helpers'

module Bosh::Cpi::CompatibilityHelpers
  def it_can_delete_non_existent_vm(vm_cid='vm-cid')
    describe "delete_vm (deleting non existent vm)" do
      context "when VM is not present" do
        it "raises VMNotFound error" do
          expect {
            cpi.delete_vm(vm_cid)
          }.to raise_error(Bosh::Clouds::VMNotFound, "VM '#{vm_cid}' not found")
        end
      end
    end
  end
end
