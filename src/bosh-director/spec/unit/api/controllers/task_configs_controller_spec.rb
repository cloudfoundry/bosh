require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::TaskConfigsController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }

      let(:temp_dir) { Dir.mktmpdir }

      let(:deployment_name_1) { 'deployment1' }
      let(:deployment_name_2) { 'deployment2' }
      let(:deployment_name_3) { 'deployment3' }
      let(:team_rocket) { Models::Team.make(name: 'team-rocket') }
      let(:dev) { Models::Team.make(name: 'dev') }

      let(:config) do
        config = Config.load_hash(SpecHelper.spec_get_director_config)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end

      after { FileUtils.rm_rf(temp_dir) }

      context 'info' do
        class FakeJob < Jobs::BaseJob
          def self.job_type
            :snow
          end
          define_method :perform do
            'foo'
          end
          @queue = :sample
        end

        let(:tmpdir) { Dir.mktmpdir }
        after { FileUtils.rm_rf tmpdir }

        let(:job_class) { FakeJob }
        let(:description) { 'busy doing something' }
        let(:task_remover) { instance_double('Bosh::Director::Api::TaskRemover') }

        let(:teams) do
          [Models::Team.make(name: 'security'), Models::Team.make(name: 'spies')]
        end
        let(:deployment1) { Models::Deployment.create_with_teams(name: deployment_name_1, teams: teams) }
        let(:deployment2) { Models::Deployment.create_with_teams(name: deployment_name_2, teams: teams) }

        before do
          Config.base_dir = tmpdir
          Config.max_tasks = 2
          allow(Api::TaskRemover).to receive(:new).with(Config.max_tasks).and_return(task_remover)
          allow(task_remover).to receive(:remove)
        end

        it 'allows to pause jobs' do
          basic_authorize 'admin', 'admin'
          JobQueue.new.enqueue('whoami', job_class, description, ['foo', 'bar'], deployment1)
          post '/', YAML.dump(Bosh::Spec::Deployments.simple_task_config(true)), {'CONTENT_TYPE' => 'text/yaml'}
          JobQueue.new.enqueue('whoami', job_class, description, ['foo', 'bar'], deployment2)
          expect(Delayed::Job.count).to eq(2)
          Delayed::Job.all.each do |delayed_job|
            expect(delayed_job[:queue]).to eq('pause')
          end
          post '/', YAML.dump(Bosh::Spec::Deployments.simple_task_config), {'CONTENT_TYPE' => 'text/yaml'}
          expect(Delayed::Job.count).to eq(2)
          Delayed::Job.all.each do |delayed_job|
            expect(delayed_job[:queue]).to eq('sample')
          end
        end

        it 'does not pause failed jobs' do
          basic_authorize 'admin', 'admin'
          JobQueue.new.enqueue('whoami', job_class, description, ['foo', 'bar'], deployment1)
          expect(Delayed::Job.count).to eq(1)
          Delayed::Job.first.update(:failed_at => Time.current)
          post '/', YAML.dump(Bosh::Spec::Deployments.simple_task_config(true)), {'CONTENT_TYPE' => 'text/yaml'}
          expect(Delayed::Job.first[:queue]).to eq('sample')
        end

        it 'does not pause locked jobs' do
          basic_authorize 'admin', 'admin'
          JobQueue.new.enqueue('whoami', job_class, description, ['foo', 'bar'], deployment1)
          expect(Delayed::Job.count).to eq(1)
          Delayed::Job.first.update(:locked_by => 'some other worker')
          post '/', YAML.dump(Bosh::Spec::Deployments.simple_task_config(true)), {'CONTENT_TYPE' => 'text/yaml'}
          expect(Delayed::Job.first[:queue]).to eq('sample')
        end
      end

      describe 'API calls' do
        describe 'POST' do

          context 'when tasks_paused director attribute is set' do
            before(:each) { basic_authorize 'admin', 'admin' }

            it 'returns true' do
              post '/', YAML.dump(Bosh::Spec::Deployments.simple_task_config(true)), {'CONTENT_TYPE' => 'text/yaml'}
              expect(last_response.status).to eq(200)
              record = Bosh::Director::Models::TasksConfig.order(Sequel.desc(:id)).limit(1).first
              expect(record.manifest['paused']).to eq(true)
            end

            it 'returns false' do
              post '/', YAML.dump(Bosh::Spec::Deployments.simple_task_config), {'CONTENT_TYPE' => 'text/yaml'}
              expect(last_response.status).to eq(200)
              record = Bosh::Director::Models::TasksConfig.order(Sequel.desc(:id)).limit(1).first
              expect(record.manifest['paused']).to eq(false)
            end

            it 'gives a nice error when request body is empty' do
              post '/', '', {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)).to eq(
              'code' => 440001,
              'description' => 'Manifest should not be empty',
              )
            end
          end
        end

        describe 'GET', '/' do
          describe 'when user has admin access' do
            before { authorize('admin', 'admin') }

            it 'returns paused value' do
              Bosh::Director::Models::TasksConfig.new(
                  properties:  YAML.dump(Bosh::Spec::Deployments.simple_task_config(true))
              ).save
              get '/?limit=1'
              expect(last_response.status).to eq(200)
              expect(YAML.load(JSON.parse(last_response.body).first['properties'])['paused']).to eq(true)
            end

            it 'returns the number of task configs specified by ?limit' do
              oldest_task_config = Bosh::Director::Models::TasksConfig.new(
                  properties: "config_from_time_immortal",
                  created_at: Time.now - 3,
              ).save
              older_task_config = Bosh::Director::Models::TasksConfig.new(
                  properties: "config_from_last_year",
                  created_at: Time.now - 2,
              ).save
              newer_task_config_properties = "---\nsuper_shiny: new_config"
              newer_task_config = Bosh::Director::Models::TasksConfig.new(
                  properties: newer_task_config_properties,
                  created_at: Time.now - 1,
              ).save

              get '/?limit=2'

              expect(last_response.status).to eq(200)
              expect(JSON.parse(last_response.body).count).to eq(2)
              expect(JSON.parse(last_response.body).first["properties"]).to eq(newer_task_config_properties)
            end

            it 'returns STATUS 400 if limit was not specified or malformed' do
              get '/'
              expect(last_response.status).to eq(400)
              expect(last_response.body).to eq("limit is required")

              get "/?limit="
              expect(last_response.status).to eq(400)
              expect(last_response.body).to eq("limit is required")

              get "/?limit=foo"
              expect(last_response.status).to eq(400)
              expect(last_response.body).to eq("limit is invalid: 'foo' is not an integer")
            end
          end

          describe 'when user has readonly access' do
            before { basic_authorize 'reader', 'reader' }
            before {
              Bosh::Director::Models::TasksConfig.make(:properties => '{}')
            }

            it 'denies access' do
              expect(get('/?limit=2').status).to eq(401)
            end
          end
        end
      end
    end
  end
end
