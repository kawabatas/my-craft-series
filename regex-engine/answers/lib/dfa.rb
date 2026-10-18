require_relative 'nfa'

class DFAState
  attr_reader :transitions, :is_final
  def initialize(is_final); @is_final = is_final; @transitions = {}; end
  def add_transition(char, state); @transitions[char] = state; end
end

class DFACompiler
  include NFAOps

  def initialize(nfa_fragment)
    @start_state = nfa_fragment.start_state
    @nfa_end = nfa_fragment.end_state
  end

  def compile
    start_set = epsilon_closure(Set[@start_state])
    worklist = [start_set]
    generated = { start_set => DFAState.new(start_set.include?(@nfa_end)) }

    while !worklist.empty?
      curr_set = worklist.shift
      curr_dfa = generated[curr_set]

      chars = curr_set.map(&:char).compact.to_set
      chars.each do |char|
        next_set = epsilon_closure(move(curr_set, char))
        next if next_set.empty?

        unless generated.key?(next_set)
          generated[next_set] = DFAState.new(next_set.include?(@nfa_end))
          worklist << next_set
        end
        curr_dfa.add_transition(char, generated[next_set])
      end
    end
    generated[start_set]
  end
end

# DFA Runner: 1文字ごとに矢印を1本たどるだけ。迷いも後戻りもない
class DFARunner
  attr_reader :steps

  def initialize(start_state); @start_state = start_state; end

  def match?(text)
    @steps = 0
    state = @start_state
    text.each_char do |char|
      @steps += 1
      state = state.transitions[char] || state.transitions[:any]
      return false if state.nil?
    end
    state.is_final
  end
end
