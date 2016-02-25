module Bosh::Director
  class PermissionAuthorizer
    def initialize
      @director_uuid = Bosh::Director::Models::DirectorAttribute.uuid
    end

    def has_admin_or_director_scope?(token_scopes)
      !(intersect(permissions[:write], token_scopes).empty?)
    end

    def has_admin_or_director_read_scope?(token_scopes)
      !(intersect(permissions[:read], token_scopes).empty?)
    end

    def contains_requested_scope?(valid_scopes, token_scopes)
      return false unless valid_scopes
      !(intersect(valid_scopes, token_scopes).empty?)
    end

    def permissions
      {
        :read  => ['bosh.admin', "bosh.#{@director_uuid}.admin", 'bosh.read', "bosh.#{@director_uuid}.read"],
        :write => ['bosh.admin', "bosh.#{@director_uuid}.admin"]
      }
    end

    def is_authorized_to_read?(provided_scopes, token_scopes)
      has_admin_or_director_read_scope?(token_scopes) ||
        contains_requested_scope?(provided_scopes, token_scopes)
    end

    def transform_admin_team_scope_to_teams(token_scopes)
      return [] if token_scopes.nil?
      team_scopes = token_scopes.map do |scope|
        match = scope.match(/\Abosh\.teams\.([^\.]*)\.admin\z/)
        match[1] unless match.nil?
      end
      team_scopes.compact
    end

    def transform_teams_to_team_scopes(teams)
      return [] if teams.nil?
      teams.map do |team|
        "bosh.teams.#{team}.admin"
      end
    end

    def is_granted?(subject, right, user_scopes)
      director_permissions = permissions

      allowed_scope = [director_permissions[:write]]

      if subject.instance_of? Models::Deployment
        allowed_scope << deployment_team_scopes(subject, 'admin')

        if :admin == right
          # already allowed with initial allowed_scope
        elsif :read == right
          allowed_scope << director_permissions[:read]
          allowed_scope << deployment_team_scopes(subject, 'read')
        else
          raise ArgumentError, "Unexpected right for deployment: #{right}"
        end
      elsif :director == subject
        if :admin == right
          # already allowed with initial allowed_scope
        elsif :create_deployment == right
          allowed_scope << user_scopes.select do |scope|
            scope.match(/\Abosh\.teams\.([^\.]*)\.admin\z/)
          end
        elsif :list_deployments == right
          allowed_scope << director_permissions[:read]
          allowed_scope << user_scopes.select do |scope|
            scope.match(/\Abosh\.teams\.([^\.]*)\.(admin|read)\z/)
          end
        elsif :read == right
          allowed_scope << director_permissions[:read]
        else
          raise ArgumentError, "Unexpected right for director: #{right}"
        end
      else
        raise ArgumentError, "Unexpected subject: #{subject}"
      end

      !intersect(user_scopes, allowed_scope.flatten).empty?
    end

    private

    def deployment_team_scopes(deployment, right)
      rights = deployment.teams.nil? ? [] : deployment.teams.split(',')
      rights.map{ |team_name| "bosh.teams.#{team_name}.#{right}" }
    end

    def intersect(valid_scopes, token_scopes)
      valid_scopes & token_scopes
    end
  end
end
