class CreateKeyPairs < Bosh::AwsCliPlugin::Migration
  def execute
    say "allocating #{config["key_pairs"].length} KeyPair(s)"
    config["key_pairs"].each do |name, path|
      ec2.force_add_key_pair(name, path)
    end
  end
end
