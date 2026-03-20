int main() {
    int a = 3;
    int b = 4;
    int eq = a == b;
    int ne = a != b;
    int lt = a < b;
    int gt = a > b;
    int le = a <= b;
    int ge = a >= b;
    return eq + ne * 2 + lt * 4 + gt * 8 + le * 16 + ge * 32;
}
