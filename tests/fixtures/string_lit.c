int get_addr(char* p) {
    return p;
}

int main() {
    int a = get_addr("Hello");
    int b = get_addr("Hello");
    return b - a;
}
