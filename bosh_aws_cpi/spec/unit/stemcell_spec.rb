require 'spec_helper'

describe Bosh::AwsCloud::Stemcell do
  describe ".find" do
    it "should return an AMI if given an id for an existing one" do
      fake_aws_ami = double("image", exists?: true)
      region = double("region", images: {'ami-exists' => fake_aws_ami})
      expect(described_class.find(region, "ami-exists").ami).to eq(fake_aws_ami)
    end

    it "should raise an error if no AMI exists with the given id" do
      fake_aws_ami = double("image", exists?: false)
      region = double("region", images: {'ami-doesntexist' => fake_aws_ami})
      expect {
        described_class.find(region, "ami-doesntexist")
      }.to raise_error Bosh::Clouds::CloudError, "could not find AMI 'ami-doesntexist'"
    end
  end

  describe "#image_id" do
    let(:fake_aws_ami) { double("image", id: "my-id") }
    let(:region) { double("region") }

    it "returns the id of the ami object" do
      stemcell = described_class.new(region, fake_aws_ami)
      expect(stemcell.image_id).to eq('my-id')
    end
  end

  describe "#delete" do
    let(:fake_aws_ami) { double("image", exists?: true, id: "ami-xxxxxxxx") }
    let(:region) { double("region", images: {'ami-exists' => fake_aws_ami}) }

    context "with real stemcell" do
      it "should deregister the ami" do
        stemcell = described_class.new(region, fake_aws_ami)

        expect(stemcell).to receive(:memoize_snapshots).ordered
        expect(fake_aws_ami).to receive(:deregister).ordered
        allow(Bosh::AwsCloud::ResourceWait).to receive(:for_image).with(image: fake_aws_ami, state: :deleted)
        expect(stemcell).to receive(:delete_snapshots).ordered

        stemcell.delete
      end
    end

    context "with light stemcell" do
      it "should fake ami deregistration" do
        stemcell = described_class.new(region, fake_aws_ami)

        allow(stemcell).to receive(:memoize_snapshots)
        expect(fake_aws_ami).to receive(:deregister).and_raise(AWS::EC2::Errors::AuthFailure)
        expect(Bosh::AwsCloud::ResourceWait).not_to receive(:for_image)

        stemcell.delete
      end
      # AWS::EC2::Errors::AuthFailure
    end

    context 'when the AMI is not found after deletion' do
      it 'should not propagate a AWS::Core::Resource::NotFound error' do
        stemcell = described_class.new(region, fake_aws_ami)

        expect(stemcell).to receive(:memoize_snapshots).ordered
        expect(fake_aws_ami).to receive(:deregister).ordered
        resource_wait = double('Bosh::AwsCloud::ResourceWait')
        allow(Bosh::AwsCloud::ResourceWait).to receive_messages(new: resource_wait)
        allow(resource_wait).to receive(:for_resource).with(
          resource: fake_aws_ami, errors: [], target_state: :deleted, state_method: :state).and_raise(
          AWS::Core::Resource::NotFound)
        expect(stemcell).to receive(:delete_snapshots).ordered

        stemcell.delete
      end
    end
  end

  describe "#memoize_snapshots" do
    let(:fake_aws_object) { double("fake", :to_hash => {
        "/dev/foo" => {:snapshot_id => 'snap-xxxxxxxx'}
    })}
    let(:fake_aws_ami) do
      image = double("image", exists?: true, id: "ami-xxxxxxxx")
      expect(image).to receive(:block_device_mappings).and_return(fake_aws_object)
      image
    end
    let(:region) { double("region", images: {'ami-exists' => fake_aws_ami}) }

    it "should memoized the snapshots used by the AMI" do
      stemcell = described_class.new(region, fake_aws_ami)

      stemcell.memoize_snapshots

      expect(stemcell.snapshots).to eq(%w[snap-xxxxxxxx])
    end
  end

  describe "#delete_snapshots" do
    let(:fake_aws_ami) { double("image", exists?: true, id: "ami-xxxxxxxx") }
    let(:snapshot) { double('snapshot') }
    let(:region) do
      region = double("region")
      allow(region).to receive_messages(:images => {'ami-exists' => fake_aws_ami})
      allow(region).to receive_message_chain(:snapshots, :[]).and_return(snapshot)
      region
    end

    it "should delete all memoized snapshots" do
      stemcell = described_class.new(region, fake_aws_ami)
      allow(stemcell).to receive(:snapshots).and_return(%w[snap-xxxxxxxx])

      expect(snapshot).to receive(:delete)

      stemcell.delete_snapshots
    end
  end
end
