#include <Carbon/Carbon.h>
#include <stdio.h>
#include <string.h>

static void get_string(TISInputSourceRef source, CFStringRef key, char *buf, size_t size) {
  CFStringRef value = TISGetInputSourceProperty(source, key);
  if (value == NULL || !CFStringGetCString(value, buf, (CFIndex)size, kCFStringEncodingUTF8)) {
    snprintf(buf, size, "-");
  }
}

static bool get_bool(TISInputSourceRef source, CFStringRef key) {
  CFBooleanRef value = TISGetInputSourceProperty(source, key);
  return value != NULL && CFBooleanGetValue(value);
}

static int list_enabled(void) {
  const void *keys[] = { kTISPropertyInputSourceIsEnabled };
  const void *values[] = { kCFBooleanTrue };
  CFDictionaryRef filter = CFDictionaryCreate(NULL, keys, values, 1,
      &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFArrayRef sources = TISCreateInputSourceList(filter, false);
  CFRelease(filter);
  if (sources == NULL) {
    return 0;
  }
  for (CFIndex i = 0; i < CFArrayGetCount(sources); i++) {
    TISInputSourceRef source = (TISInputSourceRef)CFArrayGetValueAtIndex(sources, i);
    char id[256], name[256], type[128];
    get_string(source, kTISPropertyInputSourceID, id, sizeof(id));
    get_string(source, kTISPropertyLocalizedName, name, sizeof(name));
    get_string(source, kTISPropertyInputSourceType, type, sizeof(type));
    printf("%s\t%s\t%s\t%s\n", id, type,
        get_bool(source, kTISPropertyInputSourceIsSelectCapable) ? "selectable" : "-", name);
  }
  CFRelease(sources);
  return 0;
}

static int disable(const char *id) {
  CFStringRef cf_id = CFStringCreateWithCString(NULL, id, kCFStringEncodingUTF8);
  const void *keys[] = { kTISPropertyInputSourceID };
  const void *values[] = { cf_id };
  CFDictionaryRef filter = CFDictionaryCreate(NULL, keys, values, 1,
      &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFArrayRef sources = TISCreateInputSourceList(filter, true);
  CFRelease(filter);
  CFRelease(cf_id);

  int failed = 0;
  CFIndex count = sources == NULL ? 0 : CFArrayGetCount(sources);
  for (CFIndex i = 0; i < count; i++) {
    TISInputSourceRef source = (TISInputSourceRef)CFArrayGetValueAtIndex(sources, i);
    if (!get_bool(source, kTISPropertyInputSourceIsEnabled)) {
      continue;
    }
    OSStatus status = TISDisableInputSource(source);
    if (status != noErr) {
      fprintf(stderr, "tisctl: failed to disable %s (OSStatus %d)\n", id, (int)status);
      failed = 1;
    }
  }
  if (sources != NULL) {
    CFRelease(sources);
  }
  return failed;
}

int main(int argc, char *argv[]) {
  if (argc == 2 && strcmp(argv[1], "list") == 0) {
    return list_enabled();
  }
  if (argc >= 3 && strcmp(argv[1], "disable") == 0) {
    int failed = 0;
    for (int i = 2; i < argc; i++) {
      failed |= disable(argv[i]);
    }
    return failed;
  }
  fprintf(stderr, "usage: tisctl list | tisctl disable <input-source-id>...\n");
  return 2;
}
