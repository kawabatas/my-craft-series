require_relative 'ast'

class Parser
  def initialize(tokens); @tokens = tokens; @pos = 0; @group_count = 0; end

  def parse
    node = parse_union
    raise "Parse Error: unexpected ')'" if peek
    node
  end

  private
  def peek; @tokens[@pos]; end
  def consume; t = peek; @pos += 1; t; end

  def parse_union
    node = parse_concat
    while peek&.type == :pipe
      consume
      right = parse_concat
      node = Alternate.new(node, right)
    end
    node
  end

  def parse_concat
    nodes = []
    while peek && peek.type != :pipe && peek.type != :rparen
      nodes << parse_repeat
    end
    if nodes.empty?; Empty.new
    elsif nodes.length == 1; nodes[0]
    else; nodes.reverse.reduce { |acc, n| Sequence.new(n, acc) }
    end
  end

  def parse_repeat
    node = parse_atom
    while %i[star plus question].include?(peek&.type)
      case consume.type
      when :star     then node = Repeat.new(node)
      when :plus     then node = Sequence.new(node, Repeat.new(node))  # x+ = xx*
      when :question then node = Alternate.new(node, Empty.new)        # x? = x|
      end
    end
    node
  end

  def parse_atom
    t = consume
    if t.type == :lparen
      @group_count += 1
      index = @group_count # 開きカッコの順に番号を振る
      node = parse_union
      raise "Parse Error: missing ')'" unless consume&.type == :rparen
      Group.new(index, node)
    elsif t.type == :char
      Literal.new(t.value)
    elsif t.type == :dot
      AnyChar.new
    else; raise "Parse Error: unexpected '#{t.type}'"; end
  end
end
