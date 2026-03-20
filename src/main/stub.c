#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

/* MoonBit runtime API */
extern void moonbit_decref(void *obj);
extern uint16_t *moonbit_make_string_raw(int32_t size);
extern uint8_t *moonbit_make_bytes_raw(int32_t size);

/* GC header is located just before the data pointer */
struct moonbit_object {
  uint32_t rc;
  uint32_t meta;
};

#define OBJ_HEADER(ptr) ((struct moonbit_object*)(ptr) - 1)
#define ARRAY_LENGTH(ptr) (OBJ_HEADER(ptr)->meta & (((uint32_t)1 << 28) - 1))

/* Read a file and return as MoonBit String (UTF-16) */
uint16_t *mucc_read_file(uint8_t *path) {
  FILE *f = fopen((const char *)path, "rb");
  moonbit_decref(path);
  if (!f) {
    return NULL;
  }

  fseek(f, 0, SEEK_END);
  long sz = ftell(f);
  fseek(f, 0, SEEK_SET);

  uint8_t *buf = (uint8_t *)malloc((size_t)sz);
  if (!buf) {
    fclose(f);
    return NULL;
  }
  fread(buf, 1, (size_t)sz, f);
  fclose(f);

  /* Convert UTF-8/ASCII bytes to UTF-16 code units */
  uint16_t *str = moonbit_make_string_raw((int32_t)sz);
  for (long i = 0; i < sz; i++) {
    str[i] = (uint16_t)buf[i];
  }
  free(buf);
  return str;
}

/* Write MoonBit Bytes to a file */
int mucc_write_file(uint8_t *path, uint8_t *data) {
  uint32_t data_len = ARRAY_LENGTH(data);
  FILE *f = fopen((const char *)path, "wb");
  moonbit_decref(path);
  if (!f) {
    moonbit_decref(data);
    return -1;
  }

  size_t written = fwrite(data, 1, data_len, f);
  fclose(f);
  moonbit_decref(data);
  return (written == (size_t)data_len) ? 0 : -1;
}
