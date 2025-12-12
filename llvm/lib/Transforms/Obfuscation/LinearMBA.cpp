#include "llvm/Transforms/Obfuscation/LinearMBA.h"
#include "llvm/Transforms/Obfuscation/MBAMatrix.h"
#include "llvm/Transforms/Obfuscation/ObfuscationOptions.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/CFG.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instruction.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>
#include <map>
#include <random>
#include <vector>

#define DEBUG_TYPE "linear-mba"

using namespace llvm;

namespace llvm {

// 14 种位运算表达式的构建函数实现
Value *buildMBAExpr0(IRBuilder<> &IRB, Value *X, Value *Y) {
  return IRB.CreateAnd(X, Y);
}

Value *buildMBAExpr1(IRBuilder<> &IRB, Value *X, Value *Y) {
  return IRB.CreateAnd(X, IRB.CreateNot(Y));
}

Value *buildMBAExpr2(IRBuilder<> &IRB, Value *X, Value *Y) { return X; }

Value *buildMBAExpr3(IRBuilder<> &IRB, Value *X, Value *Y) {
  return IRB.CreateXor(IRB.CreateNot(X), Y);
}

Value *buildMBAExpr4(IRBuilder<> &IRB, Value *X, Value *Y) { return Y; }

Value *buildMBAExpr5(IRBuilder<> &IRB, Value *X, Value *Y) {
  return IRB.CreateXor(X, Y);
}

Value *buildMBAExpr6(IRBuilder<> &IRB, Value *X, Value *Y) {
  return IRB.CreateOr(X, Y);
}

Value *buildMBAExpr7(IRBuilder<> &IRB, Value *X, Value *Y) {
  return IRB.CreateNot(IRB.CreateOr(X, Y));
}

Value *buildMBAExpr8(IRBuilder<> &IRB, Value *X, Value *Y) {
  return IRB.CreateNot(IRB.CreateXor(X, Y));
}

Value *buildMBAExpr9(IRBuilder<> &IRB, Value *X, Value *Y) {
  return IRB.CreateNot(Y);
}

Value *buildMBAExpr10(IRBuilder<> &IRB, Value *X, Value *Y) {
  return IRB.CreateOr(X, IRB.CreateNot(Y));
}

Value *buildMBAExpr11(IRBuilder<> &IRB, Value *X, Value *Y) {
  return IRB.CreateNot(X);
}

Value *buildMBAExpr12(IRBuilder<> &IRB, Value *X, Value *Y) {
  return IRB.CreateOr(IRB.CreateNot(X), Y);
}

Value *buildMBAExpr13(IRBuilder<> &IRB, Value *X, Value *Y) {
  return IRB.CreateNot(IRB.CreateAnd(X, Y));
}

} // namespace llvm

namespace {

// 全局位运算项类型表
static std::vector<BitwiseTerm> TermType = {
    DEFINE_TERM_INFO(0),  DEFINE_TERM_INFO(1),  DEFINE_TERM_INFO(2),
    DEFINE_TERM_INFO(3),  DEFINE_TERM_INFO(4),  DEFINE_TERM_INFO(5),
    DEFINE_TERM_INFO(6),  DEFINE_TERM_INFO(7),  DEFINE_TERM_INFO(8),
    DEFINE_TERM_INFO(9),  DEFINE_TERM_INFO(10), DEFINE_TERM_INFO(11),
    DEFINE_TERM_INFO(12), DEFINE_TERM_INFO(13)};

struct LinearMBA : public FunctionPass {
  static char ID;
  ObfuscationOptions *ArgsOptions;

  LinearMBA(ObfuscationOptions *argsOptions) : FunctionPass(ID) {
    this->ArgsOptions = argsOptions;
  }

  StringRef getPassName() const override { return "LinearMBA"; }

  /// 随机选择额外的项来构建 MBA 表达式
  void randomSelectTerms(std::vector<LinearMBATerm> &SelectedTerms) {
    std::vector<BitwiseTerm *> Available;
    for (BitwiseTerm &BT : TermType) {
      bool B = false;
      for (auto Iter = SelectedTerms.begin(); Iter != SelectedTerms.end();
           Iter++) {
        if (Iter->TermInfo == &BT) {
          B = true;
          break;
        }
      }
      if (!B) {
        Available.push_back(&BT);
      }
    }
    std::shuffle(Available.begin(), Available.end(),
                 std::mt19937{std::random_device{}()});
    int Num = 5 - (int)SelectedTerms.size();
    for (int i = 0; i < Num; i++) {
      LinearMBATerm NewTerm = {Available[i], 0};
      SelectedTerms.push_back(NewTerm);
    }
    // 添加常数项 (TermInfo = nullptr 表示常数 -1)
    LinearMBATerm LastTerm = {nullptr, 0};
    SelectedTerms.push_back(LastTerm);
  }

  /// 使用矩阵求解计算各项系数
  void calcCoefficients(std::vector<LinearMBATerm> &SelectedTerms) {
    int Size = SelectedTerms.size();
    MBAMatrix Mat(4, Size);
    for (int i = 0; i < Size; i++) {
      for (int j = 0; j < 4; j++) {
        if (SelectedTerms[i].TermInfo != nullptr) {
          Mat.setElement(j, i, SelectedTerms[i].TermInfo->TruthTable[j]);
        } else {
          Mat.setElement(j, i, 1);
        }
      }
    }
    std::vector<int64_t> Result;
    Mat.solve(Result);
    for (int i = 0; i < Size; i++) {
      SelectedTerms[i].Coefficient = Result[i];
    }
  }

  /// 构建 MBA 表达式
  Value *buildLinearMBA(BinaryOperator *OriginalInsn,
                        std::vector<LinearMBATerm> &Terms) {
    IRBuilder<> IRB(OriginalInsn);
    std::shuffle(Terms.begin(), Terms.end(),
                 std::mt19937{std::random_device{}()});
    bool NSW = OriginalInsn->hasNoSignedWrap();
    bool NUW = OriginalInsn->hasNoUnsignedWrap();
    Value *X = OriginalInsn->getOperand(0), *Y = OriginalInsn->getOperand(1);
    Value *Expr = nullptr;
    for (LinearMBATerm &Term : Terms) {
      if (Term.Coefficient == 0) {
        continue;
      }
      Value *TermVal = nullptr;
      if (Term.TermInfo != nullptr) {
        TermVal = Term.TermInfo->Builder(IRB, X, Y);
      } else {
        TermVal = ConstantInt::getSigned(X->getType(), -1);
      }
      Value *Mul = ConstantInt::getSigned(X->getType(), Term.Coefficient);
      TermVal = IRB.CreateMul(Mul, TermVal, "", NUW, NSW);
      if (Expr != nullptr) {
        Expr = IRB.CreateAdd(Expr, TermVal, "", NUW, NSW);
      } else {
        Expr = TermVal;
      }
    }
    return Expr;
  }

  /// 处理单条指令
  bool processAt(Instruction &Insn) {
    std::vector<LinearMBATerm> TermsSelected;
    Value *Result = nullptr;
    if (isa<BinaryOperator>(Insn)) {
      BinaryOperator &BI = cast<BinaryOperator>(Insn);
      switch (BI.getOpcode()) {
      case BinaryOperator::Add:
        // x + y = x + y + 0 (使用 x 和 y 项)
        TermsSelected.push_back({&TermType[2], 0}); // x
        TermsSelected.push_back({&TermType[4], 0}); // y
        randomSelectTerms(TermsSelected);
        calcCoefficients(TermsSelected);
        TermsSelected[0].Coefficient += 1;
        TermsSelected[1].Coefficient += 1;
        Result = buildLinearMBA(&BI, TermsSelected);
        break;
      case BinaryOperator::Sub:
        // x - y = x - y + 0
        TermsSelected.push_back({&TermType[2], 0}); // x
        TermsSelected.push_back({&TermType[4], 0}); // y
        randomSelectTerms(TermsSelected);
        calcCoefficients(TermsSelected);
        TermsSelected[0].Coefficient += 1;
        TermsSelected[1].Coefficient -= 1;
        Result = buildLinearMBA(&BI, TermsSelected);
        break;
      case BinaryOperator::And:
        // x & y
        TermsSelected.push_back({&TermType[0], 0}); // x & y
        randomSelectTerms(TermsSelected);
        calcCoefficients(TermsSelected);
        TermsSelected[0].Coefficient += 1;
        Result = buildLinearMBA(&BI, TermsSelected);
        break;
      case BinaryOperator::Or:
        // x | y
        TermsSelected.push_back({&TermType[6], 0}); // x | y
        randomSelectTerms(TermsSelected);
        calcCoefficients(TermsSelected);
        TermsSelected[0].Coefficient += 1;
        Result = buildLinearMBA(&BI, TermsSelected);
        break;
      case BinaryOperator::Xor:
        // x ^ y
        TermsSelected.push_back({&TermType[5], 0}); // x ^ y
        randomSelectTerms(TermsSelected);
        calcCoefficients(TermsSelected);
        TermsSelected[0].Coefficient += 1;
        Result = buildLinearMBA(&BI, TermsSelected);
        break;
      default:
        break;
      }
    }
    if (Result != nullptr) {
      Insn.replaceAllUsesWith(Result);
      return true;
    } else {
      return false;
    }
  }

  /// 处理整个函数
  void process(Function &F) {
    std::vector<Instruction *> ToRemove;
    for (BasicBlock &BB : F) {
      for (Instruction &I : BB) {
        if (processAt(I)) {
          ToRemove.push_back(&I);
        }
      }
    }
    for (Instruction *I : ToRemove) {
      I->eraseFromParent();
    }
  }

  bool runOnFunction(Function &F) override {
    const auto opt = ArgsOptions->toObfuscate(ArgsOptions->mbaOpt(), &F);
    if (!opt.isEnabled()) {
      return false;
    }
    process(F);
    return true;
  }
};

} // anonymous namespace

char LinearMBA::ID = 0;

FunctionPass *llvm::createLinearMBAPass(ObfuscationOptions *Options) {
  return new LinearMBA(Options);
}

INITIALIZE_PASS(LinearMBA, "mba", "Enable Linear MBA Obfuscation", false, false)
