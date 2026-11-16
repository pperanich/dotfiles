#include <Carbon/Carbon.h>
#include <dlfcn.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef int (*sls_main_connection_id_fn)(void);
typedef void (*sls_set_menubar_vis_fn)(int cid, int did, bool enabled);
typedef void (*sls_set_menubar_inset_fn)(int cid, double u1, double u2, float alpha);
typedef void (*slps_get_front_process_fn)(ProcessSerialNumber* psn);
typedef void (*sls_get_cid_for_psn_fn)(int cid, ProcessSerialNumber* psn, int* cid_out);
typedef void (*sls_connection_get_pid_fn)(int cid, pid_t* pid_out);

static sls_main_connection_id_fn p_SLSMainConnectionID;
static sls_set_menubar_vis_fn p_SLSSetMenuBarVisibilityOverrideOnDisplay;
static sls_set_menubar_inset_fn p_SLSSetMenuBarInsetAndAlpha;
static slps_get_front_process_fn p_SLPSGetFrontProcess;
static sls_get_cid_for_psn_fn p_SLSGetConnectionIDForPSN;
static sls_connection_get_pid_fn p_SLSConnectionGetPID;

static bool skylight_init(void) {
  static bool initialized = false;
  if (initialized) return true;

  void* handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
  if (!handle) return false;

  p_SLSMainConnectionID = (sls_main_connection_id_fn)dlsym(handle, "SLSMainConnectionID");
  p_SLSSetMenuBarVisibilityOverrideOnDisplay =
      (sls_set_menubar_vis_fn)dlsym(handle, "SLSSetMenuBarVisibilityOverrideOnDisplay");
  p_SLSSetMenuBarInsetAndAlpha =
      (sls_set_menubar_inset_fn)dlsym(handle, "SLSSetMenuBarInsetAndAlpha");
  p_SLPSGetFrontProcess = (slps_get_front_process_fn)dlsym(handle, "_SLPSGetFrontProcess");
  p_SLSGetConnectionIDForPSN =
      (sls_get_cid_for_psn_fn)dlsym(handle, "SLSGetConnectionIDForPSN");
  p_SLSConnectionGetPID = (sls_connection_get_pid_fn)dlsym(handle, "SLSConnectionGetPID");

  initialized = p_SLSMainConnectionID && p_SLSSetMenuBarVisibilityOverrideOnDisplay
                && p_SLSSetMenuBarInsetAndAlpha && p_SLPSGetFrontProcess
                && p_SLSGetConnectionIDForPSN && p_SLSConnectionGetPID;
  return initialized;
}

static void ax_init(void) {
  const void* keys[] = { kAXTrustedCheckOptionPrompt };
  const void* values[] = { kCFBooleanTrue };

  CFDictionaryRef options = CFDictionaryCreate(kCFAllocatorDefault,
                                               keys,
                                               values,
                                               sizeof(keys) / sizeof(*keys),
                                               &kCFCopyStringDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);

  bool trusted = AXIsProcessTrustedWithOptions(options);
  CFRelease(options);
  if (!trusted) exit(1);
}

static void ax_perform_click(AXUIElementRef element) {
  if (!element) return;
  AXUIElementPerformAction(element, kAXCancelAction);
  usleep(150000);
  AXUIElementPerformAction(element, kAXPressAction);
}

static CFStringRef ax_get_title(AXUIElementRef element) {
  CFTypeRef title = NULL;
  AXError error = AXUIElementCopyAttributeValue(element, kAXTitleAttribute, &title);
  if (error != kAXErrorSuccess) return NULL;
  return (CFStringRef)title;
}

static void ax_select_menu_option(AXUIElementRef app, int id) {
  AXUIElementRef menubars_ref = NULL;
  CFArrayRef children_ref = NULL;

  AXError error = AXUIElementCopyAttributeValue(
      app, kAXMenuBarAttribute, (CFTypeRef*)&menubars_ref);
  if (error == kAXErrorSuccess) {
    error = AXUIElementCopyAttributeValue(
        menubars_ref, kAXVisibleChildrenAttribute, (CFTypeRef*)&children_ref);

    if (error == kAXErrorSuccess) {
      CFIndex count = CFArrayGetCount(children_ref);
      if (id >= 0 && id < count) {
        AXUIElementRef item = (AXUIElementRef)CFArrayGetValueAtIndex(children_ref, id);
        ax_perform_click(item);
      }
      if (children_ref) CFRelease(children_ref);
    }
    if (menubars_ref) CFRelease(menubars_ref);
  }
}

static void ax_print_menu_options(AXUIElementRef app) {
  AXUIElementRef menubars_ref = NULL;
  CFArrayRef children_ref = NULL;

  AXError error = AXUIElementCopyAttributeValue(
      app, kAXMenuBarAttribute, (CFTypeRef*)&menubars_ref);
  if (error == kAXErrorSuccess) {
    error = AXUIElementCopyAttributeValue(
        menubars_ref, kAXVisibleChildrenAttribute, (CFTypeRef*)&children_ref);

    if (error == kAXErrorSuccess) {
      CFIndex count = CFArrayGetCount(children_ref);

      for (CFIndex i = 1; i < count; i++) {
        AXUIElementRef item = (AXUIElementRef)CFArrayGetValueAtIndex(children_ref, i);
        CFStringRef title = ax_get_title(item);

        if (title) {
          CFIndex max_len = CFStringGetMaximumSizeForEncoding(
                                CFStringGetLength(title), kCFStringEncodingUTF8)
                            + 1;
          char* buffer = calloc((size_t)max_len, 1);
          if (buffer && CFStringGetCString(title, buffer, max_len, kCFStringEncodingUTF8)) {
            printf("%s\n", buffer);
          }
          free(buffer);
          CFRelease(title);
        }
      }
    }
    if (menubars_ref) CFRelease(menubars_ref);
    if (children_ref) CFRelease(children_ref);
  }
}

static AXUIElementRef ax_get_extra_menu_item(const char* alias) {
  pid_t pid = 0;
  CGRect bounds = CGRectNull;
  CFArrayRef window_list =
      CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
  if (!window_list) return NULL;

  char owner_buffer[256];
  char name_buffer[256];
  char buffer[512];
  CFIndex window_count = CFArrayGetCount(window_list);
  for (CFIndex i = 0; i < window_count; ++i) {
    CFDictionaryRef dictionary = (CFDictionaryRef)CFArrayGetValueAtIndex(window_list, i);
    if (!dictionary) continue;

    CFStringRef owner_ref =
        (CFStringRef)CFDictionaryGetValue(dictionary, kCGWindowOwnerName);
    CFNumberRef owner_pid_ref =
        (CFNumberRef)CFDictionaryGetValue(dictionary, kCGWindowOwnerPID);
    CFStringRef name_ref = (CFStringRef)CFDictionaryGetValue(dictionary, kCGWindowName);
    CFNumberRef layer_ref =
        (CFNumberRef)CFDictionaryGetValue(dictionary, kCGWindowLayer);
    CFDictionaryRef bounds_ref =
        (CFDictionaryRef)CFDictionaryGetValue(dictionary, kCGWindowBounds);

    if (!name_ref || !owner_ref || !owner_pid_ref || !layer_ref || !bounds_ref)
      continue;

    long long int layer = 0;
    CFNumberGetValue(layer_ref, CFNumberGetType(layer_ref), &layer);
    uint64_t owner_pid = 0;
    CFNumberGetValue(owner_pid_ref, CFNumberGetType(owner_pid_ref), &owner_pid);

    if (layer != 0x19) continue;
    bounds = CGRectNull;
    if (!CGRectMakeWithDictionaryRepresentation(bounds_ref, &bounds)) continue;
    CFStringGetCString(
        owner_ref, owner_buffer, sizeof(owner_buffer), kCFStringEncodingUTF8);
    CFStringGetCString(
        name_ref, name_buffer, sizeof(name_buffer), kCFStringEncodingUTF8);
    snprintf(buffer, sizeof(buffer), "%s,%s", owner_buffer, name_buffer);

    if (strcmp(buffer, alias) == 0) {
      pid = (pid_t)owner_pid;
      break;
    }
  }
  CFRelease(window_list);
  if (!pid) return NULL;

  AXUIElementRef app = AXUIElementCreateApplication(pid);
  if (!app) return NULL;
  AXUIElementRef result = NULL;
  CFTypeRef extras = NULL;
  CFArrayRef children_ref = NULL;
  AXError error =
      AXUIElementCopyAttributeValue(app, kAXExtrasMenuBarAttribute, &extras);
  if (error == kAXErrorSuccess) {
    error = AXUIElementCopyAttributeValue(
        extras, kAXVisibleChildrenAttribute, (CFTypeRef*)&children_ref);

    if (error == kAXErrorSuccess) {
      CFIndex count = CFArrayGetCount(children_ref);
      for (CFIndex i = 0; i < count; i++) {
        AXUIElementRef item = (AXUIElementRef)CFArrayGetValueAtIndex(children_ref, i);
        CFTypeRef position_ref = NULL;
        CFTypeRef size_ref = NULL;
        AXUIElementCopyAttributeValue(item, kAXPositionAttribute, &position_ref);
        AXUIElementCopyAttributeValue(item, kAXSizeAttribute, &size_ref);
        if (!position_ref || !size_ref) {
          if (position_ref) CFRelease(position_ref);
          if (size_ref) CFRelease(size_ref);
          continue;
        }

        CGPoint position = CGPointZero;
        AXValueGetValue((AXValueRef)position_ref, kAXValueCGPointType, &position);
        CGSize size = CGSizeZero;
        AXValueGetValue((AXValueRef)size_ref, kAXValueCGSizeType, &size);
        CFRelease(position_ref);
        CFRelease(size_ref);
        if (fabs(position.x - bounds.origin.x) <= 10) {
          result = (AXUIElementRef)CFRetain(item);
          break;
        }
      }
      if (children_ref) CFRelease(children_ref);
    }
    if (extras) CFRelease(extras);
  }

  CFRelease(app);
  return result;
}

static void ax_select_menu_extra(const char* alias) {
  if (!skylight_init()) return;
  AXUIElementRef item = ax_get_extra_menu_item(alias);
  if (!item) return;
  p_SLSSetMenuBarInsetAndAlpha(p_SLSMainConnectionID(), 0, 1, 0.0f);
  p_SLSSetMenuBarVisibilityOverrideOnDisplay(p_SLSMainConnectionID(), 0, true);
  p_SLSSetMenuBarInsetAndAlpha(p_SLSMainConnectionID(), 0, 1, 0.0f);
  ax_perform_click(item);
  p_SLSSetMenuBarVisibilityOverrideOnDisplay(p_SLSMainConnectionID(), 0, false);
  p_SLSSetMenuBarInsetAndAlpha(p_SLSMainConnectionID(), 0, 1, 1.0f);
  CFRelease(item);
}

static AXUIElementRef ax_get_front_app(void) {
  if (!skylight_init()) return NULL;
  ProcessSerialNumber psn;
  p_SLPSGetFrontProcess(&psn);
  int target_cid = 0;
  p_SLSGetConnectionIDForPSN(p_SLSMainConnectionID(), &psn, &target_cid);

  pid_t pid = 0;
  p_SLSConnectionGetPID(target_cid, &pid);
  return AXUIElementCreateApplication(pid);
}

int main(int argc, char** argv) {
  if (argc == 1) {
    printf("Usage: %s [-l | -s id/alias ]\n", argv[0]);
    exit(0);
  }
  ax_init();
  if (strcmp(argv[1], "-l") == 0) {
    AXUIElementRef app = ax_get_front_app();
    if (!app) return 1;
    ax_print_menu_options(app);
    CFRelease(app);
  } else if (argc == 3 && strcmp(argv[1], "-s") == 0) {
    int id = 0;
    if (sscanf(argv[2], "%d", &id) == 1) {
      AXUIElementRef app = ax_get_front_app();
      if (!app) return 1;
      ax_select_menu_option(app, id);
      CFRelease(app);
    } else {
      ax_select_menu_extra(argv[2]);
    }
  }
  return 0;
}
