require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/cloud_configs_controller'

module Bosh::Director
  describe Api::Controllers::CloudConfigsController do
    include Rack::Test::Methods

    subject(:app) { linted_rack_app(described_class.new(config)) }
    let(:config) do
      config = Config.load_hash(SpecHelper.spec_get_director_config)
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end

    describe 'POST', '/' do
      context 'user has admin permissions' do
        before { authorize 'admin', 'admin' }

        it 'creates a new cloud config' do
          content = YAML.dump(SharedSupport::DeploymentManifestHelper.simple_cloud_config)
          expect {
            post '/', content, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Models::Config, :count).from(0).to(1)

          expect(Models::Config.first.content).to eq(content)
        end

        it 'creates a new cloud config when one exists with different content' do
          content = YAML.dump(SharedSupport::DeploymentManifestHelper.simple_cloud_config)
          FactoryBot.create(:models_config_cloud, content: content+"123")

          expect {
            post '/', content, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Models::Config, :count)

          expect(last_response.status).to eq(201)
        end

        it 'ignores cloud config when config already exists' do
          content = YAML.dump(SharedSupport::DeploymentManifestHelper.simple_cloud_config)
          FactoryBot.create(:models_config_cloud, content: content)

          expect {
            post '/', content, {'CONTENT_TYPE' => 'text/yaml'}
          }.to_not change(Models::Config, :count)

          expect(last_response.status).to eq(201)
        end

        it 'gives a nice error when request body is not a valid yml' do
          post '/', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml'}

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['code']).to eq(440001)
          expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded manifest: ')
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

      context 'when user is reader' do
        before { basic_authorize('reader', 'reader') }

        it 'forbids access' do
          expect(post('/', '', {'CONTENT_TYPE' => 'text/yaml'}).status).to eq(401)
        end
      end

      context 'when user is team-admin' do
        before { basic_authorize('dev-team-member', 'dev-team-member') }

        it 'forbid access' do
          expect(post('/', '', {'CONTENT_TYPE' => 'text/yaml'}).status).to eq(401)
        end
      end

      context 'user is not authorized' do
        it 'denies access when not authenticated' do
          expect(post('/').status).to eq(401)
        end
      end

      it 'creates a new event' do
        authorize('admin', 'admin')

        content = YAML.dump(SharedSupport::DeploymentManifestHelper.simple_cloud_config)
        expect {
          post '/', content, {'CONTENT_TYPE' => 'text/yaml'}
        }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
        event = Bosh::Director::Models::Event.first
        expect(event.object_type).to eq('cloud-config')
        expect(event.object_name).to eq('default')
        expect(event.action).to eq('update')
        expect(event.user).to eq('admin')
      end

      it 'creates a new event with error' do
        authorize('admin', 'admin')
        expect {
          post '/', {}, {'CONTENT_TYPE' => 'text/yaml'}
        }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
        event = Bosh::Director::Models::Event.first
        expect(event.object_type).to eq('cloud-config')
        expect(event.object_name).to eq('default')
        expect(event.action).to eq('update')
        expect(event.user).to eq('admin')
        expect(event.error).to eq('Manifest should not be empty')
      end

      context 'when name is the empty string' do
        before { authorize 'admin', 'admin' }

        let(:path) { '/?name=' }
        let(:content) { YAML.dump(SharedSupport::DeploymentManifestHelper.simple_cloud_config) }

        it "creates a new cloud config with name 'default'" do
          post path, content, 'CONTENT_TYPE' => 'text/yaml'

          expect(last_response.status).to eq(201)
          expect(Bosh::Director::Models::Config.first.name).to eq('default')
        end
      end

      context 'when a name is passed in via a query param' do
        before { authorize 'admin', 'admin' }

        let(:path) { '/?name=smurf' }
        let(:content) { YAML.dump(SharedSupport::DeploymentManifestHelper.simple_cloud_config) }

        it 'creates a new named cloud config' do
          post path, content, 'CONTENT_TYPE' => 'text/yaml'

          expect(last_response.status).to eq(201)
          expect(Bosh::Director::Models::Config.first.name).to eq('smurf')
        end

        it 'ignores named cloud config when config already exists' do
          FactoryBot.create(:models_config_cloud, content: content, name: 'smurf')

          expect do
            post path, content, 'CONTENT_TYPE' => 'text/yaml'
          end.to_not change(Models::Config, :count)

          expect(last_response.status).to eq(201)
        end

        it 'creates a new event and add name to event context' do
          expect do
            post path, content, 'CONTENT_TYPE' => 'text/yaml'
          end.to change(Bosh::Director::Models::Event, :count).from(0).to(1)

          event = Bosh::Director::Models::Event.first
          expect(event.object_type).to eq('cloud-config')
          expect(event.object_name).to eq('smurf')
          expect(event.action).to eq('update')
          expect(event.user).to eq('admin')
        end
      end
    end

    describe 'GET', '/' do
      it "returns the number of cloud configs specified by ?limit and only considers 'default' names" do
        authorize('admin', 'admin')

        FactoryBot.create(:models_config_cloud,
          content: 'config_from_time_immortal',
          created_at: Time.now - 4,
          name: 'not-default'
        )
        FactoryBot.create(:models_config_cloud,
          content: 'config_from_second_last_year',
          created_at: Time.now - 3,
          name: 'default'
        )
        FactoryBot.create(:models_config_cloud,
          content: 'config_from_last_year',
          created_at: Time.now - 2,
          name: 'not-default'
        )
        newer_cloud_config_content = "---\nsuper_shiny: new_config"
        FactoryBot.create(:models_config_cloud,
          content: newer_cloud_config_content,
          created_at: Time.now - 1,
          name: 'default'
        )

        get '/?limit=2'

        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body).count).to eq(2)
        expect(JSON.parse(last_response.body)[0]['properties']).to eq(newer_cloud_config_content)
        expect(JSON.parse(last_response.body)[1]['properties']).to eq('config_from_second_last_year')
      end

      it "returns the cloud configs specified by name" do
        authorize('admin', 'admin')

        FactoryBot.create(:models_config_cloud,
          content: 'config_from_second_last_year',
          created_at: Time.now - 3,
          name: 'not-default'
        )
        FactoryBot.create(:models_config_cloud,
          content: 'config_from_last_year',
          created_at: Time.now - 2,
          name: 'not-default'
        )
        newer_cloud_config_content = "---\nsuper_shiny: new_config"
        FactoryBot.create(:models_config_cloud,
          content: newer_cloud_config_content,
          created_at: Time.now - 1,
          name: 'default'
        )

        get '/?limit=2&name=not-default'

        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body).count).to eq(2)
        expect(JSON.parse(last_response.body)[0]['properties']).to eq('config_from_last_year')
        expect(JSON.parse(last_response.body)[1]['properties']).to eq('config_from_second_last_year')
      end

      it 'returns STATUS 400 if limit was not specified or malformed' do
        authorize('admin', 'admin')

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

      it 'denies access when not authenticated' do
        expect(get('/').status).to eq(401)
      end

      context 'when user is reader' do
        before { basic_authorize('reader', 'reader') }

        it 'permits access' do
          expect(get('/?limit=1').status).to eq(200)
        end
      end
    end

    describe 'diff' do

      let(:cloud_config_hash_with_one_az) do
        {
          'azs' => [
            {
              'name' => 'az1',
              'cloud_properties' => {},
            },
          ],
        }
      end

      let(:cloud_config_hash_with_two_azs) do
        {
          'azs' => [
            {
              'name' => 'az1',
              'cloud_properties' => {},
            },
            {
              'name' => 'az2',
              'cloud_properties' => {},
            },
          ],
        }
      end

      context 'authenticated access' do

        before { authorize 'admin', 'admin' }

        context 'when there is a previous cloud config' do
          before do
            FactoryBot.create(:models_config_cloud, content: YAML.dump(cloud_config_hash_with_two_azs))
          end

          context 'when uploading an empty cloud config' do
            it 'returns the diff' do
              post(
                '/diff',
                "--- \n {}",
                { 'CONTENT_TYPE' => 'text/yaml' }
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["azs:","removed"],["- name: az1","removed"],["  cloud_properties: {}","removed"],["- name: az2","removed"],["  cloud_properties: {}","removed"]]}')
            end
          end

          context 'when there is no diff' do
            it 'returns empty diff' do
              post(
                  '/diff',
                  YAML.dump(cloud_config_hash_with_two_azs),
                  {'CONTENT_TYPE' => 'text/yaml'}
              )
              expect(last_response.body).to eq('{"diff":[]}')
            end
          end

          context 'when there is a diff' do
            it 'returns the diff' do
              post(
                  '/diff',
                  YAML.dump(cloud_config_hash_with_one_az),
                  {'CONTENT_TYPE' => 'text/yaml'}
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["azs:",null],["- name: az2","removed"],["  cloud_properties: {}","removed"]]}')
            end
          end

          it 'gives a nice error when request body is not a valid yml' do
            post '/diff', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440001)
            expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded manifest: ')
          end

          it 'gives a nice error when request body is empty' do
            post '/diff', '', {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)).to eq(
                'code' => 440001,
                'description' => 'Manifest should not be empty',
            )
          end

          it 'returns 200 with an empty diff and an error message if the diffing fails' do
            allow_any_instance_of(Bosh::Director::Changeset).to receive(:diff).and_raise('Oooooh crap')

            post '/diff', {}.to_yaml, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)['diff']).to eq([])
            expect(JSON.parse(last_response.body)['error']).to include('Unable to diff cloud-config')
          end

        end

        context 'when there are two previous cloud config' do
          before do
            FactoryBot.create(:models_config_cloud, name: 'foo',content: YAML.dump(cloud_config_hash_with_one_az))
            FactoryBot.create(:models_config_cloud, content: YAML.dump(cloud_config_hash_with_two_azs))
          end
          it 'always diffs against the default-named cloud config' do
            post(
                '/diff',
                YAML.dump(cloud_config_hash_with_two_azs),
                {'CONTENT_TYPE' => 'text/yaml'}
            )
            expect(last_response.body).to eq('{"diff":[]}')
          end
        end

        context 'when a config name is provided' do
          before do
            FactoryBot.create(:models_config_cloud, name: 'foo',content: YAML.dump(cloud_config_hash_with_one_az))
            FactoryBot.create(:models_config_cloud, content: YAML.dump(cloud_config_hash_with_two_azs))
          end
          it 'always diffs against the named cloud config' do
            post(
                '/diff?name=foo',
                YAML.dump(cloud_config_hash_with_one_az),
                {'CONTENT_TYPE' => 'text/yaml'}
            )
            expect(last_response.body).to eq('{"diff":[]}')
          end
        end

        context 'when there is no previous cloud config' do
          it 'returns the diff' do
            post(
                '/diff',
                YAML.dump(cloud_config_hash_with_one_az),
                {'CONTENT_TYPE' => 'text/yaml'}
            )
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('{"diff":[["azs:","added"],["- name: az1","added"],["  cloud_properties: {}","added"]]}')
          end

          context 'when previous cloud config is nil' do
            before do
              FactoryBot.create(:models_config_cloud)
            end

            it 'returns the diff' do
              post(
                '/diff',
                YAML.dump(cloud_config_hash_with_one_az),
                {'CONTENT_TYPE' => 'text/yaml'}
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["azs:","added"],["- name: az1","added"],["  cloud_properties: {}","added"]]}')
            end
          end
        end
      end

      context 'accessing with invalid credentials' do
        before { authorize 'invalid-user', 'invalid-password' }

        it 'returns 401' do
          post '/diff', {}.to_yaml, {'CONTENT_TYPE' => 'text/yaml'}
          expect(last_response.status).to eq(401)
        end
      end
    end
  end
end
