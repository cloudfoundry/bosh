module Bosh::Director
  module DuplicateDetector
    def detect_duplicates(collection)
      transformed_elements = Set.new
      duplicated_elements = Set.new
      collection.each do |element|
        transformed = yield(element)

        if transformed_elements.include?(transformed)
          duplicated_elements << element
        else
          transformed_elements << transformed
        end
      end

      duplicated_elements
    end
  end
end
