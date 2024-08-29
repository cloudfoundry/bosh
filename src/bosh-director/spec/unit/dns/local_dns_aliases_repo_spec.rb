require 'spec_helper'

module Bosh::Director
  describe LocalDnsAliasesRepo do
    subject(:local_dns_aliases_repo) { LocalDnsAliasesRepo.new(logger, root_domain) }
    let(:root_domain) { 'bosh1.tld' }

    describe '#update_for_deployment' do
      let(:deployment_model) { FactoryBot.create(:models_deployment, name: 'test-deployment') }
      let!(:ignored_provider_intent1) do
        FactoryBot.create(:models_links_link_provider_intent, link_provider: FactoryBot.create(:models_links_link_provider, deployment: deployment_model))
      end
      let!(:ignored_provider_intent2) do
        FactoryBot.create(:models_links_link_provider_intent,
          link_provider: FactoryBot.create(:models_links_link_provider, deployment: deployment_model),
          metadata: {}.to_json,
        )
      end
      let!(:ignored_provider_intent3) do
        FactoryBot.create(:models_links_link_provider_intent, metadata: { dns_aliases: [{ domain: 'foo.bar' }] }.to_json)
      end
      let!(:provider_intent1) do
        FactoryBot.create(:models_links_link_provider_intent,
          link_provider: FactoryBot.create(:models_links_link_provider, deployment: deployment_model),
          metadata: {
            dns_aliases: [
              {
                domain: 'foo.bar',
                health_filter: 'healthy',
                initial_health_check: 'synchronous',
              },
              {
                domain: 'foo2.bar',
              },
              {
                domain: '_.foo.bar',
                placeholder_type: 'uuid',
              },
            ],
          }.to_json,
        )
      end
      let!(:group1) do
        Bosh::Director::Models::LocalDnsEncodedGroup.create(
          name: provider_intent1.group_name,
          deployment_id: deployment_model.id,
          type: Models::LocalDnsEncodedGroup::Types::LINK,
        )
      end

      it 'creates and saves local dns alias models' do
        local_dns_aliases_repo.update_for_deployment(deployment_model)

        expect(Models::LocalDnsAlias.count).to eq(3)

        local_dns_alias = Models::LocalDnsAlias.find(domain: 'foo.bar')
        expect(local_dns_alias.deployment_id).to eq(deployment_model.id)
        expect(local_dns_alias.domain).to eq('foo.bar')
        expect(local_dns_alias.health_filter).to eq('healthy')
        expect(local_dns_alias.initial_health_check).to eq('synchronous')
        expect(local_dns_alias.group_id).to eq(group1.id.to_s)
        expect(local_dns_alias.placeholder_type).to be_nil

        local_dns_alias = Models::LocalDnsAlias.find(domain: 'foo2.bar')
        expect(local_dns_alias.deployment_id).to eq(deployment_model.id)
        expect(local_dns_alias.domain).to eq('foo2.bar')
        expect(local_dns_alias.health_filter).to be_nil
        expect(local_dns_alias.initial_health_check).to be_nil
        expect(local_dns_alias.group_id).to eq(group1.id.to_s)
        expect(local_dns_alias.placeholder_type).to be_nil

        local_dns_alias = Models::LocalDnsAlias.find(domain: '_.foo.bar')
        expect(local_dns_alias.deployment_id).to eq(deployment_model.id)
        expect(local_dns_alias.domain).to eq('_.foo.bar')
        expect(local_dns_alias.health_filter).to be_nil
        expect(local_dns_alias.initial_health_check).to be_nil
        expect(local_dns_alias.group_id).to eq(group1.id.to_s)
        expect(local_dns_alias.placeholder_type).to eq('uuid')
      end

      it 'does not update unchanged links' do
        local_dns_aliases_repo.update_for_deployment(deployment_model)

        expect do
          local_dns_aliases_repo.update_for_deployment(deployment_model)
        end.to_not(change { Models::LocalDnsAlias.max(:id) })
      end

      context 'when a change occurs' do
        before do
          local_dns_aliases_repo.update_for_deployment(deployment_model)
        end

        context 'when a link is updated' do
          before do
            provider_intent1.update(
              metadata: {
                dns_aliases: [
                  { domain: 'updated-foo.bar' },
                ],
              }.to_json,
            )
            deployment_model.reload
          end

          it 'recreates a local dns alias model' do
            local_dns_aliases_repo.update_for_deployment(deployment_model)
            expect(Models::LocalDnsAlias.count).to eq(1)

            local_dns_alias = Models::LocalDnsAlias.find(domain: 'updated-foo.bar')
            expect(local_dns_alias.deployment_id).to eq(deployment_model.id)
            expect(local_dns_alias.domain).to eq('updated-foo.bar')
            expect(local_dns_alias.health_filter).to be_nil
            expect(local_dns_alias.initial_health_check).to be_nil
            expect(local_dns_alias.group_id).to eq(group1.id.to_s)
            expect(local_dns_alias.placeholder_type).to be_nil
          end

          it 'bumps the version' do
            expect do
              local_dns_aliases_repo.update_for_deployment(deployment_model)
            end.to(change { Models::LocalDnsAlias.max(:id) }.by(be_positive))
          end
        end

        context 'when a link is removed' do
          before do
            provider_intent1.delete
            deployment_model.reload
          end

          it 'removes the local dns alias model' do
            local_dns_aliases_repo.update_for_deployment(deployment_model)
            local_dns_alias = Models::LocalDnsAlias.find(domain: 'foo.bar')
            expect(local_dns_alias).to be_nil
          end

          it 'bumps the version' do
            expect do
              local_dns_aliases_repo.update_for_deployment(deployment_model)
            end.to(change { Models::LocalDnsAlias.max(:id) }.by(be_positive))
          end
        end
      end
    end
  end
end
