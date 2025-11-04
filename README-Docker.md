# Hikari LLVM Docker 构建指南

本文档介绍如何使用 Docker 在 Alpine 3.19 容器中构建 Hikari LLVM 混淆器，并在其他平台上使用编译产物。

## 快速开始

### 方法 1: 使用便捷脚本（推荐）

```bash
# 构建并提取 Hikari LLVM
./docker-build.sh

# 清理构建（无缓存）
./docker-build.sh --clean

# 仅构建镜像
./docker-build.sh --build-only

# 提取到自定义目录
./docker-build.sh --output /path/to/output
```

### 方法 2: 手动 Docker 命令

```bash
# 1. 构建 Docker 镜像
docker build -t hikari-llvm:alpine-3.19 .

# 2. 提取编译产物
docker create --name hikari-extract hikari-llvm:alpine-3.19
docker cp hikari-extract:/opt/hikari ./hikari-install
docker rm hikari-extract

# 3. 创建分发压缩包
tar -czf hikari-llvm-alpine-amd64.tar.gz -C hikari-install .
```

## 构建选项

### 环境变量

```bash
# 自定义镜像名称
export DOCKER_IMAGE_NAME=my-hikari
export DOCKER_IMAGE_TAG=latest
./docker-build.sh

# 自定义输出目录
export OUTPUT_DIR=/tmp/hikari-build
./docker-build.sh
```

### 脚本参数

```
-h, --help              显示帮助信息
-b, --build-only        仅构建 Docker 镜像
-e, --extract-only      仅从现有镜像提取文件
-c, --clean             清理构建（不使用缓存）
-o, --output DIR        指定输出目录
-t, --tag TAG           指定 Docker 镜像标签
```

## 使用编译后的 Clang

### 基本编译

```bash
# 设置路径（可选）
export PATH="$PWD/hikari-install/bin:$PATH"

# 普通编译
clang main.c -o main

# C++ 编译
clang++ main.cpp -o main
```

### 启用混淆功能

Hikari 提供多种混淆选项，通过 `-mllvm` 参数传递：

```bash
# 间接跳转混淆
clang -mllvm -irobf-indbr main.c -o main

# 间接函数调用混淆
clang -mllvm -irobf-icall main.c -o main

# 间接全局变量引用
clang -mllvm -irobf-indgv main.c -o main

# 字符串加密
clang -mllvm -irobf-cse main.c -o main

# 控制流平坦化
clang -mllvm -irobf-cff main.c -o main

# 整数常量加密
clang -mllvm -irobf-cie main.c -o main

# 浮点常量加密
clang -mllvm -irobf-cfe main.c -o main

# 组合使用多种混淆
clang -mllvm -irobf-indbr \
      -mllvm -irobf-icall \
      -mllvm -irobf-indgv \
      -mllvm -irobf-cse \
      -mllvm -irobf-cff \
      main.c -o main
```

### 混淆参数说明

| 参数 | 功能 | 说明 |
|------|------|------|
| `-mllvm -irobf-indbr` | 间接跳转 | 加密跳转目标地址 |
| `-mllvm -irobf-icall` | 间接函数调用 | 加密函数地址 |
| `-mllvm -irobf-indgv` | 间接全局变量 | 混淆全局变量引用 |
| `-mllvm -irobf-cse` | 字符串加密 | 加密字符串常量 |
| `-mllvm -irobf-cff` | 控制流平坦化 | 打乱控制流图 |
| `-mllvm -irobf-cie` | 整数常量加密 | 加密整数常量 |
| `-mllvm -irobf-cfe` | 浮点常量加密 | 加密浮点数常量 |

## 跨平台使用

### 在 macOS 上使用

编译后的二进制文件是 AMD64 Linux 版本，需要在 Linux 环境中使用：

```bash
# 方法 1: 在 Docker 容器中使用
docker run --rm -v $(pwd):/workspace hikari-llvm:alpine-3.19 \
    clang -mllvm -irobf-indbr /workspace/main.c -o /workspace/main

# 方法 2: 传输到 Linux 服务器使用
scp -r hikari-install/ user@linux-server:/opt/hikari
ssh user@linux-server "/opt/hikari/bin/clang --version"
```

### 在 Linux 上使用

```bash
# 直接使用（如果提取到本地）
./hikari-install/bin/clang main.c -o main

# 或者添加到系统路径
export PATH="/path/to/hikari-install/bin:$PATH"
clang main.c -o main
```

### 在 Windows 上使用

需要通过 WSL2 或虚拟机：

```bash
# WSL2 中使用
wsl
cd /mnt/c/path/to/hikari-install
./bin/clang main.c -o main
```

## 高级用法

### 在 Docker 容器中直接编译

如果不想提取文件，可以直接在容器中编译：

```bash
# 启动交互式容器
docker run -it --rm -v $(pwd):/workspace hikari-llvm:alpine-3.19 bash

# 在容器内编译
cd /workspace
clang -mllvm -irobf-indbr main.c -o main
```

### 创建便携式编译环境

```bash
# 构建包含源码的完整镜像
docker build -t hikari-compiler --target runtime .

# 创建编译脚本
cat > hikari-compile.sh << 'EOF'
#!/bin/bash
docker run --rm -v $(pwd):/workspace -w /workspace \
    hikari-llvm:alpine-3.19 \
    clang -mllvm -irobf-indbr \
          -mllvm -irobf-icall \
          -mllvm -irobf-cse \
          "$@"
EOF
chmod +x hikari-compile.sh

# 使用
./hikari-compile.sh main.c -o main
```

### 自定义 CMake 配置

如需修改编译配置，编辑 [Dockerfile](Dockerfile) 中的 CMake 参数：

```dockerfile
RUN cmake -B/build/build-hikari -G Ninja \
    -DLLVM_TARGETS_TO_BUILD="X86;ARM;AArch64" \  # 添加更多目标架构
    -DLLVM_ENABLE_PROJECTS="clang;lld;lldb" \     # 添加更多项目
    # ... 其他参数
```

## 构建信息

### 编译配置

- **基础镜像**: Alpine Linux 3.19
- **目标架构**: AMD64 (x86_64)
- **编译器**: Clang/LLVM
- **构建系统**: Ninja
- **LLVM 目标**: X86
- **启用项目**: Clang, LLD
- **关键特性**: `LLVM_OBFUSCATION_LINK_INTO_TOOLS=ON`

### 包含的工具

编译后的 `hikari-install/bin/` 目录包含：

- `clang` - C 编译器（带混淆功能）
- `clang++` - C++ 编译器（带混淆功能）
- `clang-format` - 代码格式化工具
- `lld` - LLVM 链接器
- `ld.lld` - LLD 兼容链接器
- `llvm-ar` - LLVM 归档工具
- `llvm-nm` - 符号表查看器
- `llvm-objdump` - 对象文件查看器
- `llvm-ranlib` - 符号表索引工具
- `llvm-strip` - 符号剥离工具
- 其他 LLVM 工具...

### 文件大小

预期编译产物大小：

- Docker 镜像: ~2-3 GB
- 提取的安装目录: ~1-2 GB
- 压缩后的 tar.gz: ~500 MB - 1 GB

## 故障排查

### 构建失败

```bash
# 清理缓存重新构建
./docker-build.sh --clean

# 查看详细构建日志
docker build --progress=plain -t hikari-llvm:alpine-3.19 .
```

### 内存不足

```bash
# 限制并行编译任务
docker build --build-arg CORES=2 -t hikari-llvm:alpine-3.19 .
```

### 提取文件权限问题

```bash
# 修正权限
sudo chown -R $USER:$USER hikari-install/
```

## 参考资源

- [Hikari LLVM 混淆器主仓库](https://github.com/KomiMoe/Hikari)
- [LLVM 官方文档](https://llvm.org/docs/)
- [Linux 构建工作流](.github/workflows/linux-llvm-build.yml)

## 许可证

本构建配置遵循 Hikari LLVM 项目的开源许可证。请查看主项目 LICENSE 文件了解详情。

## 支持

如遇问题，请：

1. 检查 Docker 是否正常运行
2. 确认有足够的磁盘空间（至少 15 GB）
3. 查看构建日志定位错误
4. 在项目 Issues 中搜索类似问题

---

**构建时间**: 预计 30-90 分钟（取决于硬件配置）
**推荐配置**: 16 GB RAM, 4+ CPU 核心, 15 GB 可用磁盘空间
