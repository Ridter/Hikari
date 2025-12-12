#!/bin/bash
# quick_test.sh - 快速增量编译和测试脚本
#
# 使用方法:
#   ./quick_test.sh              # 增量编译 + 快速测试
#   ./quick_test.sh build        # 只增量编译
#   ./quick_test.sh test [pass]  # 运行测试 (可选: mba/icall/indbr/all)
#   ./quick_test.sh ir [pass]    # 查看生成的 IR

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

CLANG="$SCRIPT_DIR/build/bin/clang"
SDK_PATH=$(xcrun --show-sdk-path 2>/dev/null || echo "")
SYSROOT_FLAGS=""
if [ -n "$SDK_PATH" ]; then
    SYSROOT_FLAGS="-isysroot $SDK_PATH"
fi

# 获取 CPU 核心数
if [[ "$(uname)" == "Darwin" ]]; then
    JOBS=$(sysctl -n hw.ncpu)
else
    JOBS=$(nproc)
fi

do_build() {
    echo -e "${YELLOW}=== 增量编译 ===${NC}"
    echo "使用 $JOBS 个并行任务"

    time cmake --build build --target clang -j$JOBS

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}编译成功!${NC}"
        return 0
    else
        echo -e "${RED}编译失败!${NC}"
        return 1
    fi
}

do_build_lib() {
    echo -e "${YELLOW}=== 只编译 Obfuscation 库 ===${NC}"
    cmake --build build --target LLVMObfuscation -j$JOBS
}

do_test() {
    local pass="${1:-quick}"
    echo -e "${YELLOW}=== 运行测试: $pass ===${NC}"
    cd tests
    CLANG="$CLANG" ./run_tests.sh "$pass"
}

do_ir() {
    local pass="${1:-icall}"
    echo -e "${YELLOW}=== 生成 IR: $pass ===${NC}"
    cd tests

    local flags=""
    case "$pass" in
        mba)   flags="-mllvm -irobf-mba" ;;
        icall) flags="-mllvm -irobf-icall" ;;
        indbr) flags="-mllvm -irobf-indbr" ;;
        cse)   flags="-mllvm -irobf-cse" ;;
        *)     flags="-mllvm -irobf-$pass" ;;
    esac

    echo "生成未混淆 IR..."
    $CLANG $SYSROOT_FLAGS -S -emit-llvm test_obfuscation.c -o normal.ll

    echo "生成混淆 IR ($pass)..."
    $CLANG $SYSROOT_FLAGS $flags -S -emit-llvm test_obfuscation.c -o obf.ll

    echo ""
    echo "IR 行数对比:"
    echo "  未混淆: $(wc -l < normal.ll) 行"
    echo "  混淆后: $(wc -l < obf.ll) 行"

    echo ""
    echo "IR 文件已生成:"
    echo "  - tests/normal.ll"
    echo "  - tests/obf.ll"
}

show_help() {
    echo "快速增量编译和测试脚本"
    echo ""
    echo "使用方法:"
    echo "  $0                  增量编译 + 快速测试"
    echo "  $0 build            只增量编译 clang"
    echo "  $0 lib              只编译 LLVMObfuscation 库（最快）"
    echo "  $0 test [pass]      运行测试 (mba/icall/indbr/cse/all/quick)"
    echo "  $0 ir [pass]        生成并查看 IR (mba/icall/indbr/cse)"
    echo "  $0 help             显示帮助"
    echo ""
    echo "示例:"
    echo "  $0 test mba         只测试 MBA 混淆"
    echo "  $0 test all         测试所有混淆 pass"
    echo "  $0 ir icall         查看 icall 混淆的 IR"
}

case "${1:-default}" in
    build)
        do_build
        ;;
    lib)
        do_build_lib
        ;;
    test)
        do_test "$2"
        ;;
    ir)
        do_ir "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    default|"")
        do_build && do_test quick
        ;;
    *)
        echo -e "${RED}未知命令: $1${NC}"
        show_help
        exit 1
        ;;
esac
