class String

  unless method_defined?(:to_xs)
    define_method(:to_xs) do
      encode(:xml => :text)
    end
  end

end