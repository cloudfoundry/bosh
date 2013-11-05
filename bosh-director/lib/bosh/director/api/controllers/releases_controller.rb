require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class ReleasesController < BaseController
      post '/releases', :consumes => :tgz do
        options = {}
        options['remote'] = false
        options['rebase'] = true if params['rebase'] == 'true'

        task = @release_manager.create_release(@user, request.body, options)
        redirect "/tasks/#{task.id}"
      end

      post '/releases', :consumes => :json do
        options = {}
        options['remote'] = true
        options['rebase'] = true if params['rebase'] == 'true'
        payload = json_decode(request.body)

        task = @release_manager.create_release(@user, payload['location'], options)
        redirect "/tasks/#{task.id}"
      end

      get '/releases' do
        releases = Models::Release.order_by(:name.asc).map do |release|
          release_versions = release.versions_dataset.order_by(:version.asc).map do |rv|
            Hash['version', rv.version.to_s,
                 'commit_hash', rv.commit_hash,
                 'uncommitted_changes', rv.uncommitted_changes,
                 'currently_deployed', !rv.deployments.empty?,
                 'job_names', rv.templates.map(&:name)]
          end

          Hash['name', release.name,
               'release_versions', release_versions]
        end

        json_encode(releases)
      end

      get '/releases/:name' do
        name = params[:name].to_s.strip
        release = @release_manager.find_by_name(name)

        result = { }

        result['packages'] = release.packages.map do |package|
          {
            'name' => package.name,
            'sha1' => package.sha1,
            'version' => package.version.to_s,
            'dependencies' => package.dependency_set.to_a
          }
        end

        result['jobs'] = release.templates.map do |template|
          {
            'name' => template.name,
            'sha1' => template.sha1,
            'version' => template.version.to_s,
            'packages' => template.package_names
          }
        end

        result['versions'] = release.versions.map do |rv|
          rv.version.to_s
        end

        content_type(:json)
        json_encode(result)
      end

      delete '/releases/:name' do
        release = @release_manager.find_by_name(params[:name])

        options = {}
        options['force'] = true if params['force'] == 'true'
        options['version'] = params['version']

        task = @release_manager.delete_release(@user, release, options)
        redirect "/tasks/#{task.id}"
      end
    end
  end
end
