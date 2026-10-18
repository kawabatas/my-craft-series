require 'minitest/autorun'
require_relative '../lib/regex_engine'

class TestParser < Minitest::Test
  # ASTを読みやすい文字列にする（テスト用）
  def show(node)
    case node
    when Empty     then "ε"
    when Literal   then node.char
    when Sequence  then "Seq(#{show(node.first)},#{show(node.second)})"
    when Alternate then "Alt(#{show(node.left)},#{show(node.right)})"
    when Repeat    then "Rep(#{show(node.pattern)})"
    end
  end

  def parse(src) = show(RegexEngine.parse(src))

  def test_tokenize
    tokens = Lexer.new("(a|b)*").tokenize
    assert_equal %i[lparen char pipe char rparen star], tokens.map(&:type)
  end

  def test_escape
    assert_equal [Token.new(:char, "*")], Lexer.new("\\*").tokenize
    assert_raises(RuntimeError) { Lexer.new("a\\").tokenize }
  end

  def test_precedence
    assert_equal "a", parse("a")
    assert_equal "Seq(a,b)", parse("ab")
    assert_equal "Seq(a,Seq(b,c))", parse("abc")
    assert_equal "Alt(a,b)", parse("a|b")
    assert_equal "Alt(Seq(a,b),c)", parse("ab|c")      # Concat > Union
    assert_equal "Seq(a,Rep(b))", parse("ab*")         # Repeat > Concat
    assert_equal "Rep(Seq(a,b))", parse("(ab)*")
    assert_equal "Rep(Rep(a))", parse("a**")
  end

  def test_empty
    assert_equal "ε", parse("")
    assert_equal "ε", parse("()")
    assert_equal "Alt(a,ε)", parse("a|")
  end

  def test_errors
    ["(a", "a)", "*", "a|*", "(*)"].each do |src|
      assert_raises(RuntimeError, src) { RegexEngine.parse(src) }
    end
  end
end
