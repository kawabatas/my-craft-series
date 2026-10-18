require 'set'
require_relative 'ast'

Instruction = Struct.new(:opcode, :arg1, :arg2) do
  # CHAR 命令が文字 c に一致するか。:any はどの文字にも一致する
  def char_match?(c) = opcode == :char && !c.nil? && (arg1 == :any || arg1 == c)
end

class VMCompiler
  def initialize; @insts = []; end

  def compile(ast)
    generate(ast); emit(:match); @insts
  end

  private
  def emit(op, a1=nil, a2=nil)
    @insts << Instruction.new(op, a1, a2); @insts.length - 1
  end

  def generate(node)
    case node
    when Empty then nil # 何も食べないので命令も不要
    when Literal then emit(:char, node.char)
    when AnyChar then emit(:char, :any)
    when Group
      emit(:save, node.index * 2)
      generate(node.pattern)
      emit(:save, node.index * 2 + 1)
    when Sequence then generate(node.first); generate(node.second)
    when Alternate
      split = emit(:split)
      generate(node.left)
      jmp = emit(:jump)
      @insts[split].arg1 = split + 1
      @insts[split].arg2 = @insts.length
      generate(node.right)
      @insts[jmp].arg1 = @insts.length
    when Repeat
      start = @insts.length
      split = emit(:split)
      generate(node.pattern)
      emit(:jump, start)
      @insts[split].arg1 = split + 1
      @insts[split].arg2 = @insts.length
    end
  end
end

# Backtracking VM Runner (深さ優先探索)
# SPLIT で「もう一方の道」をスタックに積み、行き止まりになったら取り出して再開する
class BacktrackVMRunner
  attr_reader :steps

  def initialize(insts)
    @insts = insts
    @group_count = insts.select { |i| i.opcode == :save }.map(&:arg1).max.to_i / 2
  end

  def match?(text) = !match(text).nil?

  # マッチしたら各グループがキャプチャした文字列の配列を、しなければ nil を返す
  def match(text)
    @steps = 0
    stack = [[0, 0, Set.new, []]] # [PC, SP, 文字を食べずに通過したPC, キャプチャ位置]
    until stack.empty?
      pc, sp, seen, caps = stack.pop
      loop do
        @steps += 1
        # 文字を食べずに同じ命令へ戻ってきた = 空回りの無限ループなので打ち切る
        break if seen.include?(pc)
        seen.add(pc)
        inst = @insts[pc]
        case inst.opcode
        when :char
          break unless inst.char_match?(text[sp])
          pc += 1; sp += 1; seen = Set.new
        when :save
          caps = caps.dup # 別の道と記録を共有しないよう、書き込む前に複製する
          caps[inst.arg1] = sp
          pc += 1
        when :jump
          pc = inst.arg1
        when :split
          stack.push([inst.arg2, sp, seen.dup, caps])
          pc = inst.arg1
        when :match
          return captures(text, caps) if sp == text.length
          break
        end
      end
    end
    nil
  end

  private
  def captures(text, caps)
    (1..@group_count).map do |i|
      from, to = caps[i * 2], caps[i * 2 + 1]
      from && to ? text[from...to] : nil
    end
  end
end

# Memoized Backtracking VM Runner
# 一度訪れた (PC, SP) を全部の道で共有して記録し、二度目は試さない
class MemoizedBacktrackVMRunner
  attr_reader :steps

  def initialize(insts); @insts = insts; end

  def match?(text)
    @steps = 0
    visited = Set.new
    stack = [[0, 0]]
    until stack.empty?
      pc, sp = stack.pop
      loop do
        @steps += 1
        break unless visited.add?([pc, sp]) # 訪問済みなら、その先の結果はもう分かっている
        inst = @insts[pc]
        case inst.opcode
        when :char
          break unless inst.char_match?(text[sp])
          pc += 1; sp += 1
        when :save
          pc += 1
        when :jump
          pc = inst.arg1
        when :split
          stack.push([inst.arg2, sp])
          pc = inst.arg1
        when :match
          return true if sp == text.length
          break
        end
      end
    end
    false
  end
end
