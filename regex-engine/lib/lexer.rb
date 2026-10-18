Token = Struct.new(:type, :value)

class Lexer
  def initialize(source); @source = source; @len = source.length; @pos = 0; end

  def tokenize
    tokens = []
    while @pos < @len
      char = @source[@pos]
      case char
      when '(' then tokens << Token.new(:lparen, nil)
      when ')' then tokens << Token.new(:rparen, nil)
      when '|' then tokens << Token.new(:pipe, nil)
      when '*' then tokens << Token.new(:star, nil)
      when '\\'
        @pos += 1
        raise "Lex Error: pattern ends with '\\'" if @pos >= @len
        tokens << Token.new(:char, @source[@pos])
      else          tokens << Token.new(:char, char)
      end
      @pos += 1
    end
    tokens
  end
end
