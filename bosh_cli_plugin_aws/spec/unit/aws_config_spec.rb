require_relative '../spec_helper'

module ConfigSupport
  def it_needs_env(key)
    context "when missing key #{key}" do
      before { environment.delete(key) }

      it "raises an error" do
        expect {
          config.configuration
        }.to raise_error(Bosh::Aws::ConfigurationInvalid, "Missing ENV variable #{key}")
      end
    end

    context "when #{key} is present" do
      it "does not raise an error" do
        expect {
          config.configuration
        }.not_to raise_error
      end
    end
  end
end

describe Bosh::Aws::AwsConfig do
  let(:config) { described_class.new(config_file, environment) }
  let(:config_file) { File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "templates", "aws_configuration_template.yml.erb"))}
  let(:configuration) { config.configuration }
  let!(:environment) {{}}

  extend ConfigSupport

  context "default configuration" do
    before do
      environment["BOSH_VPC_SECONDARY_AZ"]        = "secondary_az"
      environment["BOSH_VPC_PRIMARY_AZ"]          = "primary_az"
      environment["BOSH_AWS_ACCESS_KEY_ID"]       = "access_key_id"
      environment["BOSH_AWS_SECRET_ACCESS_KEY"]   = "secret_access_key"
      environment["BOSH_VPC_SUBDOMAIN"]           = "burritos"
      environment["BOSH_CACHE_SECRET_ACCESS_KEY"] = "subdomain"
      environment["BOSH_AWS_REGION"]              = "us-east-1"
    end

    describe "validating yaml content" do
      it_needs_env "BOSH_VPC_SECONDARY_AZ"
      it_needs_env "BOSH_VPC_PRIMARY_AZ"
      it_needs_env "BOSH_AWS_ACCESS_KEY_ID"
      it_needs_env "BOSH_AWS_SECRET_ACCESS_KEY"

      context "package cache configuration disabled" do
        it "does not validate the presence of BOSH_CACHE_SECRET_ACCESS_KEY" do
          environment.delete('BOSH_CACHE_ACCESS_KEY_ID')
          environment.delete('BOSH_CACHE_SECRET_ACCESS_KEY')
          expect { config.configuration }.not_to raise_error
        end
      end

      context "package cache configuration enabled" do
        before { environment["BOSH_CACHE_ACCESS_KEY_ID"] = "cache_access_key" }
        it_needs_env "BOSH_CACHE_SECRET_ACCESS_KEY"
      end
    end

    describe "rendering the configuration yaml" do
      describe "invalid configuration" do
        before { environment.delete("BOSH_AWS_ACCESS_KEY_ID") }

        it "does not render the hash" do
          expect { config.configuration }.to raise_error(Bosh::Aws::ConfigurationInvalid)
        end
      end

      it "loads secret access key" do
        configuration['aws']['secret_access_key'].should == "secret_access_key"
      end

      it "loads access key id" do
        configuration['aws']['access_key_id'].should == "access_key_id"
      end

      it "loads vpc domains" do
        configuration['name'].should == "burritos"
        configuration['vpc']['domain'].should == "burritos.cf-app.com"
      end

      it "loads the primary availability zone" do
        configuration['vpc']['subnets']['bosh1']['availability_zone'].should == "primary_az"
        configuration['vpc']['subnets']['cf1']['availability_zone'].should == "primary_az"
        configuration['vpc']['subnets']['services1']['availability_zone'].should == "primary_az"
        configuration['vpc']['subnets']['cf_rds1']['availability_zone'].should == "primary_az"
      end

      it "loads the secondary availability zone" do
        configuration['vpc']['subnets']['cf_rds2']['availability_zone'].should == "secondary_az"
      end

      context "when the key pair name is set" do
        it "loads the key pair name" do
          environment["BOSH_KEY_PAIR_NAME"] = "key name"

          configuration['vpc']['subnets']['bosh1']['nat_instance']['key_name'].should == "key name"
          configuration['key_pairs'].should have_key "key name"
        end
      end

      context "when the key pair name is not set" do
        it "loads the default key pair name" do
          configuration['vpc']['subnets']['bosh1']['nat_instance']['key_name'].should == "bosh"
          configuration['key_pairs'].should have_key "bosh"
        end
      end

      context "when the key path is set" do
        it "loads the key path" do
          environment["BOSH_KEY_PATH"] = "key path"

          configuration['key_pairs']["bosh"].should == "key path"
        end
      end

      context "when the key path is not set" do
        it "loads the default key path" do
          environment["HOME"] = "/home/bosh"

          configuration['key_pairs']["bosh"].should == "/home/bosh/.ssh/id_rsa_bosh"
        end
      end

      context "when the ssl key file name is set" do
        it "loads the ssh key file name" do
          environment["BOSH_AWS_ELB_SSL_KEY"] = "ssl_key"

          configuration['ssl_certs']['cfrouter_cert']['private_key_path'].should == "ssl_key"
        end
      end

      context "when the ssl key file name is not set" do
        it "loads the default ssl key file name" do
          configuration['ssl_certs']['cfrouter_cert']['private_key_path'].should == "elb-cfrouter.key"
        end
      end

      context "when the director ssl key file name is set" do
        it "loads the ssh key file name" do
          environment["BOSH_DIRECTOR_SSL_KEY"] = "ssl_key"

          configuration['ssl_certs']['director_cert']['private_key_path'].should == "ssl_key"
        end
      end

      context "when the director ssl key file name is not set" do
        it "loads the default ssl key file name" do
          configuration['ssl_certs']['director_cert']['private_key_path'].should == "director.key"
        end
      end

      context "when the domain name is set" do
        it "loads the domain name" do
          environment["BOSH_VPC_DOMAIN"] = "domain"

          configuration['vpc']['domain'].should == "burritos.domain"
        end
      end

      context "when the domain name is not set" do
        it "loads the default domain name" do
          configuration['vpc']['domain'].should == "burritos.cf-app.com"
        end
      end

      context "when the ssl cert file name is set" do
        it "loads the ssh cert file name" do
          environment["BOSH_AWS_ELB_SSL_CERT"] = "ssl_cert"

          configuration['ssl_certs']['cfrouter_cert']['certificate_path'].should == "ssl_cert"
        end
      end

      context "when the ssl cert file name is not set" do
        it "loads the default ssl cert file name" do
          configuration['ssl_certs']['cfrouter_cert']['certificate_path'].should == "elb-cfrouter.pem"
        end
      end

      context "when the director ssl cert file name is set" do
        it "loads the ssh cert file name" do
          environment["BOSH_DIRECTOR_SSL_CERT"] = "ssl_cert"

          configuration['ssl_certs']['director_cert']['certificate_path'].should == "ssl_cert"
        end
      end

      context "when the director ssl cert file name is not set" do
        it "loads the default ssl cert file name" do
          configuration['ssl_certs']['director_cert']['certificate_path'].should == "director.pem"
        end
      end

      it "loads the bosh ssl chain zone" do
        environment["BOSH_AWS_ELB_SSL_CHAIN"] = "ssl_chain"
        configuration['ssl_certs']['cfrouter_cert']['certificate_chain_path'].should == "ssl_chain"
      end

      it "should not use a larger database size by default" do
        configuration["rds"][0]["aws_creation_options"]["db_instance_class"].should == "db.t1.micro"
      end

      context "when the cache credentials are not set" do
        before do
          environment.delete("BOSH_CACHE_ACCESS_KEY_ID")
        end

        it "should not set the package cache keys" do
          configuration.should_not have_key("compiled_package_cache")
        end

        it "should not have package cache configured" do
          config.should_not have_package_cache_configuration
        end
      end

      context "when cache credentials are set" do
        before do
          environment["BOSH_CACHE_ACCESS_KEY_ID"] = "cache_access_key_id"
          environment["BOSH_CACHE_SECRET_ACCESS_KEY"] = "cache_secret_access_key"
          environment["BOSH_CACHE_BUCKET_NAME"] = "gimme_mah_bukkit"
        end

        context "when the bucket name is not set" do
          it "loads the default value for the bucket name" do
            environment.delete("BOSH_CACHE_BUCKET_NAME")

            configuration["compiled_package_cache"]["bucket_name"].should == "bosh-global-package-cache"
          end
        end

        it "should have package cache configured" do
          config.should have_package_cache_configuration
        end

        it "loads the cache access key id" do
          configuration.should have_key("compiled_package_cache")
          configuration["compiled_package_cache"]["access_key_id"].should == "cache_access_key_id"
          configuration["compiled_package_cache"]["secret_access_key"].should == "cache_secret_access_key"
          configuration["compiled_package_cache"]["bucket_name"].should == "gimme_mah_bukkit"
        end
      end

      context "with production resources" do
        before do
          environment["BOSH_PRODUCTION_RESOURCES"] = "true"
        end

        it "should use a larger database size" do
          configuration["rds"][0]["aws_creation_options"]["db_instance_class"].should == "db.m1.large"
        end
      end
    end
  end

  context "no subdomain configuration" do
    before do
      environment["BOSH_VPC_SECONDARY_AZ"]        = "secondary_az"
      environment["BOSH_VPC_PRIMARY_AZ"]          = "primary_az"
      environment["BOSH_AWS_ACCESS_KEY_ID"]       = "access_key_id"
      environment["BOSH_AWS_SECRET_ACCESS_KEY"]   = "secret_access_key"
      environment["BOSH_CACHE_SECRET_ACCESS_KEY"] = "subdomain"
      environment["BOSH_VPC_DOMAIN"]              = "example.com"

      environment.delete("BOSH_VPC_SUBDOMAIN")
    end

    context "when the domain is not set" do
      before do
        environment.delete("BOSH_VPC_DOMAIN")
      end

      it "should raise an error" do
        expect { config.configuration }.to raise_error(Bosh::Aws::ConfigurationInvalid, 'No domain and subdomain are defined.')
      end
    end

    it "loads vpc domains" do
      configuration['name'].should == "example-com"
      configuration['vpc']['domain'].should == "example.com"
    end
  end
end
