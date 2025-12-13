# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Hikari 是基于 LLVM 的代码混淆器（Goron 分支），在 LLVM IR 层面提供多种混淆技术。基于 LLVM 21.x，将自定义混淆 Pass 集成到 Clang/LLD 中。

**仓库**: KomiMoe/Hikari
**主分支**: llvm-21.x

## 构建命令

### Linux 构建
```bash
cmake -Bbuild -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_TARGETS_TO_BUILD="X86" \
  -DLLVM_OBFUSCATION_LINK_INTO_TOOLS=ON \
  -DCMAKE_INSTALL_PREFIX=install \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  llvm

cmake --build build --target install
```

### Windows 构建 (VS 2022 + Ninja)
```bash
# 从 x64 Native Tools Command Prompt for VS 2022 运行
cmake -DCMAKE_CXX_FLAGS="/utf-8" \
  -DCMAKE_INSTALL_PREFIX="./install" \
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang;lld;lldb" \
  -G "Ninja" ../llvm

ninja
ninja install
```

### macOS 构建 (ARM/Apple Silicon)
```bash
cmake -Bbuild -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
  -DLLVM_OBFUSCATION_LINK_INTO_TOOLS=ON \
  -DCMAKE_INSTALL_PREFIX=install \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  llvm

cmake --build build -j$(sysctl -n hw.ncpu)
cmake --build build --target install
```

**依赖安装：**
```bash
brew install ninja cmake
xcode-select --install
```

### Docker 构建
```bash
./docker-build.sh
```

### 快速增量编译
```bash
./quick_test.sh              # 增量编译 + 快速测试
./quick_test.sh build        # 只增量编译 clang
./quick_test.sh lib          # 只编译 LLVMObfuscation 库（最快，修改 Pass 后使用）
./quick_test.sh test all     # 运行所有测试
./quick_test.sh ir icall     # 查看 icall 混淆的 IR
```

### 单独编译目标
```bash
cmake --build build --target clang -j$(nproc)           # 编译 clang
cmake --build build --target LLVMObfuscation -j$(nproc) # 只编译混淆库
cmake --build build --target install                    # 完整安装
```

## 架构

### 混淆模块位置
所有混淆 Pass 位于 `llvm/lib/Transforms/Obfuscation/`：

- **ObfuscationPassManager.cpp/h** - 主调度器，管理所有 Pass
- **ObfuscationOptions.cpp/h** - 配置系统（CLI 参数、JSON 配置、注解）
- **IndirectBranch.cpp/h** - 加密分支目标 (`-mllvm -irobf-indbr`)
- **IndirectCall.cpp/h** - 加密函数调用目标 (`-mllvm -irobf-icall`)
- **IndirectGlobalVariable.cpp/h** - 混淆全局变量引用 (`-mllvm -irobf-indgv`)
- **StringEncryption.cpp/h** - 加密 C 字符串 (`-mllvm -irobf-cse`)
- **Flattening.cpp/h** - 控制流平坦化 (`-mllvm -irobf-fla`)
- **ConstantIntEncryption.cpp/h** - 整数常量加密 (`-mllvm -irobf-cie`)
- **ConstantFPEncryption.cpp/h** - 浮点常量加密 (`-mllvm -irobf-cfe`)
- **LinearMBA.cpp/h** - 混合布尔算术混淆 (`-mllvm -irobf-mba`)
- **MBAMatrix.cpp/h** - MBA 矩阵运算支持
- **MicrosoftRTTIEraser.cpp/h** - RTTI 名称擦除 (`-mllvm -irobf-rtti`)
- **LegacyLowerSwitch.cpp/h** - Switch 语句降级（Flattening 依赖）
- **CryptoUtils.cpp/h** - 加密工具类
- **Utils.cpp/h** - 通用工具函数

头文件位于 `llvm/include/llvm/Transforms/Obfuscation/`。

### 关键 CMake 选项
- `LLVM_OBFUSCATION_LINK_INTO_TOOLS=ON` - 将混淆链接到 clang/lld
- `LLVM_ENABLE_PROJECTS="clang;lld"` - 必需项目
- `LLVM_TARGETS_TO_BUILD="X86;AArch64"` - 目标架构
- `LLVM_APPEND_VC_REV=OFF` - 禁用版本控制信息嵌入（默认已关闭）

## 混淆使用

### 命令行参数
```bash
clang -mllvm -irobf-indbr -mllvm -irobf-icall main.c -o main
```

### 强度级别 (0-3)
```bash
clang -mllvm -irobf-icall -mllvm -level-icall=3 main.c
```

### 函数注解
```cpp
[[clang::annotate("+indbr +icall ^icall=3")]]
int main() { ... }
```

### JSON 配置
```bash
clang -mllvm -hikari-cfg="config.json" main.c
```

### 仅注解模式
仅使用 `-mllvm -irobf` 而不指定具体 Pass，可通过函数注解精确控制混淆范围：
```bash
clang -mllvm -irobf main.c  # 配合 [[clang::annotate("+icall")]] 使用
```

## 测试

### 运行测试
```bash
./tests/run_tests.sh all      # 测试所有 Pass
./tests/run_tests.sh mba      # 只测试 MBA
./tests/run_tests.sh icall    # 只测试 IndirectCall
./tests/run_tests.sh indbr    # 只测试 IndirectBranch
./tests/run_tests.sh cse      # 只测试 StringEncryption
./tests/run_tests.sh indgv    # 只测试 IndirectGlobalVariable
./tests/run_tests.sh fla      # 只测试 Flattening
./tests/run_tests.sh cie      # 只测试 ConstantIntEncryption
./tests/run_tests.sh cfe      # 只测试 ConstantFPEncryption
./tests/run_tests.sh combined # 测试多 Pass 组合
./tests/run_tests.sh quick    # 快速测试
```

### 测试文件
- `tests/test_obfuscation.c` - 统一测试用例
- `tests/run_tests.sh` - 测试主脚本
- `tests/common.sh` - 通用测试函数库

## Pass 执行顺序

Pass 按以下顺序执行（在 `ObfuscationPassManager.cpp` 中定义）：

1. ConstantIntEncryption (cie)
2. ConstantFPEncryption (cfe)
3. StringEncryption (cse) - 必须在 IndirectGlobalVariable 之前
4. IndirectGlobalVariable (indgv)
5. IndirectCall (icall)
6. Flattening (fla)
7. IndirectBranch (indbr)
8. MsRttiEraser (rtti)
9. LinearMBA (mba)

## Pass 集成点

混淆 Pass 通过 `llvm/lib/Passes/PassBuilderPipelines.cpp` 集成到 LLVM 管道：
- `ObfuscationPassManagerPass` 在模块优化阶段运行
- 需要 `#include "llvm/Transforms/Obfuscation/ObfuscationPassManager.h"`

## 代码审查指南

修改混淆 Pass 时：
- 验证更改不会破坏性能分析数据
- 确保调试信息保持有效，特别是分支和调用
- 密切关注修改函数控制流的代码
- 注意 Pass 执行顺序的依赖关系
- 修改后运行 `./quick_test.sh test all` 验证所有 Pass 正常工作
