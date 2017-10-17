require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/configs_controller'

module Bosh::Director
  describe Api::Controllers::ConfigsController do
    include Rack::Test::Methods

    subject(:app) { Api::Controllers::ConfigsController.new(config) }
    let(:config) do
      config = Config.load_hash(SpecHelper.spec_get_director_config)
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end

    describe 'GET', '/' do
      context 'with authenticated admin user' do
        before(:each) do
          authorize('admin', 'admin')
        end

        it 'returns all matching' do
          newest_config = 'new_config'

          Models::Config.make(
            content: 'some-yaml',
            created_at: Time.now - 3.days
          )

          Models::Config.make(
          content: 'some-other-yaml',
          created_at: Time.now - 2.days
          )

          Models::Config.make(
            name: 'my-config',
            content: newest_config,
            created_at: Time.now - 1.days
          )

          get '/?&latest=true'
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
          expect(JSON.parse(last_response.body)).to include(include('content' => 'some-other-yaml'))
          expect(JSON.parse(last_response.body)).to include(include('content' => newest_config))
        end

        context 'when name is given' do
          it 'returns the latest config with that name' do
            Models::Config.make(
                content: 'some-yaml',
                created_at: Time.now - 3.days
            )

            Models::Config.make(
              content: 'some-other-yaml',
              created_at: Time.now - 2.days
            )

            newest_config = 'new_config'
            Models::Config.make(
            name: 'my-config',
            content: newest_config,
            created_at: Time.now - 1.days
            )

            get '/?type=my-type&name=my-config&latest=true'
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
          end
        end

        it 'returns the latest config' do
          Models::Config.make(
              content: 'some-yaml',
              created_at: Time.now - 3.days
          )

          Models::Config.make(
              content: 'some-other-yaml',
              created_at: Time.now - 2.days
          )

          newest_config = 'new_config'
          Models::Config.make(
              content: newest_config,
              created_at: Time.now - 1.days
          )

          get '/?type=my-type&latest=true'
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
        end

        context 'when no records match the filters' do
          it 'returns empty' do

            get '/?type=my-type&name=notExisting&latest=true'

            expect(last_response.status).to eq(200)

            result = JSON.parse(last_response.body)
            expect(result.class).to be(Array)
            expect(result).to eq([])
          end
        end

        context 'when no type is given' do
          it 'does not filter by type' do
            Models::Config.make(
              content: 'some-other-yaml',
              created_at: Time.now - 2.days
            )

            newest_config = 'new_config'
            Models::Config.make(
              content: newest_config,
              created_at: Time.now - 1.days
            )

            get '/?latest=true'

            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
          end
        end

        context 'when no latest param is given' do
          it 'return 400' do
            get '/?type=my-type&name=some-name'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(40001)
            expect(JSON.parse(last_response.body)['description']).to eq("'latest' is required")
          end
        end

        context 'when latest param is given and has wrong value' do
          it 'return 400' do
            get '/?type=my-type&name=some-name&latest=foo'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(40005)
            expect(JSON.parse(last_response.body)['description']).to eq("'latest' must be 'true' or 'false'")
          end
        end

        context 'when latest is false' do
          it 'returns the history of all matching configs' do
            config1 = Models::Config.make
            Models::Config.make

            get '/?type=my-type&latest=false'

            expect(last_response.status).to eq(200)

            result = JSON.parse(last_response.body)
            expect(result.class).to be(Array)
            expect(result.size).to eq(2)
            expect(result).to include({
                'content' => config1.content,
                'id' => config1.id,
                'type' => config1.type,
                'name' => config1.name
            })
          end
        end
      end

      context 'without an authenticated user' do
        it 'denies access' do
          expect(get('/').status).to eq(401)
        end
      end

      context 'when user is reader' do
        before { basic_authorize('reader', 'reader') }

        it 'permits access' do
          expect(get('/?type=my-type&latest=true').status).to eq(200)
        end
      end
    end

    describe 'POST', '/' do
      let(:content) { YAML.dump(Bosh::Spec::Deployments.simple_runtime_config) }

      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        it 'creates a new config' do
          expect {
            post '/?type=my-type&name=my-name', content, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

          expect(last_response.status).to eq(201)

          expect(JSON.parse(last_response.body)).to eq(
            {
              'id' => Bosh::Director::Models::Config.first.id,
              'type' => 'my-type',
              'name' => 'my-name',
              'content' => content
            }
          )
        end

        it 'creates new config and does not update existing ' do
          post '/?type=my-type&name=my-name', content, {'CONTENT_TYPE' => 'text/yaml'}
          expect(last_response.status).to eq(201)

          expect {
            post '/?type=my-type&name=my-name', content, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Config, :count).from(1).to(2)

          expect(last_response.status).to eq(201)
        end

        it 'gives a nice error when request body is not a valid yml' do
          post '/?type=my-type&name=my-name', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml'}

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['code']).to eq(440001)
          expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded manifest: ')
        end

        it 'gives a nice error when request body is empty' do
          post '/?type=my-type&name=my-name', '', {'CONTENT_TYPE' => 'text/yaml'}

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)).to eq(
              'code' => 440001,
              'description' => 'Manifest should not be empty',
          )
        end

        it 'creates a new event' do
          expect {
            post '/?type=my-type&name=my-name', content, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
          event = Bosh::Director::Models::Event.first
          expect(event.object_type).to eq('config/my-type')
          expect(event.object_name).to eq('my-name')
          expect(event.action).to eq('create')
          expect(event.user).to eq('admin')
        end

        it 'creates a new event with error' do
          expect {
            post '/?type=my-type&name=my-name', {}, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
          event = Bosh::Director::Models::Event.first
          expect(event.object_type).to eq('config/my-type')
          expect(event.object_name).to eq('my-name')
          expect(event.action).to eq('create')
          expect(event.user).to eq('admin')
          expect(event.error).to eq('Manifest should not be empty')
        end

        context 'when `type` argument is missing' do
          it 'return 400' do
            post '/?name=some-name', content, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(40001)
            expect(JSON.parse(last_response.body)['description']).to eq("'type' is required")
          end
        end

        context 'when `name` argument is missing' do
          it 'return 400' do
            post '/?type=my-type', content, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(40001)
            expect(JSON.parse(last_response.body)['description']).to eq("'name' is required")
          end
        end
      end

      describe 'when user has readonly access' do
        before { basic_authorize 'reader', 'reader' }

        it 'denies access' do
          expect(post('/?type=my-type&name=my-name', content, {'CONTENT_TYPE' => 'text/yaml'}).status).to eq(401)
        end
      end
    end

    describe 'DELETE', '/' do
      describe 'when user has readonly access' do
        before { basic_authorize 'reader', 'reader' }

        it 'denies access' do
          expect(delete('/?type=my-type&name=my-name').status).to eq(401)
        end
      end

      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        context 'when type and name are given' do
          context 'when config exists' do
            before do
              Models::Config.make(
                type: 'my-type',
                name: 'my-name'
              )
            end

            it 'deletes the config' do
              expect(delete('/?type=my-type&name=my-name').status).to eq(204)

              configs = JSON.parse(get('/?type=my-type&name=my-name&latest=false').body)

              expect(configs.count).to eq(0)
            end
          end

          context "when there is no config matching given 'type' and 'name'" do
            it 'responds with 404' do
              expect(delete('/?type=my-type&name=my-name').status).to eq(404)
            end
          end
        end

        context "when 'type' parameter is missing" do
          it 'responds with 400' do
            response = delete('/?name=my-name')

            expect(response.status).to eq(400)
            expect(JSON.parse(response.body)['description']).to eq("'type' is required")
          end
        end

        context "when 'name' parameter is missing" do
          it 'responds with 400' do
            response = delete('/?type=my-type')

            expect(response.status).to eq(400)
            expect(JSON.parse(response.body)['description']).to eq("'name' is required")
          end
        end
      end
    end
  end
end
