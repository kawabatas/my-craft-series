require 'set'
require_relative 'vm'

# Pike VM Runner (幅優先探索)
# 全スレッドを1文字ずつ足並みをそろえて進める。同じPCのスレッドは1つにまとめる
class PikeVMRunner
  attr_reader :steps

  def initialize(insts); @insts = insts; end

  def match?(text)
    @steps = 0
    curr = []; add_thread(curr, 0, Set.new)
    text.each_char do |char|
      next_threads = []
      visited = Set.new
      curr.each do |pc|
        @steps += 1
        inst = @insts[pc]
        add_thread(next_threads, pc + 1, visited) if inst.opcode == :char && inst.arg1 == char
      end
      curr = next_threads
      return false if curr.empty?
    end
    curr.any? { |pc| @insts[pc].opcode == :match }
  end

  private
  # visited: この1文字の間に訪れたPC。JUMP/SPLIT の空回りループも防ぐ
  def add_thread(list, pc, visited)
    return if visited.include?(pc)
    visited.add(pc)
    inst = @insts[pc]
    if inst.opcode == :jump; add_thread(list, inst.arg1, visited)
    elsif inst.opcode == :split; add_thread(list, inst.arg1, visited); add_thread(list, inst.arg2, visited)
    else; list << pc
    end
  end
end
