module Bosh::Director
  class PermissionAuthorizer
    def initialize(uuid_provider)
      @uuid_provider = uuid_provider
    end

    def granted_or_raise(subject, permission, user_scopes)
      if !is_granted?(subject, permission, user_scopes)
        raise UnauthorizedToAccessDeployment, "Require one of the scopes: #{list_expected_scope(subject, permission, user_scopes).join(', ')}"
      end
    end

    def is_granted?(subject, permission, user_scopes)
      !intersect(user_scopes, list_expected_scope(subject, permission, user_scopes)).empty?
    end

    def list_expected_scope(subject, permission, user_scopes)
      expected_scope = director_permissions[:admin]

      if subject.instance_of? Models::Deployment
        expected_scope << deployment_team_scopes(subject, 'admin')

        if :admin == permission
          # already allowed with initial expected_scope
        elsif :read == permission
          expected_scope << director_permissions[:read]
          expected_scope << deployment_team_scopes(subject, 'read')
        else
          raise ArgumentError, "Unexpected permission for deployment: #{permission}"
        end
      elsif :director == subject
        if :admin == permission
          # already allowed with initial expected_scope
        elsif :create_deployment == permission
          expected_scope << user_scopes.select do |scope|
            scope.match(/\Abosh\.teams\.([^\.]*)\.admin\z/)
          end
        elsif :list_deployments == permission
          expected_scope << director_permissions[:read]
          expected_scope << user_scopes.select do |scope|
            scope.match(/\Abosh\.teams\.([^\.]*)\.(admin|read)\z/)
          end
        elsif :read == permission
          expected_scope << director_permissions[:read]
        else
          raise ArgumentError, "Unexpected permission for director: #{permission}"
        end
      else
        raise ArgumentError, "Unexpected subject: #{subject}"
      end

      expected_scope.flatten.uniq
    end

    private

    def director_permissions
      {
        read: ['bosh.read', "bosh.#{@uuid_provider.uuid}.read"],
        admin: ['bosh.admin', "bosh.#{@uuid_provider.uuid}.admin"],
      }
    end

    def deployment_team_scopes(deployment, permission)
      permissions = deployment.teams.nil? ? [] : deployment.teams.split(',')
      permissions.map{ |team_name| "bosh.teams.#{team_name}.#{permission}" }
    end

    def intersect(valid_scopes, token_scopes)
      valid_scopes & token_scopes
    end
  end
end
