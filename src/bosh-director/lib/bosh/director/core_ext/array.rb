class Array
  def to_openstruct
    map { |el| el.to_openstruct }
  end
end
