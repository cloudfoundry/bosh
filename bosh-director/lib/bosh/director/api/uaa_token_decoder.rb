require 'uaa/info'

module Bosh
  module Director
    module Api
      class UAATokenDecoder
        class BadToken < StandardError
        end

        attr_reader :config

        def initialize(config, grace_period_in_seconds=0)
          @config = config
          @logger = Config.logger

          raise ArgumentError.new('grace period should be an integer') unless grace_period_in_seconds.is_a? Integer

          @grace_period_in_seconds = grace_period_in_seconds
          if grace_period_in_seconds < 0
            @grace_period_in_seconds = 0
            @logger.warn("negative grace period interval '#{grace_period_in_seconds}' is invalid, changed to 0")
          end
        end

        def decode_token(auth_token)
          return unless token_format_valid?(auth_token)

          if symmetric_key
            decode_token_with_symmetric_key(auth_token)
          else
            decode_token_with_asymmetric_key(auth_token)
          end
        rescue CF::UAA::TokenExpired => e
          @logger.warn('Token expired')
          raise BadToken.new(e.message)
        rescue CF::UAA::DecodeError, CF::UAA::AuthError => e
          @logger.warn("Invalid bearer token: #{e.inspect} #{e.backtrace}")
          raise BadToken.new(e.message)
        end

        private

        def token_format_valid?(auth_token)
          auth_token && auth_token.upcase.start_with?('BEARER')
        end

        def decode_token_with_symmetric_key(auth_token)
          decode_token_with_key(auth_token, skey: symmetric_key)
        end

        def decode_token_with_asymmetric_key(auth_token)
          tries = 2
          begin
            tries -= 1
            decode_token_with_key(auth_token, pkey: asymmetric_key.value)
          rescue CF::UAA::InvalidSignature
            asymmetric_key.refresh
            tries > 0 ? retry : raise
          end
        end

        def decode_token_with_key(auth_token, options)
          options = { audience_ids: config[:resource_id] }.merge(options)
          token = CF::UAA::TokenCoder.new(options).decode_at_reference_time(auth_token, Time.now.utc.to_i - @grace_period_in_seconds)
          expiration_time = token['exp'] || token[:exp]
          if expiration_time && expiration_time < Time.now.utc.to_i
            @logger.warn("token currently expired but accepted within grace period of #{@grace_period_in_seconds} seconds")
          end
          token
        end

        def symmetric_key
          config[:symmetric_secret]
        end

        def asymmetric_key
          info = CF::UAA::Info.new(config[:url])
          @asymmetric_key ||= UAAVerificationKey.new(config[:verification_key], info)
        end
      end
    end
  end
end
