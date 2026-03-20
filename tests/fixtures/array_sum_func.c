int sum(int* arr, int len) {
    int total = 0;
    int i = 0;
    while (i < len) {
        total = total + arr[i];
        i = i + 1;
    }
    return total;
}

int main() {
    int arr[5];
    arr[0] = 1;
    arr[1] = 2;
    arr[2] = 3;
    arr[3] = 4;
    arr[4] = 5;
    return sum(arr, 5);
}
