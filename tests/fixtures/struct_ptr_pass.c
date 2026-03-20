struct Point {
  int x;
  int y;
};

void set_point(struct Point* p, int x, int y) {
  p->x = x;
  p->y = y;
}

int main() {
  struct Point pt;
  pt.x = 0;
  pt.y = 0;
  set_point(&pt, 3, 4);
  return pt.x + pt.y;
}
