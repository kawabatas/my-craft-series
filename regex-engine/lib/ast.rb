class Pattern
  def match(str); raise NotImplementedError; end

  # 全体一致: 文字列を残さず食べ切れる道が1つでもあれば成功
  def full_match?(str); match(str).include?(""); end
end

class Empty < Pattern
  def inspect; "Empty"; end
  def match(str); [str]; end
end

class Literal < Pattern
  attr_reader :char
  def initialize(char); @char = char; end
  def inspect; "Literal(#{@char.inspect})"; end
  def match(str); (!str.empty? && str[0] == @char) ? [str[1..-1]] : []; end
end

class Sequence < Pattern
  attr_reader :first, :second
  def initialize(first, second); @first = first; @second = second; end
  def inspect; "Sequence(#{@first.inspect}, #{@second.inspect})"; end
  def match(str); @first.match(str).flat_map { |rest| @second.match(rest) }; end
end

class Alternate < Pattern
  attr_reader :left, :right
  def initialize(left, right); @left = left; @right = right; end
  def inspect; "Alternate(#{@left.inspect}, #{@right.inspect})"; end
  def match(str); @left.match(str) + @right.match(str); end
end

class Repeat < Pattern
  attr_reader :pattern
  def initialize(pattern); @pattern = pattern; end
  def inspect; "Repeat(#{@pattern.inspect})"; end
  def match(str)
    # 1文字も進まない繰り返しは打ち切る（無限ループ防止）
    matches = @pattern.match(str).flat_map do |rest|
      rest.length < str.length ? match(rest) : []
    end
    matches + [str]
  end
end
