require 'minitest/autorun'
require_relative '../lib/regex_engine'

# 付録の演習問題の解答を、Ruby本体の Regexp と突き合わせて検証する
class TestAnswers < Minitest::Test
  ALPHABET = %w[a b].freeze

  def random_pattern(rng, depth, empty: true)
    return (ALPHABET + ["."]).sample(random: rng) if depth.zero?
    sub = -> { random_pattern(rng, depth - 1, empty: empty) }
    case rng.rand(empty ? 8 : 7)
    when 0 then sub.()
    when 1 then sub.() + sub.()
    when 2 then "(#{sub.()}|#{sub.()})"
    when 3 then "(#{sub.()})*"
    when 4 then "(#{sub.()})+"
    when 5 then "(#{sub.()})?"
    when 6 then "(#{sub.()})"
    when 7 then "()"
    end
  end

  def nullable?(n)
    case n
    when Empty, Repeat then true
    when Literal, AnyChar then false
    when Sequence then nullable?(n.first) && nullable?(n.second)
    when Alternate then nullable?(n.left) || nullable?(n.right)
    when Group then nullable?(n.pattern)
    end
  end

  # 何も食べないこともある部分の繰り返しを含むか。空の繰り返しでのキャプチャはエンジンごとに挙動が異なる
  def empty_loop?(n)
    case n
    when Repeat then nullable?(n.pattern) || empty_loop?(n.pattern)
    when Sequence then empty_loop?(n.first) || empty_loop?(n.second)
    when Alternate then empty_loop?(n.left) || empty_loop?(n.right)
    when Group then empty_loop?(n.pattern)
    else false
    end
  end

  def random_text(rng) = Array.new(rng.rand(7)) { (ALPHABET + ["c"]).sample(random: rng) }.join

  def test_examples
    assert RegexEngine.build("a+", :dfa).match?("aaa")
    refute RegexEngine.build("a+", :dfa).match?("")
    assert RegexEngine.build("ab?c", :pike).match?("ac")
    assert RegexEngine.build("a.c", :nfa).match?("axc")
    refute RegexEngine.build("a.c", :nfa).match?("ac")
    assert RegexEngine.build_search("ab", :dfa).match?("xxabyy")
    assert_equal ["b", "c"], RegexEngine.build("a(b|x)(c)", :backtrack).match("abc")
  end

  def test_full_match_against_ruby
    rng = Random.new(1)
    300.times do
      pattern = random_pattern(rng, 4)
      reference = Regexp.new("\\A(?:#{pattern})\\z")
      runners = RegexEngine::ENGINES.to_h { |e| [e, RegexEngine.build(pattern, e)] }
      10.times do
        text = random_text(rng)
        runners.each do |name, runner|
          assert_equal reference.match?(text), runner.match?(text), "#{name}: /#{pattern}/ =~ #{text.inspect}"
        end
      end
    end
  end

  def test_search_against_ruby
    rng = Random.new(2)
    200.times do
      pattern = random_pattern(rng, 3)
      reference = Regexp.new(pattern)
      runners = RegexEngine::ENGINES.to_h { |e| [e, RegexEngine.build_search(pattern, e)] }
      10.times do
        text = random_text(rng)
        runners.each do |name, runner|
          assert_equal reference.match?(text), runner.match?(text), "#{name}: search /#{pattern}/ in #{text.inspect}"
        end
      end
    end
  end

  def test_captures_against_ruby
    rng = Random.new(3)
    300.times do
      pattern = random_pattern(rng, 4, empty: false)
      next if empty_loop?(RegexEngine.parse(pattern))
      reference = Regexp.new("\\A(?:#{pattern})\\z")
      runner = RegexEngine.build(pattern, :backtrack)
      10.times do
        text = random_text(rng)
        expected = reference.match(text)&.captures
        msg = "/#{pattern}/ =~ #{text.inspect}"
        expected.nil? ? assert_nil(runner.match(text), msg) : assert_equal(expected, runner.match(text), msg)
      end
    end
  end
end
