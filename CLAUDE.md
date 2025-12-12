# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hikari is an LLVM-based code obfuscator (fork of Goron) that provides multiple obfuscation techniques at the LLVM IR level. It extends LLVM 21.x with custom obfuscation passes integrated into Clang/LLD.

## Build Commands

### Linux Build
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

### Windows Build (VS 2022 + Ninja)
```bash
# Run from x64 Native Tools Command Prompt for VS 2022
cmake -DCMAKE_CXX_FLAGS="/utf-8" \
  -DCMAKE_INSTALL_PREFIX="./install" \
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang;lld;lldb" \
  -G "Ninja" ../llvm

ninja
ninja install
```

### Docker Build
```bash
./docker-build.sh
```

## Architecture

### Obfuscation Module Location
All obfuscation passes are in `llvm/lib/Transforms/Obfuscation/`:

- **ObfuscationPassManager.cpp/h** - Main orchestrator that manages all passes
- **ObfuscationOptions.cpp/h** - Configuration system (CLI args, JSON config, annotations)
- **IndirectBranch.cpp/h** - Encrypts branch targets (`-mllvm -irobf-indbr`)
- **IndirectCall.cpp/h** - Encrypts function call targets (`-mllvm -irobf-icall`)
- **IndirectGlobalVariable.cpp/h** - Obfuscates global variable references (`-mllvm -irobf-indgv`)
- **StringEncryption.cpp/h** - Encrypts C strings (`-mllvm -irobf-cse`)
- **Flattening.cpp/h** - Control flow flattening (`-mllvm -irobf-cff`)
- **ConstantIntEncryption.cpp/h** - Integer constant encryption (`-mllvm -irobf-cie`)
- **ConstantFPEncryption.cpp/h** - Floating-point constant encryption (`-mllvm -irobf-cfe`)
- **MicrosoftRTTIEraser.cpp/h** - RTTI name erasure (`-mllvm -irobf-rtti`)
- **CryptoUtils.cpp/h** - Cryptographic utilities
- **Utils.cpp/h** - General utilities

Headers are in `llvm/include/llvm/Transforms/Obfuscation/`.

### Key CMake Options
- `LLVM_OBFUSCATION_LINK_INTO_TOOLS=ON` - Links obfuscation into clang/lld
- `LLVM_ENABLE_PROJECTS="clang;lld"` - Required projects
- `LLVM_TARGETS_TO_BUILD="X86;AArch64"` - Target architectures

## Obfuscation Usage

### Command-line flags
```bash
clang -mllvm -irobf-indbr -mllvm -irobf-icall main.c -o main
```

### Intensity levels (0-3)
```bash
clang -mllvm -irobf-icall -mllvm -level-icall=3 main.c
```

### Function annotations
```cpp
[[clang::annotate("+indbr +icall ^icall=3")]]
int main() { ... }
```

### JSON configuration
```bash
clang -mllvm -hikari-cfg="config.json" main.c
```

## Code Review Guidelines

When modifying obfuscation passes:
- Verify changes don't corrupt performance profile data
- Ensure debug information remains valid, especially for branches and calls
- Pay close attention to code modifying function control flow
