module Bosh::Director::Links
  class LinksParser
    class LinkConsumersParser
      include Bosh::Director::ValidationHelper

      def initialize
        @logger = Bosh::Director::Config.logger
        @link_helper = LinkHelpers.new
      end

      def parse_consumers_from_job(
        manifest_job_spec, deployment_model, current_release_template_model, instance_group_details = {}
      )
        instance_group_name = get_instance_group_name(deployment_model, manifest_job_spec, instance_group_details)
        @links_manager = Bosh::Director::Links::LinksManager.new(deployment_model.links_serial_id)

        consumes_links = Bosh::Director::DeepCopy.copy(safe_property(manifest_job_spec, 'consumes',
                                                                   class: Hash, optional: true, default: {}))
        job_name = safe_property(manifest_job_spec, 'name', class: String)

        errors = []
        unless current_release_template_model.consumes.empty?
          errors.concat(
            process_release_template_consumes(
              consumes_links,
              current_release_template_model,
              deployment_model,
              instance_group_name,
              job_name,
            ),
          )
        end

        unless consumes_links.empty?
          warning = 'Manifest defines unknown consumers:'
          consumes_links.each_key do |link_name|
            warning << "\n  - Job '#{job_name}' does not define link consumer '#{link_name}' in the release spec"
          end
          @logger.warn(warning)
        end

        raise errors.join("\n") unless errors.empty?
      end

      private

      def get_instance_group_name(deployment_model, manifest_job_spec, manifest_details)
        migrated_from = manifest_details.fetch(:migrated_from, [])

        migrated_from_instange_group = migrated_from.find do |migration_block|
          job_name = safe_property(manifest_job_spec, 'name', class: String)

          true if Bosh::Director::Models::Links::LinkConsumer.find(
            deployment: deployment_model,
            instance_group: migration_block['name'],
            name: job_name,
            type: 'job',
          )
        end

        return migrated_from_instange_group['name'] if migrated_from_instange_group

        manifest_details.fetch(:instance_group_name, nil)
      end

      def process_release_template_consumes(
        consumes_links, current_release_template_model, deployment_model, instance_group_name, job_name
      )
        consumer = @links_manager.find_or_create_consumer(
          deployment_model: deployment_model,
          instance_group_name: instance_group_name,
          name: job_name,
          type: 'job',
        )

        create_consumer_intent_from_template_model(
          consumer, consumes_links, current_release_template_model, instance_group_name, job_name
        )
      end

      def create_consumer_intent_from_template_model(
        consumer, consumes_links, current_release_template_model, instance_group_name, job_name
      )
        errors = []
        current_release_template_model.consumes.each do |consumes|
          metadata = {}
          consumer_intent_params = {
            'original_name' => consumes['name'],
            'alias' => consumes['name'],
            'blocked' => false,
            'type' => consumes['type'],
          }

          if !consumes_links.key?(consumes['name'])
            metadata['explicit_link'] = false
          else
            consumer_intent_params, metadata, err = generate_explicit_link_metadata(
              consumer,
              consumer_intent_params,
              consumes_links,
              metadata,
              consumed_link_original_name: consumes['name'],
              job_name: job_name,
              instance_group_name: instance_group_name,
            )
            unless err.empty?
              errors.concat(err)
              next
            end
          end

          create_consumer_intent(consumer, consumer_intent_params, consumes, metadata)
        end
        errors
      end

      def generate_explicit_link_metadata(
        consumer, consumer_intent_params, consumes_links, metadata, names = {}
      )
        consumed_link_original_name = names.fetch(:consumed_link_original_name, nil)
        job_name = names.fetch(:job_name, nil)
        instance_group_name = names.fetch(:instance_group_name, nil)

        errors = []
        manifest_source = consumes_links.delete(consumed_link_original_name)

        new_errors = @link_helper.validate_consume_link(
          manifest_source, consumed_link_original_name, job_name, instance_group_name
        )
        errors.concat(new_errors)
        return consumer_intent_params, metadata, errors unless new_errors.empty?

        metadata['explicit_link'] = true

        if manifest_source.eql? 'nil'
          consumer_intent_params['blocked'] = true
        elsif @link_helper.manual_link? manifest_source
          metadata['manual_link'] = true
          process_manual_link(consumer, consumer_intent_params, manifest_source)
        else
          consumer_intent_params['alias'] = manifest_source.fetch('from', consumer_intent_params['alias'])
          metadata['ip_addresses'] = manifest_source['ip_addresses'] if manifest_source.key?('ip_addresses')
          metadata['network'] = manifest_source['network'] if manifest_source.key?('network')
          validate_consumes_deployment(
            consumer_intent_params,
            errors,
            manifest_source,
            metadata,
            instance_group_name: instance_group_name,
            job_name: job_name,
          )
        end
        [consumer_intent_params, metadata, errors]
      end

      def validate_consumes_deployment(consumer_intent_params, errors, manifest_source, metadata, instance_group_details = {})
        return unless manifest_source['deployment']

        instance_group_name = instance_group_details.fetch(:instance_group_name, nil)
        job_name = instance_group_details.fetch(:job_name, nil)

        from_deployment = Bosh::Director::Models::Deployment.find(name: manifest_source['deployment'])
        metadata['from_deployment'] = manifest_source['deployment']

        from_deployment_error_message = "Link '#{consumer_intent_params['alias']}' in job '#{job_name}' from instance group"\
                  " '#{instance_group_name}' consumes from deployment '#{manifest_source['deployment']}',"\
                  ' but the deployment does not exist.'
        errors.push(from_deployment_error_message) unless from_deployment
      end

      def create_consumer_intent(consumer, consumer_intent_params, consumes, metadata)
        consumer_intent = @links_manager.find_or_create_consumer_intent(
          link_consumer: consumer,
          link_original_name: consumer_intent_params['original_name'],
          link_type: consumer_intent_params['type'],
          new_intent_metadata: metadata,
        )

        consumer_intent.name = consumer_intent_params['alias'].split('.')[-1]
        consumer_intent.blocked = consumer_intent_params['blocked']
        consumer_intent.optional = consumes['optional'] || false
        consumer_intent.save
      end

      def process_manual_link(consumer, consumer_intent_params, manifest_source)
        manual_provider = @links_manager.find_or_create_provider(
          deployment_model: consumer.deployment,
          instance_group_name: consumer.instance_group,
          name: consumer.name,
          type: 'manual',
        )

        manual_provider_intent = @links_manager.find_or_create_provider_intent(
          link_provider: manual_provider,
          link_original_name: consumer_intent_params['original_name'],
          link_type: consumer_intent_params['type'],
        )

        content = {}
        MANUAL_LINK_KEYS.each do |key|
          content[key] = manifest_source[key]
        end

        content['deployment_name'] = consumer.deployment.name

        manual_provider_intent.name = consumer_intent_params['original_name']
        manual_provider_intent.content = content.to_json
        manual_provider_intent.save
      end
    end
  end
end
