// test_obfuscation.c - 统一混淆测试用例
// 包含所有混淆 pass 的测试场景

#include <stdio.h>
#include <stdint.h>
#include <string.h>

//=============================================================================
// 1. 基础算术运算 (MBA 测试)
//=============================================================================

int add_func(int a, int b) { return a + b; }
int sub_func(int a, int b) { return a - b; }
int and_func(int a, int b) { return a & b; }
int or_func(int a, int b) { return a | b; }
int xor_func(int a, int b) { return a ^ b; }

int test_arithmetic() {
    int a = 0x12345678, b = 0x87654321;
    int pass = 1;

    pass &= (add_func(a, b) == (a + b));
    pass &= (sub_func(a, b) == (a - b));
    pass &= (and_func(a, b) == (a & b));
    pass &= (or_func(a, b) == (a | b));
    pass &= (xor_func(a, b) == (a ^ b));

    return pass;
}

//=============================================================================
// 2. 函数调用 (IndirectCall 测试)
//=============================================================================

typedef int (*BinaryOp)(int, int);

int op_add(int a, int b) { return a + b; }
int op_mul(int a, int b) { return a * b; }

int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

int test_calls() {
    int pass = 1;

    // 直接调用
    pass &= (op_add(10, 20) == 30);
    pass &= (op_mul(5, 6) == 30);

    // 递归调用
    pass &= (factorial(5) == 120);

    // 函数指针
    BinaryOp ops[] = {op_add, op_mul};
    pass &= (ops[0](3, 4) == 7);
    pass &= (ops[1](3, 4) == 12);

    return pass;
}

//=============================================================================
// 3. 分支控制流 (IndirectBranch / Flattening 测试)
//=============================================================================

int branch_test(int x) {
    if (x > 100) {
        return 1;
    } else if (x > 50) {
        return 2;
    } else if (x > 0) {
        return 3;
    } else {
        return 4;
    }
}

int switch_test(int x) {
    switch (x) {
        case 1: return 10;
        case 2: return 20;
        case 3: return 30;
        default: return 0;
    }
}

int test_branches() {
    int pass = 1;

    pass &= (branch_test(150) == 1);
    pass &= (branch_test(75) == 2);
    pass &= (branch_test(25) == 3);
    pass &= (branch_test(-5) == 4);

    pass &= (switch_test(1) == 10);
    pass &= (switch_test(2) == 20);
    pass &= (switch_test(3) == 30);
    pass &= (switch_test(99) == 0);

    return pass;
}

//=============================================================================
// 4. 字符串 (StringEncryption 测试)
//=============================================================================

const char *get_secret() {
    return "SECRET_STRING_12345";
}

int test_strings() {
    const char *s = get_secret();
    return strcmp(s, "SECRET_STRING_12345") == 0;
}

//=============================================================================
// 5. 常量 (ConstantIntEncryption 测试)
//=============================================================================

int use_constants() {
    int magic1 = 0xDEADBEEF;
    int magic2 = 0xCAFEBABE;
    return magic1 ^ magic2;
}

int test_constants() {
    return use_constants() == (0xDEADBEEF ^ 0xCAFEBABE);
}

//=============================================================================
// 6. 全局变量 (IndirectGlobalVariable 测试)
//=============================================================================

int global_counter = 0;
int global_array[4] = {1, 2, 3, 4};

int test_globals() {
    global_counter = 42;
    int sum = 0;
    for (int i = 0; i < 4; i++) {
        sum += global_array[i];
    }
    return (global_counter == 42) && (sum == 10);
}

//=============================================================================
// 主测试入口
//=============================================================================

int main() {
    int total = 0, passed = 0;

    printf("=== Hikari Obfuscation Tests ===\n\n");

    #define RUN_TEST(name, func) do { \
        total++; \
        if (func()) { \
            printf("[PASS] %s\n", name); \
            passed++; \
        } else { \
            printf("[FAIL] %s\n", name); \
        } \
    } while(0)

    RUN_TEST("Arithmetic (MBA)", test_arithmetic);
    RUN_TEST("Function Calls (icall)", test_calls);
    RUN_TEST("Branches (indbr/cff)", test_branches);
    RUN_TEST("Strings (cse)", test_strings);
    RUN_TEST("Constants (cie)", test_constants);
    RUN_TEST("Globals (indgv)", test_globals);

    printf("\n=== Results: %d/%d passed ===\n", passed, total);

    if (passed == total) {
        printf("All tests passed!\n");
        return 0;
    } else {
        printf("Some tests failed!\n");
        return 1;
    }
}
