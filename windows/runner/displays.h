#ifndef RUNNER_DISPLAYS_H_
#define RUNNER_DISPLAYS_H_

#include <windows.h>

#include <string>
#include <vector>

// A connected monitor, in physical pixels.
struct Display {
  std::wstring id;  // Device name, e.g. \\.\DISPLAY1
  RECT bounds;
  RECT work;
  UINT dpi;
  bool primary;
};

std::vector<Display> EnumerateDisplays();

// The display with |id| when connected, otherwise the primary display.
Display FindDisplay(const std::wstring& id);

UINT DpiForMonitor(HMONITOR monitor);

// Top-left corner for an item of |width| x |height| placed in |area| at the
// 0..1 alignment, |margin| px from the edges. Mirrors overlayOrigin() in
// lib/display/display_layout.dart.
POINT AlignInArea(const RECT& area, int width, int height, double align_x,
                  double align_y, int margin);

#endif  // RUNNER_DISPLAYS_H_
