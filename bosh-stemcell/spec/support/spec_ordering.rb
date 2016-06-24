
RSpec.configure do |config|
  config.register_ordering(:global) do |list|
    # make sure that stig test case check will be run at last
    list.each do |example_group|
      if example_group.metadata[:security_spec]
        list.delete example_group
        list.push example_group
      end
    end
    list
  end
end
