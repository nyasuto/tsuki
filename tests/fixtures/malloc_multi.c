int main() {
    int* a = malloc(4);
    int* b = malloc(4);
    *a = 10;
    *b = 20;
    return *a + *b;
}
