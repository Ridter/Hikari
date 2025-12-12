#!/bin/bash
# run_tests.sh - Hikari 混淆测试主脚本
#
# 用法:
#   ./run_tests.sh              # 测试所有 pass
#   ./run_tests.sh mba          # 只测试 MBA
#   ./run_tests.sh icall        # 只测试 IndirectCall
#   ./run_tests.sh indbr        # 只测试 IndirectBranch
#   ./run_tests.sh cse          # 只测试 StringEncryption
#   ./run_tests.sh all          # 测试所有 pass (组合)
#   ./run_tests.sh quick        # 快速测试

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 初始化
init_test_env "${CLANG:-$SCRIPT_DIR/../build/bin/clang}"

cd "$SCRIPT_DIR"

echo "Hikari Obfuscation Test Suite"
echo "Clang: $CLANG"
echo ""

#=============================================================================
# 测试函数
#=============================================================================

test_mba() {
    print_header "MBA (Mixed Boolean-Arithmetic)"

    print_section "功能测试"
    run_test "无混淆基准" "test_obfuscation.c" "" "All tests passed"
    run_test "MBA 混淆" "test_obfuscation.c" "-mllvm -irobf-mba" "All tests passed"

    print_section "输出一致性"
    compare_test "MBA 对比" "test_obfuscation.c" "-mllvm -irobf-mba"

    print_section "IR 复杂度"
    ir_check "MBA IR 特征" "test_obfuscation.c" "-mllvm -irobf-mba" "mul"
}

test_icall() {
    print_header "IndirectCall (间接调用)"

    print_section "功能测试"
    run_test "icall 混淆" "test_obfuscation.c" "-mllvm -irobf-icall" "All tests passed"
    run_test "icall level=1" "test_obfuscation.c" "-mllvm -irobf-icall -mllvm -level-icall=1" "All tests passed"
    run_test "icall level=2" "test_obfuscation.c" "-mllvm -irobf-icall -mllvm -level-icall=2" "All tests passed"
    run_test "icall level=3" "test_obfuscation.c" "-mllvm -irobf-icall -mllvm -level-icall=3" "All tests passed"

    print_section "输出一致性"
    compare_test "icall 对比" "test_obfuscation.c" "-mllvm -irobf-icall"

    print_section "IR 特征"
    ir_check "间接调用表" "test_obfuscation.c" "-mllvm -irobf-icall" "call ptr"
}

test_indbr() {
    print_header "IndirectBranch (间接分支)"

    print_section "功能测试"
    run_test "indbr 混淆" "test_obfuscation.c" "-mllvm -irobf-indbr" "All tests passed"
    run_test "indbr level=1" "test_obfuscation.c" "-mllvm -irobf-indbr -mllvm -level-indbr=1" "All tests passed"

    print_section "输出一致性"
    compare_test "indbr 对比" "test_obfuscation.c" "-mllvm -irobf-indbr"

    print_section "IR 特征"
    ir_check "间接分支" "test_obfuscation.c" "-mllvm -irobf-indbr" "indirectbr"
}

test_cse() {
    print_header "StringEncryption (字符串加密)"

    print_section "功能测试"
    run_test "cse 混淆" "test_obfuscation.c" "-mllvm -irobf-cse" "All tests passed"

    print_section "输出一致性"
    compare_test "cse 对比" "test_obfuscation.c" "-mllvm -irobf-cse"
}

test_indgv() {
    print_header "IndirectGlobalVariable (间接全局变量)"

    print_section "功能测试"
    run_test "indgv 混淆" "test_obfuscation.c" "-mllvm -irobf-indgv" "All tests passed"

    print_section "输出一致性"
    compare_test "indgv 对比" "test_obfuscation.c" "-mllvm -irobf-indgv"
}

test_fla() {
    print_header "Flattening (控制流平坦化)"

    print_section "功能测试"
    run_test "fla 混淆" "test_obfuscation.c" "-mllvm -irobf-fla" "All tests passed"

    print_section "输出一致性"
    compare_test "fla 对比" "test_obfuscation.c" "-mllvm -irobf-fla"
}

test_cie() {
    print_header "ConstantIntEncryption (整数常量加密)"

    print_section "功能测试"
    run_test "cie 混淆" "test_obfuscation.c" "-mllvm -irobf-cie" "All tests passed"

    print_section "输出一致性"
    compare_test "cie 对比" "test_obfuscation.c" "-mllvm -irobf-cie"
}

test_combined() {
    print_header "组合测试"

    print_section "多 Pass 组合"
    run_test "mba + icall" "test_obfuscation.c" "-mllvm -irobf-mba -mllvm -irobf-icall" "All tests passed"
    run_test "icall + indbr" "test_obfuscation.c" "-mllvm -irobf-icall -mllvm -irobf-indbr" "All tests passed"
    run_test "全部 Pass" "test_obfuscation.c" "-mllvm -irobf-mba -mllvm -irobf-icall -mllvm -irobf-indbr -mllvm -irobf-cse -mllvm -irobf-indgv" "All tests passed"
}

test_quick() {
    print_header "快速测试"
    run_test "基准" "test_obfuscation.c" "" "All tests passed"
    run_test "MBA" "test_obfuscation.c" "-mllvm -irobf-mba" "All tests passed"
    run_test "icall" "test_obfuscation.c" "-mllvm -irobf-icall" "All tests passed"
}

test_all() {
    test_mba
    test_icall
    test_indbr
    test_cse
    test_indgv
    test_fla
    test_cie
    test_combined
}

#=============================================================================
# 主入口
#=============================================================================

case "${1:-all}" in
    mba)     test_mba ;;
    icall)   test_icall ;;
    indbr)   test_indbr ;;
    cse)     test_cse ;;
    indgv)   test_indgv ;;
    fla)     test_fla ;;
    cie)     test_cie ;;
    combined) test_combined ;;
    quick)   test_quick ;;
    all)     test_all ;;
    *)
        echo "用法: $0 [mba|icall|indbr|cse|indgv|fla|cie|combined|quick|all]"
        exit 1
        ;;
esac

print_summary
