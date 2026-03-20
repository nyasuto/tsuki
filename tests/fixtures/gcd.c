int gcd(int a, int b) {
    while (b != 0) {
        int tmp = b;
        b = a - (a / b) * b;
        a = tmp;
    }
    return a;
}

int main() {
    return gcd(12, 8);
}
