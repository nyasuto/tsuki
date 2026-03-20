int main() {
    int a = 10;
    int b = 20;
    int *pa = &a;
    int *pb = &b;
    return *(pa + 1);
}
