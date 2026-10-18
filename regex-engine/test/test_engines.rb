require 'minitest/autorun'
require_relative '../lib/regex_engine'

class TestEngines < Minitest::Test
  CASES = [
    ["a", "a", true], ["a", "", false], ["a", "b", false], ["a", "aa", false],
    ["ab", "ab", true], ["ab", "a", false], ["ab", "abc", false],
    ["a|b", "a", true], ["a|b", "b", true], ["a|b", "c", false],
    ["a*", "", true], ["a*", "aaaa", true], ["a*", "aab", false],
    ["(ab)*", "ababab", true], ["(ab)*", "aba", false],
    ["(a|b)*c", "abbac", true], ["(a|b)*c", "abba", false],
    ["", "", true], ["", "a", false], ["()*", "", true],
    ["(a*)*", "aaa", true], ["(a*)*b", "aaab", true], ["(a*)*b", "aaac", false],
    ["(a|)*", "aa", true], ["a**", "aaa", true],
    ["(a|a)*b", "aaaab", true], ["(a|a)*b", "aaaac", false],
    ["\\*", "*", true], ["\\(a\\)", "(a)", true],
  ].freeze

  RegexEngine::ENGINES.each do |engine|
    define_method("test_cases_#{engine}") do
      CASES.each do |pattern, text, expected|
        actual = RegexEngine.build(pattern, engine).match?(text)
        assert_equal expected, actual, "#{engine}: /#{pattern}/ =~ #{text.inspect}"
      end
    end
  end

  # ランダムな正規表現と文字列で、4エンジンとRuby本体の結果が一致するか確かめる
  def random_pattern(rng, depth)
    return %w[a b].sample(random: rng) if depth.zero?
    case rng.rand(5)
    when 0 then random_pattern(rng, depth - 1)
    when 1 then random_pattern(rng, depth - 1) + random_pattern(rng, depth - 1)
    when 2 then "(#{random_pattern(rng, depth - 1)}|#{random_pattern(rng, depth - 1)})"
    when 3 then "(#{random_pattern(rng, depth - 1)})*"
    when 4 then "()"
    end
  end

  def test_random_against_ruby_regexp
    rng = Random.new(42)
    500.times do
      pattern = random_pattern(rng, 4)
      reference = Regexp.new("\\A(?:#{pattern})\\z")
      engines = RegexEngine::ENGINES.to_h { |e| [e, RegexEngine.build(pattern, e)] }
      10.times do
        text = Array.new(rng.rand(7)) { %w[a b].sample(random: rng) }.join
        expected = reference.match?(text)
        engines.each do |name, runner|
          assert_equal expected, runner.match?(text), "#{name}: /#{pattern}/ =~ #{text.inspect}"
        end
      end
    end
  end
end
