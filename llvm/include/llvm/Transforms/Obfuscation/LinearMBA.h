#ifndef OBFUSCATION_LINEARMBA_H
#define OBFUSCATION_LINEARMBA_H

#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Pass.h"

namespace llvm {

class ObfuscationOptions;

/// BitwiseTerm - 表示一个位运算表达式项
/// TruthTable: 真值表 [f(0,0), f(0,1), f(1,0), f(1,1)]
/// Builder: 构建该表达式的函数指针
struct BitwiseTerm {
  int TruthTable[4];
  Value *(*Builder)(IRBuilder<> &, Value *, Value *);
};

/// LinearMBATerm - MBA 表达式中的一项
struct LinearMBATerm {
  BitwiseTerm *TermInfo;
  int64_t Coefficient;
};

// 14 种位运算表达式的构建函数声明
#define DEFINE_TERM_FUNC(ID)                                                   \
  Value *buildMBAExpr##ID(IRBuilder<> &, Value *, Value *)

// 真值表宏定义
#define TERM_0(x, y) ((x) & (y))
#define TERM_1(x, y) ((x) & ~(y))
#define TERM_2(x, y) (x)
#define TERM_3(x, y) (~(x) ^ (y))
#define TERM_4(x, y) (y)
#define TERM_5(x, y) ((x) ^ (y))
#define TERM_6(x, y) ((x) | (y))
#define TERM_7(x, y) (~((x) | (y)))
#define TERM_8(x, y) (~((x) ^ (y)))
#define TERM_9(x, y) (~(y))
#define TERM_10(x, y) ((x) | ~(y))
#define TERM_11(x, y) (~(x))
#define TERM_12(x, y) (~(x) | (y))
#define TERM_13(x, y) (~((x) & (y)))

// 生成 BitwiseTerm 结构的宏
#define DEFINE_TERM_INFO(ID)                                                   \
  {{(TERM_##ID(0, 0)) & 1, (TERM_##ID(0, 1)) & 1, (TERM_##ID(1, 0)) & 1,       \
    (TERM_##ID(1, 1)) & 1},                                                    \
   buildMBAExpr##ID}

// 声明所有表达式构建函数
DEFINE_TERM_FUNC(0);
DEFINE_TERM_FUNC(1);
DEFINE_TERM_FUNC(2);
DEFINE_TERM_FUNC(3);
DEFINE_TERM_FUNC(4);
DEFINE_TERM_FUNC(5);
DEFINE_TERM_FUNC(6);
DEFINE_TERM_FUNC(7);
DEFINE_TERM_FUNC(8);
DEFINE_TERM_FUNC(9);
DEFINE_TERM_FUNC(10);
DEFINE_TERM_FUNC(11);
DEFINE_TERM_FUNC(12);
DEFINE_TERM_FUNC(13);

#define TERM_TYPE_NUM 14

/// 创建 LinearMBA Pass
FunctionPass *createLinearMBAPass(ObfuscationOptions *Options);
void initializeLinearMBAPass(PassRegistry &Registry);

} // namespace llvm

#endif // OBFUSCATION_LINEARMBA_H
