module Bosh::Director
  module Api
    module Extensions
      module DeploymentsSecurity
        def route(verb, path, options = {}, &block)
          options[:scope] ||= :authorization
          options[:authorization] ||= :admin
          super(verb, path, options, &block)
        end

        def authorization(perm)
          return unless perm

          condition do
            subject = :director
            permission = perm

            if permission == :diff
              begin
                @deployment = Bosh::Director::Api::DeploymentLookup.new.by_name(params[:deployment])
                subject = @deployment
                permission = :admin
              rescue DeploymentNotFound
                permission = :create_deployment
              end
            elsif params.key?('deployment')
              @deployment = Bosh::Director::Api::DeploymentLookup.new.by_name(params[:deployment])
              subject = @deployment
            end

            @permission_authorizer.granted_or_raise(subject, permission, token_scopes)
          end
        end
      end
    end
  end
end
