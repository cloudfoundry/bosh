module VSphereCloud
  class PathFinder
    def path(managed_object)
      path_objects = []
      until managed_object.parent.instance_of?(VimSdk::Vim::Datacenter)
        path_objects.unshift(managed_object.name)
        managed_object = managed_object.parent
      end
      path_objects.join('/')
    end
  end
end
