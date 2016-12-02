module Bosh::Registry

  class AWSCredentialsProvider < AWS::Core::CredentialProviders::DefaultProvider
    DEFAULT_RETRIES = 10

    def initialize(static_credentials = {})
      @providers = []
      @providers << AWS::Core::CredentialProviders::StaticProvider.new(static_credentials)
      @providers << AWS::Core::CredentialProviders::EC2Provider.new(:retries => DEFAULT_RETRIES)
    end
  end
end
