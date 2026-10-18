require_relative 'lexer'
require_relative 'parser'
require_relative 'ast'
require_relative 'nfa'
require_relative 'dfa'
require_relative 'vm'
require_relative 'vm_pike'

# 各エンジンを同じ使い方で呼び出すための窓口
module RegexEngine
  ENGINES = %i[ast nfa dfa backtrack memo pike].freeze

  def self.parse(pattern)
    Parser.new(Lexer.new(pattern).tokenize).parse
  end

  # 返り値は match?(text) を持つオブジェクト
  def self.build(pattern, engine)
    ast = parse(pattern)
    case engine
    when :ast       then AstRunner.new(ast)
    when :nfa       then NFARunner.new(NFACompiler.new.compile(ast))
    when :dfa       then DFARunner.new(DFACompiler.new(NFACompiler.new.compile(ast)).compile)
    when :backtrack then BacktrackVMRunner.new(VMCompiler.new.compile(ast))
    when :memo      then MemoizedBacktrackVMRunner.new(VMCompiler.new.compile(ast))
    when :pike      then PikeVMRunner.new(VMCompiler.new.compile(ast))
    else raise ArgumentError, "unknown engine: #{engine}"
    end
  end

  AstRunner = Struct.new(:ast) do
    def match?(text); ast.full_match?(text); end
  end
end
