require 'spec_helper'

describe Bosh::AwsCliPlugin::Route53 do
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
    expect(r53).to receive(:generate_unique_name).and_return(unique_name)
    aws_r53 = double("aws_r53")
    allow(r53).to receive_message_chain(:aws_route53, :client).and_return(aws_r53)
    expect(aws_r53).to receive(:create_hosted_zone).with(name: "example.com.", caller_reference: unique_name)

    r53.create_zone("example.com")
  end

  it "can create a new A record in that zone" do
    zone_id = "???"
    allow(r53).to receive(:get_zone_id).with("example.com.").and_return(zone_id)

    aws_r53 = double("aws_r53")
    allow(r53).to receive_message_chain(:aws_route53, :client).and_return(aws_r53)
    expect(aws_r53).to receive(:change_resource_record_sets).with(resource_set("CREATE", "\\052", "example.com.", "10.0.22.5"))

    r53.add_record("*", "example.com", "10.0.22.5")
  end

  context "delete records" do
    it "can delete an A record from a zone" do
      zone_id = "???"
      allow(r53).to receive(:get_zone_id).with("example.com.").and_return(zone_id)
      fake_aws_response = double("aws_response")

      aws_r53 = double("aws_r53")
      allow(r53).to receive_message_chain(:aws_route53, :client).and_return(aws_r53)
      expect(aws_r53).to receive(:change_resource_record_sets).
          with(resource_set("DELETE", "\\052", "example.com.", "10.0.22.5"))
      expect(aws_r53).to receive(:list_resource_record_sets).
          with(:hosted_zone_id => "???").and_return(fake_aws_response)
      allow(fake_aws_response).to receive(:data).and_return(
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
      allow(r53).to receive(:get_zone_id).with("example.com.").and_return(zone_id)
      fake_aws_response = double("aws_response")

      aws_r53 = double("aws_r53")
      allow(r53).to receive_message_chain(:aws_route53, :client).and_return(aws_r53)
      allow(aws_r53).to receive(:list_resource_record_sets).
          with(:hosted_zone_id => "???").and_return(fake_aws_response)
      allow(fake_aws_response).to receive(:data).and_return(
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
        allow(r53).to receive(:aws_route53).and_return(fake_aws_r53)
      end

      it "can delete all" do
        expect(fake_aws_r53).to receive(:hosted_zones).and_return([fake_zone])
        expect(fake_zone).to receive(:rrsets)
        expect(fake_ns_record).to receive(:delete)
        expect(fake_soa_record).to receive(:delete)
        expect(fake_a_record).to receive(:delete)

        r53.delete_all_records
      end

      it "can delete all except omissions" do
        expect(fake_aws_r53).to receive(:hosted_zones).and_return([fake_zone])
        expect(fake_zone).to receive(:rrsets)
        expect(fake_ns_record).not_to receive(:delete)
        expect(fake_soa_record).not_to receive(:delete)
        expect(fake_a_record).to receive(:delete)

        r53.delete_all_records(omit_types: %w[NS SOA])
      end
    end
  end

  it "can delete a hosted zone" do
    zone_id = "???"
    allow(r53).to receive(:get_zone_id).with("example.com.").and_return(zone_id)

    aws_r53 = double("aws_r53")
    allow(r53).to receive_message_chain(:aws_route53, :client).and_return(aws_r53)
    expect(aws_r53).to receive(:delete_hosted_zone).with(id: zone_id)

    r53.delete_zone("example.com")
  end

end
