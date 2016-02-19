module Bosh::Director
  class PermissionAuthorizer
    def initialize
      @director_uuid ||= Bosh::Director::Models::DirectorAttribute.uuid
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
      return true if has_admin_or_director_read_scope?(token_scopes)

      return contains_requested_scope?(provided_scopes, token_scopes)
    end

    def raise_error_if_no_write_permissions(provided_scopes, team_scopes)
      return if has_admin_or_director_scope?(provided_scopes)

      if (team_scopes & provided_scopes).empty?
        raise Bosh::Director::UnauthorizedToAccessDeployment,
          'You are unauthorized to view this deployment. Please contact the BOSH admin.'
      end
    end

    def transform_team_scope_to_teams(token_scopes)
      return [] if token_scopes.nil?
      team_scopes = token_scopes.map do |scope|
        match = scope.match(/bosh\.teams\.([^\.]*)\.admin/)
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

    private

    def intersect(valid_scopes, token_scopes)
      valid_scopes & token_scopes
    end
  end
end
