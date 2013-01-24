require 'spec_helper'

describe Bosh::Aws::Route53 do
  let(:r53) { described_class.new({}) }

  def resource_set(action, host, zone, address)
    { hosted_zone_id: "???",
      change_batch: {
        changes: [
          {
            action: action,
            resource_record_set: {
              name: "#{host}.#{zone}",
              type: "A",
              ttl: 3600,
              resource_records: [
                { value: address }
              ]
            }
          }
        ]
      }
    }
  end

  it "can create a new hosted zone" do
    unique_name = "xxx-yyy-zzz-111"
    r53.should_receive(:generate_unique_name).and_return(unique_name)
    aws_r53 = mock("aws_r53")
    r53.stub(:aws_route53).and_return(aws_r53)
    aws_r53.should_receive(:create_hosted_zone).with(name: "example.com.", caller_reference: unique_name)

    r53.create_zone("example.com")
  end

  it "can create a new A record in that zone" do
    zone_id = "???"
    r53.stub(:get_zone_id).with("example.com.").and_return(zone_id)

    aws_r53 = mock("aws_r53")
    r53.stub(:aws_route53).and_return(aws_r53)
    aws_r53.should_receive(:change_resource_record_sets).with(resource_set("CREATE", "\\052", "example.com.", "10.0.22.5"))

    r53.add_record("*", "example.com", "10.0.22.5")
  end

  context "delete record" do
    it "can delete an A record from a zone" do
      zone_id = "???"
      r53.stub(:get_zone_id).with("example.com.").and_return(zone_id)
      fake_aws_response = mock("aws_response")

      aws_r53 = mock("aws_r53")
      r53.stub(:aws_route53).and_return(aws_r53)
      aws_r53.should_receive(:change_resource_record_sets).
          with(resource_set("DELETE", "\\052", "example.com.", "10.0.22.5"))
      aws_r53.should_receive(:list_resource_record_sets).
          with(:hosted_zone_id => "???").and_return(fake_aws_response)
      fake_aws_response.stub(:data).and_return(
        resource_record_sets: [{
          name: "\\052.example.com.",
          type: "A",
          ttl: 3600,
          resource_records: [{
            value: "10.0.22.5"
          }]
        }]
      )

      r53.delete_record("*", "example.com")
    end

    it "throws an error when it can't find the record to delete" do
      zone_id = "???"
      r53.stub(:get_zone_id).with("example.com.").and_return(zone_id)
      fake_aws_response = mock("aws_response")

      aws_r53 = mock("aws_r53")
      r53.stub(:aws_route53).and_return(aws_r53)
      aws_r53.stub(:list_resource_record_sets).
          with(:hosted_zone_id => "???").and_return(fake_aws_response)
      fake_aws_response.stub(:data).and_return(
        resource_record_sets: [{
          name: "\\052.foobar.org.",
          type: "A",
          ttl: 3600,
          resource_records: [{
            value: "172.111.222.333"
        }]
       }]
      )
      expect {
        r53.delete_record("*", "example.com")
      }.to raise_error("no A record found for \\052.example.com.")
    end
  end
  it "can delete a hosted zone" do
    zone_id = "???"
    r53.stub(:get_zone_id).with("example.com.").and_return(zone_id)

    aws_r53 = mock("aws_r53")
    r53.stub(:aws_route53).and_return(aws_r53)
    aws_r53.should_receive(:delete_hosted_zone).with(id: zone_id)

    r53.delete_zone("example.com")
  end
end