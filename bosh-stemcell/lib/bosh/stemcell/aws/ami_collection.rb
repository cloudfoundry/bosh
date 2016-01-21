require 'cloud'
require 'bosh_aws_cpi'
require 'ostruct'
require 'yaml'
require 'rake'

module Bosh::Stemcell::Aws
  class AmiCollection
    MAX_COPY_IMAGE_WAIT_ATTEMPTS = 360

    attr_reader :stemcell

    def initialize(stemcell, regions, virtualization_type)
      @stemcell = stemcell
      @seed_region = regions.first
      @dest_regions = regions - [@seed_region]
      @virtualization_type = virtualization_type

      @access_key_id = ENV['BOSH_AWS_ACCESS_KEY_ID']
      @secret_access_key = ENV['BOSH_AWS_SECRET_ACCESS_KEY']
    end

    def publish
      logger = Logger.new('ami.log')
      cloud_config = OpenStruct.new(logger: logger, task_checkpoint: nil)
      Bosh::Clouds::Config.configure(cloud_config)
      cloud = Bosh::Clouds::Provider.create(cloud_options, 'fake-director-uuid')

      region_ami_mapping = {}
      @stemcell.extract do |tmp_dir, stemcell_manifest|
        cloud_properties = stemcell_manifest['cloud_properties'].merge(
          'virtualization_type' => @virtualization_type
        )

        seed_ami_id = nil
        Bosh::Retryable.new(tries: 3, sleep: 20, on: [Bosh::Clouds::CloudError]).retryer do
          seed_ami_id = cloud.create_stemcell("#{tmp_dir}/image", cloud_properties)
        end
        seed_ami = cloud.ec2.images[seed_ami_id]
        seed_ami.public = true
        region_ami_mapping = copy_to_regions(logger, seed_ami_id, seed_ami.name, seed_ami.tags)
        region_ami_mapping[@seed_region] = seed_ami_id
      end

      region_ami_mapping
    end

    private

    def copy_to_regions(logger, source_id, source_name, source_tags)
      threads = []
      mutex = Mutex.new
      region_ami_mapping = {}

      @dest_regions.each do |dest_region|
        threads << Thread.new do
          copied_ami_id = copy_to_region(logger, source_id, source_name, source_tags, @seed_region, dest_region)
          mutex.synchronize { region_ami_mapping[dest_region] = copied_ami_id }
        end
      end

      threads.each { |t| t.join }
      region_ami_mapping
    end

    def copy_to_region(logger, source_ami_id, source_ami_name, source_ami_tags, source_region, dest_region)
      logger.info "Copying AMI '#{source_ami_id}' from region '#{source_region}' to region '#{dest_region}'"

      client_options = {
        :access_key_id => @access_key_id,
        :secret_access_key => @secret_access_key,
        :region => dest_region
      }
      query_client = AWS::EC2::Client.new(client_options)
      ec2_client = AWS::EC2.new(client_options)

      copied_ami_id = copy_image(ec2_client, query_client, source_region, source_ami_id, source_ami_name)
      set_image_attributes(ec2_client, copied_ami_id, source_ami_tags)
      logger.info "Finished copying AMI '#{source_ami_id}' from region '#{source_region}'" +
          " to AMI '#{copied_ami_id}' in region '#{dest_region}'"

      copied_ami_id
    end

    def copy_image(ec2_client, query_client, source_region, source_ami_id, source_ami_name)
      copy_image_options = {
        source_region: source_region,
        source_image_id: source_ami_id,
        name: source_ami_name
      }

      copied_ami_id = query_client.copy_image(copy_image_options)[:image_id]
      # we have to wait for the image to be available in order to set attributes on it
      wait_for_ami_to_be_available(ec2_client, copied_ami_id)
      copied_ami_id
    end

    def set_image_attributes(ec2_client, ami_id, ami_tags)
      ami = ec2_client.images[ami_id]

      ami.public = true
      ami.add_tag('Name', :value => ami_tags['Name'])
    end

    def wait_for_ami_to_be_available(ec2, ami_id)
      # AMI is likely to be in state :pending or it may not be found (NotFound error).
      image_state = lambda {
        begin
          ec2.images[ami_id].state
        rescue AWS::EC2::Errors::InvalidAMIID::NotFound
          :not_found
        end
      }

      attempts = 0
      until image_state.call == :available
        if attempts > MAX_COPY_IMAGE_WAIT_ATTEMPTS
          raise "Timed out waiting for AMI '#{ami_id}' to reach 'available' state"
        end
        attempts += 1
        sleep(0.5*attempts)
      end
    end

    # At some point we should extract the logic in cloud.create_stemcell into a library which can be used here
    # it doesn't make a lot of sense to new up a set of options of the registry.
    def cloud_options
      {
        'plugin' => 'aws',
        'properties' => {
          'aws' => {
            'access_key_id' => @access_key_id,
            'secret_access_key' => @secret_access_key,
            'region' => @seed_region,
            'default_key_name' => 'fake'
          },
          'registry' => {
            'endpoint' => 'http://fake.registry',
            'user' => 'fake',
            'password' => 'fake'
          }
        }
      }
    end
  end
end
