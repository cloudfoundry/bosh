require 'spec_helper'

describe Bosh::Registry do
  describe 'configuring registry' do
    it 'validates configuration file' do
      expect do
        Bosh::Registry.configure('foobar')
      end.to raise_error(Bosh::Registry::ConfigError, /Invalid config format/)

      config = valid_config.merge('http' => nil)

      expect do
        Bosh::Registry.configure(config)
      end.to raise_error(Bosh::Registry::ConfigError, /HTTP configuration is missing/)

      config = valid_config.merge('db' => nil)

      expect do
        Bosh::Registry.configure(config)
      end.to raise_error(Bosh::Registry::ConfigError, /Database configuration is missing/)

      config = valid_config
      config.delete('cloud')

      expect do
        Bosh::Registry.configure(config)
      end.to_not raise_error

      config = valid_config.merge('cloud' => nil)

      expect do
        Bosh::Registry.configure(config)
      end.to raise_error(Bosh::Registry::ConfigError, /Cloud configuration is missing/)

      config = valid_config
      config['cloud']['plugin'] = nil

      expect do
        Bosh::Registry.configure(config)
      end.to raise_error(Bosh::Registry::ConfigError, /Cloud plugin is missing/)

      config = valid_config

      expect do
        Bosh::Registry.configure(config)
      end.to raise_error(Bosh::Registry::ConfigError, /Could not find Provider Plugin/)
    end

    it 'reads provided configuration file and sets singletons for AWS' do
      config = valid_config
      config['cloud'] = {
        'plugin' => 'aws',
        'aws' => {
          'access_key_id' => 'foo',
          'secret_access_key' => 'bar',
          'region' => 'foobar',
          'max_retries' => 5,
        },
      }
      Bosh::Registry.configure(config)

      logger = Bosh::Registry.logger

      expect(logger).to be_kind_of(Logger)
      expect(logger.level).to eq(Logger::DEBUG)

      user = Bosh::Registry.auth.first
      expect(Bosh::Registry.http_port).to eq(25_777)
      expect(user['user']).to eq("admin")
      expect(user['password']).to eq("admin")

      db = Bosh::Registry.db
      expect(db).to be_kind_of(Sequel::SQLite::Database)
      expect(db.opts[:database]).to eq(':memory:')
      expect(db.opts[:max_connections]).to eq(433)
      expect(db.opts[:pool_timeout]).to eq(227)

      im = Bosh::Registry.instance_manager
      expect(im).to be_kind_of(Bosh::Registry::InstanceManager::Aws)
    end

    context 'when users are defined' do
      context 'when only one user is defined' do
        it 'sets the user properly' do
          config = valid_config
          config.delete('cloud')
          Bosh::Registry.configure(config)

          expect(Bosh::Registry.auth.size).to eq(1)
          expect(Bosh::Registry.auth[0]['user']).to eq('admin')
          expect(Bosh::Registry.auth[0]['password']).to eq('admin')
        end
      end

      context 'when more than one user is defined' do
        it 'sets the users properly' do
          config = valid_config
          config.delete('cloud')

          config['http']['additional_users'] = [
              {'username' => 'admin1', 'password' => 'pass1'},
              {'username' => 'admin2', 'password' => 'pass2'},

          ]
          Bosh::Registry.configure(config)

          expect(Bosh::Registry.auth.size).to eq(3)
          expect(Bosh::Registry.auth[0]['user']).to eq('admin')
          expect(Bosh::Registry.auth[0]['password']).to eq('admin')
          expect(Bosh::Registry.auth[1]['user']).to eq('admin1')
          expect(Bosh::Registry.auth[1]['password']).to eq('pass1')
          expect(Bosh::Registry.auth[2]['user']).to eq('admin2')
          expect(Bosh::Registry.auth[2]['password']).to eq('pass2')
        end
      end

    end

    it 'reads provided configuration file and sets singletons for OpenStack' do
      allow(Fog::Compute).to receive(:new)

      config = valid_config
      config['cloud'] = {
        'plugin' => 'openstack',
        'openstack' => {
          'auth_url' => 'http://127.0.0.1:5000/v2.0',
          'username' => 'foo',
          'api_key' => 'bar',
          'tenant' => 'foo',
          'region' => '',
        },
      }
      Bosh::Registry.configure(config)

      logger = Bosh::Registry.logger

      expect(logger).to be_kind_of(Logger)
      expect(logger.level).to eq(Logger::DEBUG)

      expect(Bosh::Registry.http_port).to eq(25_777)

      user = Bosh::Registry.auth.first
      expect(user['user']).to eq("admin")
      expect(user['password']).to eq("admin")

      db = Bosh::Registry.db
      expect(db).to be_kind_of(Sequel::SQLite::Database)
      expect(db.opts[:database]).to eq(':memory:')
      expect(db.opts[:max_connections]).to eq(433)
      expect(db.opts[:pool_timeout]).to eq(227)

      im = Bosh::Registry.instance_manager
      expect(im).to be_kind_of(Bosh::Registry::InstanceManager::Openstack)
    end

    it 'reads provided configuration file and sets singletons for Azure' do
      allow(Fog::Compute).to receive(:new)

      config = valid_config
      config.delete('cloud')
      Bosh::Registry.configure(config)

      logger = Bosh::Registry.logger

      expect(logger).to be_kind_of(Logger)
      expect(logger.level).to eq(Logger::DEBUG)

      expect(Bosh::Registry.http_port).to eq(25_777)

      user = Bosh::Registry.auth.first
      expect(user['user']).to eq("admin")
      expect(user['password']).to eq("admin")

      db = Bosh::Registry.db
      expect(db).to be_kind_of(Sequel::SQLite::Database)
      expect(db.opts[:database]).to eq(':memory:')
      expect(db.opts[:max_connections]).to eq(433)
      expect(db.opts[:pool_timeout]).to eq(227)

      im = Bosh::Registry.instance_manager
      expect(im).to be_kind_of(Bosh::Registry::InstanceManager)
    end
  end

  describe 'database configuration' do
    let(:database_options) do
      {
        'adapter' => 'sqlite',
        'connection_options' => {
          'max_connections' => 32,
        },

      }
    end
    let(:database_connection) { double('Database Connection').as_null_object }

    before do
      allow(Sequel).to receive(:connect).and_return(database_connection)
    end

    it 'configures a new database connection' do
      expect(described_class.connect_db(database_options)).to eq database_connection
    end

    it 'merges connection options together with the rest of the database options' do
      expected_options = {
        'adapter' => 'sqlite',
        'max_connections' => 32,
      }
      expect(Sequel).to receive(:connect).with(expected_options).and_return(database_connection)
      described_class.connect_db(database_options)
    end

    it 'ignores empty and nil options' do
      expect(Sequel).to receive(:connect).with('baz' => 'baz').and_return(database_connection)
      described_class.connect_db('foo' => nil, 'bar' => '', 'baz' => 'baz')
    end

    context 'when TLS is requested' do
      shared_examples_for 'db connects with custom parameters' do
        it 'connects with TLS enabled for database' do
          expect(Sequel).to receive(:connect).with(connection_parameters).and_return(database_connection)
          described_class.connect_db(config)
        end
      end

      context 'postgres' do
        let(:config) do
          {
            'adapter' => 'postgres',
            'host' => '127.0.0.1',
            'port' => 5432,
            'tls' => {
              'enabled' => true,
              'cert' => {
                'ca' => '/path/to/root/ca',
                'certificate' => '/path/to/client/certificate',
                'private_key' => '/path/to/client/private_key',
              },
              'bosh_internal' => {
                'ca_provided' => true,
                'mutual_tls_enabled' => false,
              },
            },
          }
        end

        let(:connection_parameters) do
          {
            'adapter' => 'postgres',
            'host' => '127.0.0.1',
            'port' => 5432,
            'sslmode' => 'verify-full',
            'sslrootcert' => '/path/to/root/ca',
          }
        end

        it_behaves_like 'db connects with custom parameters'

        context 'when user defines TLS options in connection_options' do
          let(:config) do
            {
              'adapter' => 'postgres',
              'host' => '127.0.0.1',
              'port' => 5432,
              'tls' => {
                'enabled' => true,
                'cert' => {
                  'ca' => '/path/to/root/ca',
                  'certificate' => '/path/to/client/certificate',
                  'private_key' => '/path/to/client/private_key',
                },
                'bosh_internal' => {
                  'ca_provided' => true,
                  'mutual_tls_enabled' => false,
                },
              },
              'connection_options' => {
                'sslmode' => 'something-custom',
                'sslrootcert' => '/some/unknow/path',
              },
            }
          end

          let(:connection_parameters) do
            {
              'adapter' => 'postgres',
              'host' => '127.0.0.1',
              'port' => 5432,
              'sslmode' => 'something-custom',
              'sslrootcert' => '/some/unknow/path',
            }
          end

          it_behaves_like 'db connects with custom parameters'
        end

        context 'when user does not pass CA property' do
          let(:config) do
            {
              'adapter' => 'postgres',
              'host' => '127.0.0.1',
              'port' => 5432,
              'tls' => {
                'enabled' => true,
                'cert' => {
                  'ca' => '/path/to/root/ca',
                  'certificate' => '/path/to/client/certificate',
                  'private_key' => '/path/to/client/private_key',
                },
                'bosh_internal' => {
                  'ca_provided' => false,
                  'mutual_tls_enabled' => false,
                },
              },
            }
          end

          let(:connection_parameters) do
            {
              'adapter' => 'postgres',
              'host' => '127.0.0.1',
              'port' => 5432,
              'sslmode' => 'verify-full',
            }
          end

          it_behaves_like 'db connects with custom parameters'
        end

        context 'when mutual tls is enabled' do
          let(:config) do
            {
              'adapter' => 'postgres',
              'host' => '127.0.0.1',
              'port' => 5432,
              'tls' => {
                'enabled' => true,
                'cert' => {
                  'ca' => '/path/to/root/ca',
                  'certificate' => '/path/to/client/certificate',
                  'private_key' => '/path/to/client/private_key',
                },
                'bosh_internal' => {
                  'ca_provided' => true,
                  'mutual_tls_enabled' => true,
                },
              },
            }
          end

          let(:connection_parameters) do
            {
              'adapter' => 'postgres',
              'host' => '127.0.0.1',
              'port' => 5432,
              'sslmode' => 'verify-full',
              'sslrootcert' => '/path/to/root/ca',
              'driver_options' => {
                'sslcert' =>  '/path/to/client/certificate',
                'sslkey' => '/path/to/client/private_key',
              },
            }
          end

          it_behaves_like 'db connects with custom parameters'
        end
      end

      context 'mysql2' do
        let(:config) do
          {
            'adapter' => 'mysql2',
            'host' => '127.0.0.1',
            'port' => 3306,
            'tls' => {
              'enabled' => true,
              'cert' => {
                'ca' => '/path/to/root/ca',
                'certificate' => '/path/to/client/certificate',
                'private_key' => '/path/to/client/private_key',
              },
              'bosh_internal' => {
                'ca_provided' => true,
                'mutual_tls_enabled' => false,
              },
            },
          }
        end

        let(:connection_parameters) do
          {
            'adapter' => 'mysql2',
            'host' => '127.0.0.1',
            'port' => 3306,
            'ssl_mode' => 'verify_identity',
            'sslca' => '/path/to/root/ca',
            'sslverify' => true,
          }
        end

        it_behaves_like 'db connects with custom parameters'

        context 'when user defines TLS options in connection_options' do
          let(:config) do
            {
              'adapter' => 'mysql2',
              'host' => '127.0.0.1',
              'port' => 3306,
              'tls' => {
                'enabled' => true,
                'cert' => {
                  'ca' => '/path/to/root/ca',
                  'certificate' => '/path/to/client/certificate',
                  'private_key' => '/path/to/client/private_key',
                },
                'bosh_internal' => {
                  'ca_provided' => true,
                  'mutual_tls_enabled' => false,
                },
              },
              'connection_options' => {
                'ssl_mode' => 'something-custom',
                'sslca' => '/some/unknow/path',
                'sslverify' => false,
              },
            }
          end

          let(:connection_parameters) do
            {
              'adapter' => 'mysql2',
              'host' => '127.0.0.1',
              'port' => 3306,
              'ssl_mode' => 'something-custom',
              'sslca' => '/some/unknow/path',
              'sslverify' => false,
            }
          end

          it_behaves_like 'db connects with custom parameters'
        end

        context 'when user does not pass CA property' do
          let(:config) do
            {
              'adapter' => 'mysql2',
              'host' => '127.0.0.1',
              'port' => 3306,
              'tls' => {
                'enabled' => true,
                'cert' => {
                  'ca' => '/path/to/root/ca',
                  'certificate' => '/path/to/client/certificate',
                  'private_key' => '/path/to/client/private_key',
                },
                'bosh_internal' => {
                  'ca_provided' => false,
                  'mutual_tls_enabled' => false,
                },
              },
            }
          end

          let(:connection_parameters) do
            {
              'adapter' => 'mysql2',
              'host' => '127.0.0.1',
              'port' => 3306,
              'ssl_mode' => 'verify_identity',
              'sslverify' => true,
            }
          end

          it_behaves_like 'db connects with custom parameters'
        end

        context 'when mutual tls is enabled' do
          let(:config) do
            {
              'adapter' => 'mysql2',
              'host' => '127.0.0.1',
              'port' => 3306,
              'tls' => {
                'enabled' => true,
                'cert' => {
                  'ca' => '/path/to/root/ca',
                  'certificate' => '/path/to/client/certificate',
                  'private_key' => '/path/to/client/private_key',
                },
                'bosh_internal' => {
                  'ca_provided' => true,
                  'mutual_tls_enabled' => true,
                },
              },
            }
          end

          let(:connection_parameters) do
            {
              'adapter' => 'mysql2',
              'host' => '127.0.0.1',
              'port' => 3306,
              'ssl_mode' => 'verify_identity',
              'sslca' => '/path/to/root/ca',
              'sslverify' => true,
              'sslcert' =>  '/path/to/client/certificate',
              'sslkey' => '/path/to/client/private_key',
            }
          end

          it_behaves_like 'db connects with custom parameters'
        end
      end
    end
  end
end
