module Bosh::Deployer::Models
  def self.define_instance_from_table(table)
    return if const_defined?(:Instance)
    klass = Class.new(Sequel.Model(table))
    const_set(:Instance, klass)
  end
end
