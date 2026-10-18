require 'set'
require_relative 'ast'

# char が nil の状態は ε（空）遷移、文字を持つ状態は out1 へ進む
class State
  attr_accessor :char, :out1, :out2
  def initialize(char = nil); @char = char; @out1 = nil; @out2 = nil; end
end

class Fragment
  attr_accessor :start_state, :end_state
  def initialize(s, e); @start_state = s; @end_state = e; end
end

class NFACompiler
  def compile(node)
    case node
    when Literal
      s, e = State.new(node.char), State.new(nil)
      s.out1 = e; Fragment.new(s, e)
    when Sequence
      f1, f2 = compile(node.first), compile(node.second)
      f1.end_state.out1 = f2.start_state
      Fragment.new(f1.start_state, f2.end_state)
    when Alternate
      f1, f2 = compile(node.left), compile(node.right)
      s, e = State.new(nil), State.new(nil)
      s.out1, s.out2 = f1.start_state, f2.start_state
      f1.end_state.out1 = f2.end_state.out1 = e
      Fragment.new(s, e)
    when Repeat
      f = compile(node.pattern)
      s, e = State.new(nil), State.new(nil)
      s.out1, s.out2 = f.start_state, e
      f.end_state.out1, f.end_state.out2 = f.start_state, e
      Fragment.new(s, e)
    when Empty
      s, e = State.new(nil), State.new(nil)
      s.out1 = e; Fragment.new(s, e)
    when AnyChar
      s, e = State.new(:any), State.new(nil) # :any はどの文字にも一致する印
      s.out1 = e; Fragment.new(s, e)
    when Group
      compile(node.pattern) # 判定だけならカッコは素通り
    end
  end
end

# NFAの上で「いまいる状態の集合」を動かすための道具。NFARunner と DFACompiler で共有する
module NFAOps
  private
  # ε遷移だけでたどり着ける状態をすべて集める
  def epsilon_closure(states)
    stack, closure = states.to_a, states.dup
    while s = stack.pop
      [s.out1, s.out2].compact.each do |out|
        if s.char.nil? && !closure.include?(out)
          closure.add(out); stack.push(out)
        end
      end
    end
    closure
  end

  # 文字 char の矢印を1本進んだ先の状態を集める
  def move(states, char)
    states.select { |s| s.char == char || s.char == :any }.map(&:out1).to_set
  end
end

# NFA Runner: 可能性のある状態すべてに駒を置き、1文字ごとに全部の駒を進める
class NFARunner
  include NFAOps
  attr_reader :steps

  def initialize(fragment)
    @start_state = fragment.start_state
    @end_state = fragment.end_state
  end

  def match?(text)
    @steps = 0
    current = epsilon_closure(Set[@start_state])
    text.each_char do |char|
      @steps += current.size
      current = epsilon_closure(move(current, char))
      return false if current.empty?
    end
    current.include?(@end_state)
  end
end
