#!/bin/bash
# common.sh - 通用测试函数库
# 被其他测试脚本 source 使用

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 全局计数器
PASS=0
FAIL=0

# 初始化环境
init_test_env() {
    local clang_path="$1"

    if [ -z "$clang_path" ]; then
        # 默认路径
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        CLANG="$SCRIPT_DIR/../build/bin/clang"
    else
        CLANG="$clang_path"
    fi

    if [ ! -x "$CLANG" ]; then
        echo -e "${RED}错误: clang 不存在或不可执行: $CLANG${NC}"
        exit 1
    fi

    # macOS SDK
    SYSROOT_FLAGS=""
    if [[ "$(uname)" == "Darwin" ]]; then
        SDK_PATH=$(xcrun --show-sdk-path 2>/dev/null)
        if [ -n "$SDK_PATH" ]; then
            SYSROOT_FLAGS="-isysroot $SDK_PATH"
        fi
    fi

    export CLANG SYSROOT_FLAGS
}

# 打印测试头
print_header() {
    local title="$1"
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$title${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# 打印子标题
print_section() {
    local title="$1"
    echo ""
    echo -e "${YELLOW}--- $title ---${NC}"
}

# 编译并运行测试
# 用法: run_test "测试名" "源文件" "编译参数" "期望输出关键字"
run_test() {
    local name="$1"
    local src="$2"
    local flags="$3"
    local expected="$4"

    echo -n "  $name ... "

    local bin="${src%.c}_test_$$"

    # 编译
    if ! $CLANG $SYSROOT_FLAGS $flags "$src" -o "$bin" 2>/dev/null; then
        echo -e "${RED}编译失败${NC}"
        ((FAIL++))
        return 1
    fi

    # 运行
    local output
    if ! output=$("./$bin" 2>&1); then
        echo -e "${RED}运行失败${NC}"
        ((FAIL++))
        rm -f "$bin"
        return 1
    fi

    # 检查输出
    if echo "$output" | grep -q "$expected"; then
        echo -e "${GREEN}通过${NC}"
        ((PASS++))
    else
        echo -e "${RED}失败${NC}"
        echo "    期望: $expected"
        echo "    实际: $(echo "$output" | head -1)"
        ((FAIL++))
    fi

    rm -f "$bin"
}

# 对比测试：正常编译 vs 混淆编译
# 用法: compare_test "测试名" "源文件" "混淆参数"
compare_test() {
    local name="$1"
    local src="$2"
    local obf_flags="$3"

    echo -n "  $name (对比) ... "

    local bin_normal="${src%.c}_normal_$$"
    local bin_obf="${src%.c}_obf_$$"

    # 正常编译
    if ! $CLANG $SYSROOT_FLAGS "$src" -o "$bin_normal" 2>/dev/null; then
        echo -e "${RED}正常编译失败${NC}"
        ((FAIL++))
        return 1
    fi

    # 混淆编译
    if ! $CLANG $SYSROOT_FLAGS $obf_flags "$src" -o "$bin_obf" 2>/dev/null; then
        echo -e "${RED}混淆编译失败${NC}"
        ((FAIL++))
        rm -f "$bin_normal"
        return 1
    fi

    # 运行并对比
    local out_normal=$("./$bin_normal" 2>&1)
    local out_obf=$("./$bin_obf" 2>&1)

    if [ "$out_normal" = "$out_obf" ]; then
        echo -e "${GREEN}通过${NC}"
        ((PASS++))
    else
        echo -e "${RED}输出不一致${NC}"
        ((FAIL++))
    fi

    rm -f "$bin_normal" "$bin_obf"
}

# IR 特征检查
# 用法: ir_check "测试名" "源文件" "编译参数" "IR特征模式"
ir_check() {
    local name="$1"
    local src="$2"
    local flags="$3"
    local pattern="$4"

    echo -n "  $name (IR) ... "

    local ll="${src%.c}_$$.ll"

    if ! $CLANG $SYSROOT_FLAGS $flags -S -emit-llvm "$src" -o "$ll" 2>/dev/null; then
        echo -e "${RED}IR生成失败${NC}"
        ((FAIL++))
        return 1
    fi

    if grep -q "$pattern" "$ll"; then
        echo -e "${GREEN}通过${NC}"
        ((PASS++))
    else
        echo -e "${RED}未找到特征: $pattern${NC}"
        ((FAIL++))
    fi

    rm -f "$ll"
}

# 打印测试结果
print_summary() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "结果: ${GREEN}$PASS 通过${NC}, ${RED}$FAIL 失败${NC}"
    echo -e "${BLUE}========================================${NC}"

    if [ $FAIL -eq 0 ]; then
        echo -e "${GREEN}所有测试通过!${NC}"
        return 0
    else
        echo -e "${RED}有 $FAIL 个测试失败${NC}"
        return 1
    fi
}
