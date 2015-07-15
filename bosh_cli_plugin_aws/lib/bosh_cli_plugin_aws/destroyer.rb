module Bosh::AwsCliPlugin
  class Destroyer
    def initialize(ui, config, rds_destroyer, vpc_destroyer)
      @ui = ui
      @credentials = config['aws']
      @rds_destroyer = rds_destroyer
      @vpc_destroyer = vpc_destroyer
    end

    def ensure_not_production!
      raise "#{ec2.instances_count} instance(s) running. This isn't a dev account (more than 20) please make sure you want to do this, aborting." if ec2.instances_count > 20
      raise "#{ec2.volume_count} volume(s) present. This isn't a dev account (more than 20) please make sure you want to do this, aborting."      if ec2.volume_count > 20
    end

    def delete_all_elbs
      elb = Bosh::AwsCliPlugin::ELB.new(@credentials)
      elb_names = elb.names
      if elb_names.any? && @ui.confirmed?("Are you sure you want to delete all ELBs (#{elb_names.join(', ')})?")
        elb.delete_elbs
      end
    end

    def delete_all_ec2
      formatted_names = ec2.instance_names.map { |id, name| "#{name} (id: #{id})" }

      unless formatted_names.empty?
        @ui.say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".make_red)
        @ui.say("Instances:\n\t#{formatted_names.join("\n\t")}")

        if @ui.confirmed?('Are you sure you want to terminate all terminatable EC2 instances and their associated non-persistent EBS volumes?')
          @ui.say('Terminating instances and waiting for them to die...')
          if !ec2.terminate_instances
            @ui.say('Warning: instances did not terminate yet after 100 retries'.make_red)
          end
        end
      else
        @ui.say('No EC2 instances found')
      end
    end

    def delete_all_ebs
      if ec2.volume_count > 0
        @ui.say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".make_red)
        @ui.say("It will delete #{ec2.volume_count} EBS volume(s)")

        if @ui.confirmed?('Are you sure you want to delete all unattached EBS volumes?')
          ec2.delete_volumes
        end
      else
        @ui.say('No EBS volumes found')
      end
    end

    def delete_all_rds
      @rds_destroyer.delete_all
    end

    def delete_all_s3
      s3 = Bosh::AwsCliPlugin::S3.new(@credentials)
      bucket_names = s3.bucket_names

      unless bucket_names.empty?
        @ui.say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".make_red)
        @ui.say("Buckets:\n\t#{bucket_names.join("\n\t")}")
        s3.empty if @ui.confirmed?('Are you sure you want to empty and delete all buckets?')
      else
        @ui.say('No S3 buckets found')
      end
    end

    def delete_all_vpcs
      @vpc_destroyer.delete_all
    end

    def delete_all_key_pairs
      if @ui.confirmed?('Are you sure you want to delete all SSH Keypairs?')
        @ui.say('Deleting all key pairs...')
        ec2.remove_all_key_pairs
      end
    end

    def delete_all_elastic_ips
      if @ui.confirmed?('Are you sure you want to delete all Elastic IPs?')
        @ui.say('Releasing all elastic IPs...')
        ec2.release_all_elastic_ips
      end
    end

    def delete_all_security_groups(wait_time=10)
      if @ui.confirmed?('Are you sure you want to delete all security groups?')
        retryable = Bosh::Retryable.new(sleep: wait_time, tries: 120, on: [::AWS::EC2::Errors::InvalidGroup::InUse])
        retryable.retryer do |tries, e|
          @ui.say("unable to delete security groups: #{e}") if tries > 0
          ec2.delete_all_security_groups
          true # retryable block must yield true if we only want to retry on Exceptions
        end
      end
    end

    def delete_all_route53_records
      @ui.say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".make_red)

      omit_types = @ui.options[:omit_types] || %w(NS SOA)
      if omit_types.empty?
        msg = 'Are you sure you want to delete all records from Route 53?'
      else
        msg = "Are you sure you want to delete all but #{omit_types.join('/')} records from Route 53?"
      end

      if @ui.confirmed?(msg)
        route53 = Bosh::AwsCliPlugin::Route53.new(@credentials)
        route53.delete_all_records(omit_types: omit_types)
      end
    end

    private

    def ec2
      @ec2 ||= Bosh::AwsCliPlugin::EC2.new(@credentials)
    end
  end
end
