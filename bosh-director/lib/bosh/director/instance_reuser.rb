module Bosh::Director
  class NilInstanceError < ArgumentError; end

  class InstanceReuser
    def initialize
      @idle_instances_by_stemcell = {}
      @in_use_instances_by_stemcell = {}
      @mutex = Mutex.new
    end

    def add_in_use_instance(instance, stemcell)
      raise NilInstanceError if instance.nil?
      canonical_stemcell = canonical(stemcell)
      @mutex.synchronize do
        @in_use_instances_by_stemcell[canonical_stemcell] ||= []
        @in_use_instances_by_stemcell[canonical_stemcell] << instance
      end
    end

    def get_instance(stemcell)
      canonical_stemcell = canonical(stemcell)
      @mutex.synchronize do
        return nil if @idle_instances_by_stemcell[canonical_stemcell].nil?
        instance = @idle_instances_by_stemcell[canonical_stemcell].pop
        return nil if instance.nil?
        @in_use_instances_by_stemcell[canonical_stemcell] ||= []
        @in_use_instances_by_stemcell[canonical_stemcell] << instance
        return instance
      end
    end

    def release_instance(instance)
      raise NilInstanceError if instance.nil?
      @mutex.synchronize do
        release_without_lock(instance)
      end
    end

    def remove_instance(instance)
      raise NilInstanceError if instance.nil?
      @mutex.synchronize do
        release_without_lock(instance)
        @idle_instances_by_stemcell.each_value do |idle_instances|
          idle_instances.each do |idle_instance|
            idle_instances.delete(idle_instance) if instance == idle_instance
          end
        end
      end
    end

    def get_num_instances(stemcell)
      canonical_stemcell = canonical(stemcell)
      @mutex.synchronize do
        idle_count = @idle_instances_by_stemcell.fetch(canonical_stemcell, []).size
        in_use_count = @in_use_instances_by_stemcell.fetch(canonical_stemcell, []).size
        idle_count + in_use_count
      end
    end

    def each
      all_instances = (@idle_instances_by_stemcell.values + @in_use_instances_by_stemcell.values).flatten
      all_instances.each do |instance|
        yield instance
      end
    end

    private

    def release_without_lock(instance)
      @in_use_instances_by_stemcell.each do |canonical_stemcell, in_use_instances|
        in_use_instances.each do |in_use_instance|
          if instance == in_use_instance
            in_use_instances.delete(in_use_instance)
            @idle_instances_by_stemcell[canonical_stemcell] ||= []
            @idle_instances_by_stemcell[canonical_stemcell] << instance
          end
        end
      end
    end

    def canonical(stemcell)
      stemcell.desc
    end
  end
end
