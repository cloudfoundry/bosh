require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class ReleasesController < BaseController
      post '/', :consumes => :json do
        payload = json_decode(request.body)
        options = {
          rebase:         params['rebase'] == 'true',
          skip_if_exists: params['skip_if_exists'] == 'true',
        }
        task = @release_manager.create_release_from_url(current_user, payload['location'], options)
        redirect "/tasks/#{task.id}"
      end

      post '/', :consumes => :multipart do
        options = {
          rebase: params['rebase'] == 'true',
          compiled: params['compiled'] == 'true',
        }

        task = @release_manager.create_release_from_file_path(current_user, params[:nginx_upload_path], options)
        redirect "/tasks/#{task.id}"
      end

      get '/', scope: :read do
        releases = Models::Release.order_by(:name.asc).map do |release|
          release_versions = release.versions_dataset.order_by(:version.asc).map do |rv|
            {
              'version' => rv.version.to_s,
              'commit_hash' => rv.commit_hash,
              'uncommitted_changes' => rv.uncommitted_changes,
              'currently_deployed' => !rv.deployments.empty?,
              'job_names' => rv.templates.map(&:name),
            }
          end

          {
            'name' => release.name,
            'release_versions' => release_versions,
          }
        end

        json_encode(releases)
      end

      post '/export', consumes: :json do
        body_params = JSON.parse(request.body.read)

        deployment_name = body_params['deployment_name']
        release_name = body_params['release_name']
        release_version = body_params['release_version']
        stemcell_os = body_params['stemcell_os']
        stemcell_version = body_params['stemcell_version']

        task = @release_manager.export_release(
            current_user, deployment_name, release_name, release_version, stemcell_os, stemcell_version)

        redirect "/tasks/#{task.id}"
      end

      get '/:name', scope: :read do
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

      delete '/:name' do
        release = @release_manager.find_by_name(params[:name])

        options = {}
        options['force'] = true if params['force'] == 'true'
        options['version'] = params['version']

        task = @release_manager.delete_release(current_user, release, options)
        redirect "/tasks/#{task.id}"
      end
    end
  end
end
