# ReDoS 再現実験: 悪魔の正規表現 (a|a)*b に "aaa...ac" を食べさせる
#
#   ruby bench/redos.rb [最大文字数] [タイムアウト秒]
#
# 文字数を1つ増やすごとに、各エンジンの処理ステップ数と時間がどう増えるかを表示する。
# タイムアウトを超えたエンジンは以降の計測をスキップする。
require 'benchmark'
require 'timeout'
require_relative '../lib/regex_engine'

PATTERN = "(a|a)*b"
max_n   = (ARGV[0] || 24).to_i
limit   = (ARGV[1] || 5).to_f

runners = RegexEngine::ENGINES.to_h { |e| [e, RegexEngine.build(PATTERN, e)] }
gave_up = {}

puts "pattern: /#{PATTERN}/  text: \"a\" * n + \"c\"  (timeout #{limit}s)"
puts format("%4s  %s", "n", RegexEngine::ENGINES.map { |e| format("%-22s", e) }.join)

(1..max_n).each do |n|
  text = "a" * n + "c"
  cells = RegexEngine::ENGINES.map do |engine|
    next format("%-22s", "(skip)") if gave_up[engine]

    runner = runners[engine]
    begin
      sec = Timeout.timeout(limit) { Benchmark.realtime { runner.match?(text) } }
      steps = runner.respond_to?(:steps) ? runner.steps : "-"
      format("%-22s", format("%9.4fs %10s", sec, steps))
    rescue Timeout::Error
      gave_up[engine] = true
      format("%-22s", "TIMEOUT")
    end
  end
  puts format("%4d  %s", n, cells.join)
end
