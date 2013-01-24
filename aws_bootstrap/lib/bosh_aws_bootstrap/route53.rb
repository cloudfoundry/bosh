require 'aws-sdk'
require 'uuidtools'

module Bosh
  module Aws
    class Route53

      def initialize(credentials)
        @credentials = credentials
      end

      def create_zone(zone)
        zone = "#{zone}." unless zone =~ /\.$/
        aws_route53.create_hosted_zone(:name => zone, :caller_reference => generate_unique_name)
        true
      end

      def delete_zone(zone)
        zone = "#{zone}." unless zone =~ /\.$/
        aws_route53.delete_hosted_zone(:id => get_zone_id(zone))
        true
      end

      def add_record(host, zone, addresses, options={})
        host = "\\052" if host == "*"
        zone = "#{zone}." unless zone =~ /\.$/
        addresses = [addresses] unless addresses.kind_of?(Array)
        type = options[:type] || "A"
        ttl = options[:ttl] || 3600
        aws_route53.change_resource_record_sets(
          hosted_zone_id: get_zone_id(zone),
          change_batch: {
            changes: [
              {
                action: "CREATE",
                resource_record_set: {
                  name: "#{host}.#{zone}",
                  type: type,
                  ttl: ttl,
                  resource_records: addresses.map {|address| { value: address} }
                }
              }
            ]
          }
        )
        true
      end

      def delete_record(host, zone, options={})
        host = "\\052" if host == "*"
        zone = "#{zone}." unless zone =~ /\.$/
        record_name = "#{host}.#{zone}"
        record_type = options[:type] || "A"

        zone_response = aws_route53.list_resource_record_sets(:hosted_zone_id => get_zone_id(zone))
        resource_record_set = zone_response.data[:resource_record_sets].find do |rr|
          rr[:name] == record_name && rr[:type] == record_type
        end

        unless resource_record_set
          raise "no #{record_type} record found for #{record_name}"
        end
        aws_route53.change_resource_record_sets(
          hosted_zone_id: get_zone_id(zone),
          change_batch: {
            changes: [
              {
                action: "DELETE",
                resource_record_set: resource_record_set
              }
            ]
          }
        )
        true
      end

      private

      def get_zone_id(name)
        zones_response = aws_route53.list_hosted_zones
        zone = zones_response.data[:hosted_zones].find { |zone| zone[:name] == name }
        zone[:id]
      end

      def aws_route53
        @aws_route53 ||= ::AWS::Route53.new(@credentials).client
      end

      def generate_unique_name
        ::UUIDTools::UUID.random_create.to_s
      end
    end
  end
end