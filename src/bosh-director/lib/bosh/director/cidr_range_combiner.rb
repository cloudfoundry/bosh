module Bosh::Director
  class CidrRangeCombiner
    def combine_ranges(cidr_ranges)
      sorted_cidr_ranges = sort_ranges(cidr_ranges)
      min_max_cidr_tuples = min_max_tuples(sorted_cidr_ranges)
      combined_cidr_tuples = combine_adjacent_ranges(min_max_cidr_tuples)
      stringify_tuples(combined_cidr_tuples)
    end

    private

    def stringify_tuples(cidr_tuples)
      cidr_tuples.map { |tuple| [tuple[0].ip, tuple[1].ip] }
    end

    def sort_ranges(reserved_ranges)
      reserved_ranges.sort do |e1, e2|
        e1.to_i <=> e2.to_i
      end
    end

    def min_max_tuples(sorted_reserved_ranges)
      sorted_reserved_ranges.map do |r|
        [r.first(Objectify: true), r.last(Objectify: true)]
      end
    end

    def combine_adjacent_ranges(range_tuples)
      combined_ranges = []
      i = 0
      while i < range_tuples.length
        range_tuple = range_tuples[i]
        can_combine = true
        while can_combine
          next_range_tuple = range_tuples[i+1]
          if next_range_tuple.nil?
            can_combine = false
          else
            if range_tuple.map(&:version).uniq != next_range_tuple.map(&:version).uniq
              can_combine = false
              break
            end
            if range_tuple[1].succ == next_range_tuple[0]
              range_tuple[1] = next_range_tuple[1]
              i += 1
            # does not cover all cases: 10/32, 10/8
            elsif (range_tuple[0] < next_range_tuple[0]) && (range_tuple[1] > next_range_tuple[1])
              i += 1
            else
              can_combine = false
            end
          end
        end
        combined_ranges << range_tuple
        i += 1
      end
      combined_ranges
    end
  end
end
