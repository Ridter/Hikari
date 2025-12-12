#ifndef OBFUSCATION_MBAMATRIX_H
#define OBFUSCATION_MBAMATRIX_H

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <map>
#include <vector>

namespace llvm {

/// MBAMatrix - 用于求解 MBA (Mixed Boolean-Arithmetic) 线性方程组的矩阵类
/// 使用高斯消元法求解线性方程组，找到满足真值表约束的系数
class MBAMatrix {
private:
  int Line, Column;
  std::vector<std::vector<int64_t>> Elements;

  int64_t gcd(int64_t A, int64_t B) { return B == 0 ? A : gcd(B, A % B); }
  int64_t lcm(int64_t A, int64_t B) { return A * B / gcd(A, B); }

  /// 简化矩阵每行，除以公约数
  void simplify();

  /// 高斯消元
  void gaussian();

  /// 按首个非零元素位置排序行
  void sortLine();

  /// 获取某行首个非零元素的列索引
  int getLineFirstNonZero(int LineIdx);

  /// 消元操作
  void lineElimate(int Dst, int Src, int ColumnIdx);

  /// 行运算
  void calcLine(int64_t Factor1, int Dst, int64_t Factor2, int Src, bool IsAdd);

public:
  MBAMatrix(int Line, int Column) : Line(Line), Column(Column) {
    for (int i = 0; i < Line; i++) {
      std::vector<int64_t> LineNums;
      for (int j = 0; j < Column; j++) {
        LineNums.push_back(0);
      }
      Elements.push_back(LineNums);
    }
  }

  /// 从数组初始化矩阵
  void fromArray(int64_t *Arr);

  /// 获取矩阵元素
  int64_t getElement(int X, int Y);

  /// 设置矩阵元素
  void setElement(int X, int Y, int64_t Val);

  /// 获取矩阵的秩
  int getRank();

  /// 求解线性方程组
  void solve(std::vector<int64_t> &Solution);
};

} // namespace llvm

#endif // OBFUSCATION_MBAMATRIX_H
