#include "displays.h"

#include <shellscalingapi.h>

#include <algorithm>

UINT DpiForMonitor(HMONITOR monitor) {
  UINT dpi_x = 96, dpi_y = 96;
  if (FAILED(GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &dpi_x, &dpi_y))) {
    return 96;
  }
  return dpi_x;
}

std::vector<Display> EnumerateDisplays() {
  std::vector<Display> displays;
  EnumDisplayMonitors(
      nullptr, nullptr,
      [](HMONITOR monitor, HDC, LPRECT, LPARAM data) -> BOOL {
        MONITORINFOEXW info{};
        info.cbSize = sizeof(info);
        if (GetMonitorInfoW(monitor, &info)) {
          reinterpret_cast<std::vector<Display>*>(data)->push_back(
              {info.szDevice, info.rcMonitor, info.rcWork,
               DpiForMonitor(monitor),
               (info.dwFlags & MONITORINFOF_PRIMARY) != 0});
        }
        return TRUE;
      },
      reinterpret_cast<LPARAM>(&displays));
  return displays;
}

Display FindDisplay(const std::wstring& id) {
  auto displays = EnumerateDisplays();
  for (const auto& d : displays) {
    if (d.id == id) return d;
  }
  for (const auto& d : displays) {
    if (d.primary) return d;
  }
  if (!displays.empty()) return displays.front();
  RECT fallback{0, 0, GetSystemMetrics(SM_CXSCREEN),
                GetSystemMetrics(SM_CYSCREEN)};
  return {L"", fallback, fallback, 96, true};
}

POINT AlignInArea(const RECT& area, int width, int height, double align_x,
                  double align_y, int margin) {
  auto axis = [margin](LONG start, LONG extent, int item, double align) {
    const double min = start + margin;
    const double max = start + extent - margin - item;
    if (max <= min) return static_cast<LONG>(start + (std::max)(0, (static_cast<int>(extent) - item) / 2));
    return static_cast<LONG>(min + (max - min) * std::clamp(align, 0.0, 1.0));
  };
  return {axis(area.left, area.right - area.left, width, align_x),
          axis(area.top, area.bottom - area.top, height, align_y)};
}
