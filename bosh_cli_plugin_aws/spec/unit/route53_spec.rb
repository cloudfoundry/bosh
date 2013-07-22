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
    aws_r53 = double("aws_r53")
    r53.stub_chain(:aws_route53, :client).and_return(aws_r53)
    aws_r53.should_receive(:create_hosted_zone).with(name: "example.com.", caller_reference: unique_name)

    r53.create_zone("example.com")
  end

  it "can create a new A record in that zone" do
    zone_id = "???"
    r53.stub(:get_zone_id).with("example.com.").and_return(zone_id)

    aws_r53 = double("aws_r53")
    r53.stub_chain(:aws_route53, :client).and_return(aws_r53)
    aws_r53.should_receive(:change_resource_record_sets).with(resource_set("CREATE", "\\052", "example.com.", "10.0.22.5"))

    r53.add_record("*", "example.com", "10.0.22.5")
  end

  context "delete records" do
    it "can delete an A record from a zone" do
      zone_id = "???"
      r53.stub(:get_zone_id).with("example.com.").and_return(zone_id)
      fake_aws_response = double("aws_response")

      aws_r53 = double("aws_r53")
      r53.stub_chain(:aws_route53, :client).and_return(aws_r53)
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
      fake_aws_response = double("aws_response")

      aws_r53 = double("aws_r53")
      r53.stub_chain(:aws_route53, :client).and_return(aws_r53)
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

    context "delete all records" do
      let(:fake_ns_record) { double(AWS::Route53::ResourceRecordSet, type: 'NS') }
      let(:fake_soa_record) { double(AWS::Route53::ResourceRecordSet, type: 'SOA') }
      let(:fake_a_record) { double(AWS::Route53::ResourceRecordSet, type: 'A') }
      let(:fake_zone) { double(AWS::Route53::HostedZone, rrsets: [fake_ns_record, fake_soa_record, fake_a_record]) }
      let(:fake_aws_r53) { double(AWS::Route53) }

      before do
        r53.stub(:aws_route53).and_return(fake_aws_r53)
      end

      it "can delete all" do
        fake_aws_r53.should_receive(:hosted_zones).and_return([fake_zone])
        fake_zone.should_receive(:rrsets)
        fake_ns_record.should_receive(:delete)
        fake_soa_record.should_receive(:delete)
        fake_a_record.should_receive(:delete)

        r53.delete_all_records
      end

      it "can delete all except omissions" do
        fake_aws_r53.should_receive(:hosted_zones).and_return([fake_zone])
        fake_zone.should_receive(:rrsets)
        fake_ns_record.should_not_receive(:delete)
        fake_soa_record.should_not_receive(:delete)
        fake_a_record.should_receive(:delete)

        r53.delete_all_records(omit_types: %w[NS SOA])
      end
    end
  end

  it "can delete a hosted zone" do
    zone_id = "???"
    r53.stub(:get_zone_id).with("example.com.").and_return(zone_id)

    aws_r53 = double("aws_r53")
    r53.stub_chain(:aws_route53, :client).and_return(aws_r53)
    aws_r53.should_receive(:delete_hosted_zone).with(id: zone_id)

    r53.delete_zone("example.com")
  end

end