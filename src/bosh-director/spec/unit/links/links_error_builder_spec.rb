require 'spec_helper'

describe Bosh::Director::Links::LinksErrorBuilder do
  let(:subject) { Bosh::Director::Links::LinksErrorBuilder }

  def self.it_considers_number_of_link_providers
    context 'when the number of providers is > 1' do
      it 'should return an error message about the number of provider (ambiguous providers)' do
        link_provider = Bosh::Director::Models::Links::LinkProvider.create(
          deployment: deployment,
          instance_group: 'ig_name',
          name: 'ig_name',
          type: 'disk',
        )

        Bosh::Director::Models::Links::LinkProviderIntent.create(
          link_provider: link_provider,
          original_name: 'my_custom_disk_orig',
          name: 'my_custom_disk', # We set it differently to test that it's using the original.
          type: 'disk',
        )

        Bosh::Director::Models::Links::LinkProviderIntent.create(
          link_provider: link_provider,
          original_name: 'my_custom_disk_orig2',
          name: 'my_custom_disk2', # We set it differently to test that it's using the original.
          type: 'disk2',
        )
      end
    end
  end

  # rubocop:disable Metrics/MethodLength
  def self.it_populates_the_error_details_correctly
    context 'when there are no providers' do
      it 'should return an error message detailing that it could not find any providers' do
        error = subject.build_link_error(link_consumer_intent, [])
        expect(error).to match(/No link providers found/)
      end
    end

    context 'when the provider is a disk' do
      let(:link_provider) do
        Bosh::Director::Models::Links::LinkProvider.create(
          deployment: deployment,
          instance_group: 'ig_name',
          name: 'ig_name',
          type: 'disk',
        )
      end
      let(:link_provider_intent) do
        Bosh::Director::Models::Links::LinkProviderIntent.create(
          link_provider: link_provider,
          original_name: 'my_custom_disk_orig',
          name: 'my_custom_disk', # We set it differently to test that it's using the original.
          type: 'disk',
        )
      end

      it 'should return a disk specific error message' do
        error = subject.build_link_error(link_consumer_intent, [link_provider_intent])
        expect(error).to match("Disk link provider '#{link_provider_intent.original_name}'"\
                                 " from instance group '#{link_provider.instance_group}'")
        expect(error).to_not match(/contain any networks/)
      end

      context 'and a network is specified' do
        it 'should return a variable specific error message' do
          error = subject.build_link_error(link_consumer_intent, [link_provider_intent], 'foobar')
          expect(error).to match("Disk link provider '#{link_provider_intent.original_name}'"\
                                   " from instance group '#{link_provider.instance_group}'"\
                                   ' does not contain any networks')
        end
      end
    end

    context 'when the provider is a variable' do
      let(:link_provider) do
        Bosh::Director::Models::Links::LinkProvider.create(
          deployment: deployment,
          instance_group: 'ig_name',
          name: 'variable_name',
          type: 'variable',
        )
      end
      let(:link_provider_intent) do
        Bosh::Director::Models::Links::LinkProviderIntent.create(
          link_provider: link_provider,
          original_name: 'certificate_name',
          name: 'certificate_name_alias',
          type: 'certificate',
        )
      end

      it 'should return a variable specific error message' do
        error = subject.build_link_error(link_consumer_intent, [link_provider_intent])
        expect(error).to include("Link provider '#{link_provider_intent.original_name}'"\
                                   " from variable '#{link_provider.name}'")
        expect(error).to_not match(/contain any networks/)
      end

      context 'and a network is specified' do
        it 'should return a variable specific error message' do
          error = subject.build_link_error(link_consumer_intent, [link_provider_intent], 'foobar')
          expect(error).to include("Link provider '#{link_provider_intent.original_name}'"\
                                     " from variable '#{link_provider.name}'"\
                                     ' does not contain any networks')
        end
      end
    end

    context 'when the provider is a job' do
      let(:link_provider) do
        Bosh::Director::Models::Links::LinkProvider.create(
          deployment: deployment,
          instance_group: 'ig_name',
          name: 'my_job',
          type: 'job',
        )
      end
      let(:link_provider_intent) do
        Bosh::Director::Models::Links::LinkProviderIntent.create(
          link_provider: link_provider,
          original_name: 'provider_name',
          name: 'provider_name',
          type: 'foo',
        )
      end

      it 'should return a job specific error message' do
        error = subject.build_link_error(link_consumer_intent, [link_provider_intent])
        expected_message = "Link provider '#{link_provider_intent.original_name}'"\
                             " from job '#{link_provider.name}'"\
                             " in instance group '#{link_provider.instance_group}'"\
                             " in deployment '#{deployment.name}'"
        expect(error).to include(expected_message)
        expect(error).to_not match(/does not belong to network/)
        expect(error).to_not match(/with alias/)
      end

      context 'when the provider alias and original name differs' do
        let(:link_provider_intent) do
          Bosh::Director::Models::Links::LinkProviderIntent.create(
            link_provider: link_provider,
            original_name: 'provider_name',
            name: 'provider_name_alias',
            type: 'foo',
          )
        end

        it 'should return a job specific error message with alias' do
          error = subject.build_link_error(link_consumer_intent, [link_provider_intent])
          expected_message = "Link provider '#{link_provider_intent.original_name}'"\
                               " with alias '#{link_provider_intent.name}'"\
                               " from job '#{link_provider.name}'"\
                               " in instance group '#{link_provider.instance_group}'"\
                               " in deployment '#{deployment.name}'"
          expect(error).to include(expected_message)
        end
      end

      context 'and a network is specified' do
        let(:network) { 'foobar' }

        it 'should return a job specific error message' do
          error = subject.build_link_error(link_consumer_intent, [link_provider_intent], network)
          expect(error).to include("Link provider '#{link_provider_intent.original_name}'"\
                                     " from job '#{link_provider.name}'"\
                                     " in instance group '#{link_provider.instance_group}'"\
                                     " in deployment '#{deployment.name}'"\
                                     " does not belong to network '#{network}'")
        end
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

  describe '#build_link_error' do
    context 'when consumer is a variable' do
      let(:deployment) do
        FactoryBot.create(:models_deployment, name: 'my_deployment')
      end

      let(:link_consumer) do
        Bosh::Director::Models::Links::LinkConsumer.create(
          deployment: deployment,
          name: 'variable_name',
          type: 'variable',
        )
      end
      let(:link_consumer_intent) do
        Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: link_consumer,
          original_name: 'alternative_name',
          name: 'alternative_name',
          type: 'address',
        )
      end

      it 'should return an error message with variable specific heading' do
        error = subject.build_link_error(link_consumer_intent, [])
        expect(error).to start_with("Failed to resolve link '#{link_consumer_intent.original_name}'"\
                           " with type '#{link_consumer_intent.type}'"\
                           " from variable '#{link_consumer.name}'."\
                           ' Details below:')
      end

      it_populates_the_error_details_correctly
    end

    context 'when consumer is a job' do
      let(:deployment) do
        FactoryBot.create(:models_deployment, name: 'my_deployment')
      end

      let(:link_consumer) do
        Bosh::Director::Models::Links::LinkConsumer.create(
          deployment: deployment,
          instance_group: 'ig_name',
          name: 'job_name',
          type: 'job',
        )
      end
      let(:link_consumer_intent) do
        Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: link_consumer,
          original_name: 'cname',
          name: 'cname',
          type: 'ctype',
        )
      end

      it 'should return an error message with job specific heading' do
        error = subject.build_link_error(link_consumer_intent, [])
        expect(error).to start_with("Failed to resolve link '#{link_consumer_intent.original_name}'"\
                           " with type '#{link_consumer_intent.type}'"\
                           " from job '#{link_consumer.name}'"\
                           " in instance group '#{link_consumer.instance_group}'."\
                           ' Details below:')
      end

      context 'when the instance group does not exist for (external link) consumer' do
        let(:link_consumer) do
          Bosh::Director::Models::Links::LinkConsumer.create(
            deployment: deployment,
            name: 'job_name',
            type: 'job',
            )
        end

        it 'should return an error message with job specific heading (minus instance group)' do
          error = subject.build_link_error(link_consumer_intent, [])
          expect(error).to start_with("Failed to resolve link '#{link_consumer_intent.original_name}'"\
                           " with type '#{link_consumer_intent.type}'"\
                           " from job '#{link_consumer.name}'."\
                           ' Details below:')
        end
      end

      it_populates_the_error_details_correctly
    end
  end
end
