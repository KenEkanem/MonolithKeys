#include "keystroke_overlay.h"

#include <algorithm>
#include <cmath>
#include <vector>

#include "displays.h"
#include "encodable.h"
#include "utils.h"

using flutter::EncodableList;
using flutter::EncodableMap;

namespace {

// Matches CapGlyph in lib/keystroke/keys.dart.
enum Glyph { kNone, kWindows, kMouseLeft, kMouseRight, kMouseMiddle, kWheelUp, kWheelDown };

constexpr BYTE kFadeStep = 40;

struct Cap {
  std::wstring label;
  std::wstring symbol;
  int glyph = kNone;
  uint32_t face, edge, text, border;
  float width = 0;
};

struct Style {
  float radius, depth, border, height, font_size, padding, gap;
  int weight;
  bool presentation;
};

std::unique_ptr<Gdiplus::Font> MakeFont(int weight, float size) {
  // GDI+ has no weight axis, so pick the matching Segoe UI family.
  const wchar_t* family = weight >= 600 && weight < 700 ? L"Segoe UI Semibold" : L"Segoe UI";
  const int style = weight >= 700 ? Gdiplus::FontStyleBold : Gdiplus::FontStyleRegular;
  auto font = std::make_unique<Gdiplus::Font>(family, size, style, Gdiplus::UnitPixel);
  if (font->GetLastStatus() != Gdiplus::Ok) {
    font = std::make_unique<Gdiplus::Font>(L"Segoe UI", size, weight >= 600 ? Gdiplus::FontStyleBold : style,
                                           Gdiplus::UnitPixel);
  }
  return font;
}

float TextWidth(Gdiplus::Graphics& g, const std::wstring& text, const Gdiplus::Font& font) {
  if (text.empty()) return 0;
  Gdiplus::RectF bounds;
  Gdiplus::StringFormat format(Gdiplus::StringFormat::GenericTypographic());
  format.SetFormatFlags(format.GetFormatFlags() | Gdiplus::StringFormatFlagsMeasureTrailingSpaces);
  g.MeasureString(text.c_str(), static_cast<INT>(text.size()), &font, Gdiplus::PointF(0, 0), &format, &bounds);
  return bounds.Width;
}

void DrawGlyph(Gdiplus::Graphics& g, int glyph, Gdiplus::RectF box, Gdiplus::Color color) {
  const float s = box.Width;
  Gdiplus::SolidBrush fill(color);
  if (glyph == kWindows) {
    const float gap = s * 0.08f, q = (s - gap) / 2;
    g.FillRectangle(&fill, box.X, box.Y, q, q);
    g.FillRectangle(&fill, box.X + q + gap, box.Y, q, q);
    g.FillRectangle(&fill, box.X, box.Y + q + gap, q, q);
    g.FillRectangle(&fill, box.X + q + gap, box.Y + q + gap, q, q);
    return;
  }
  Gdiplus::RectF body(box.X + s * 0.2f, box.Y, s * 0.6f, s);
  Gdiplus::GraphicsPath outline;
  AddRoundedRect(outline, Gdiplus::RectF(body.X + s * 0.04f, body.Y + s * 0.04f, body.Width - s * 0.08f,
                                         body.Height - s * 0.08f),
                 s * 0.26f);
  Gdiplus::Pen pen(color, s * 0.08f);
  g.DrawPath(&pen, &outline);
  g.DrawLine(&pen, body.X, box.Y + s * 0.42f, body.X + body.Width, box.Y + s * 0.42f);
  Gdiplus::GraphicsPath clip;
  AddRoundedRect(clip, body, s * 0.3f);
  if (glyph == kMouseLeft || glyph == kMouseRight) {
    g.SetClip(&clip);
    const float half = body.Width / 2;
    g.FillRectangle(&fill, glyph == kMouseLeft ? body.X : body.X + half, body.Y, half, s * 0.42f);
    g.ResetClip();
  } else {
    Gdiplus::GraphicsPath wheel;
    AddRoundedRect(wheel, Gdiplus::RectF(box.X + s * 0.43f, box.Y + s * 0.1f, s * 0.14f, s * 0.24f), s * 0.07f);
    g.FillPath(&fill, &wheel);
  }
}

}  // namespace

void KeystrokeOverlay::Configure(std::wstring display_id, double align_x, double align_y, double margin) {
  display_id_ = std::move(display_id);
  align_x_ = align_x;
  align_y_ = align_y;
  margin_ = margin;
}

void KeystrokeOverlay::Show(const EncodableMap& scene) {
  const Display display = FindDisplay(display_id_);
  const float dpi = static_cast<float>(display.dpi) / 96.0f;
  Style st{};
  st.radius = static_cast<float>(GetDouble(scene, "radius")) * dpi;
  st.depth = static_cast<float>(GetDouble(scene, "depth")) * dpi;
  st.border = static_cast<float>(GetDouble(scene, "border")) * dpi;
  st.height = static_cast<float>(GetDouble(scene, "height", 52)) * dpi;
  st.font_size = static_cast<float>(GetDouble(scene, "fontSize", 19)) * dpi;
  st.weight = static_cast<int>(GetInt(scene, "fontWeight", 600));
  st.presentation = GetBool(scene, "presentation");
  st.padding = st.height * 0.3f;
  st.gap = st.height * 0.12f;

  auto read_cap = [](const EncodableMap& m) {
    Cap c;
    c.label = Utf16FromUtf8(GetString(m, "label"));
    c.symbol = Utf16FromUtf8(GetString(m, "symbol"));
    c.glyph = static_cast<int>(GetInt(m, "glyph"));
    c.face = GetColor(m, "face");
    c.edge = GetColor(m, "edge");
    c.text = GetColor(m, "text");
    c.border = GetColor(m, "border");
    return c;
  };

  // Each stroke becomes a row of caps; in presentation mode the caps are
  // joined into one pill, and a repeat count is shown as a trailing cap.
  const EncodableMap* pill = GetMap(scene, "pill");
  std::vector<std::vector<Cap>> rows;
  if (const EncodableList* strokes = GetList(scene, "strokes")) {
    for (const auto& sv : *strokes) {
      const auto* stroke = std::get_if<EncodableMap>(&sv);
      if (!stroke) continue;
      std::vector<Cap> caps;
      if (const EncodableList* list = GetList(*stroke, "caps")) {
        for (const auto& cv : *list) {
          if (const auto* m = std::get_if<EncodableMap>(&cv)) caps.push_back(read_cap(*m));
        }
      }
      if (caps.empty()) continue;
      if (st.presentation && pill) {
        Cap joined = read_cap(*pill);
        for (size_t i = 0; i < caps.size(); ++i) {
          if (i > 0) joined.label += L" + ";
          if (!caps[i].symbol.empty()) joined.label += caps[i].symbol + L" ";
          joined.label += caps[i].label;
        }
        caps = {joined};
      }
      const int64_t count = GetInt(*stroke, "count", 1);
      if (count > 1 && pill) {
        Cap badge = read_cap(*pill);
        badge.label = L"×" + std::to_wstring(count);
        caps.push_back(badge);
      }
      rows.push_back(std::move(caps));
    }
  }
  if (rows.empty()) {
    BeginFadeOut();
    return;
  }

  const auto font = MakeFont(st.weight, st.font_size);
  Gdiplus::Font symbol_font(L"Segoe UI Symbol", st.font_size, Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);

  // Measure on a scratch bitmap, then draw at the final size.
  const float aa = 2 * dpi;  // Room for anti-aliased edges.
  float total = 0;
  {
    Gdiplus::Bitmap scratch(1, 1, PixelFormat32bppPARGB);
    Gdiplus::Graphics measure(&scratch);
    measure.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);
    for (size_t r = 0; r < rows.size(); ++r) {
      if (r > 0) total += st.gap * 2.5f;
      for (size_t i = 0; i < rows[r].size(); ++i) {
        Cap& c = rows[r][i];
        float content = TextWidth(measure, c.label, *font);
        if (!c.symbol.empty()) content += TextWidth(measure, c.symbol + L" ", symbol_font);
        if (c.glyph != kNone) content += st.font_size + st.height * 0.12f;
        c.width = (std::max)(st.height, std::ceil(content + st.padding * 2));
        total += c.width + (i > 0 ? st.gap : 0);
      }
    }
  }

  const int width = static_cast<int>(std::ceil(total + aa * 2));
  const int height = static_cast<int>(std::ceil(st.height + aa * 2));
  auto g = window_.BeginDraw(width, height);
  Gdiplus::StringFormat format(Gdiplus::StringFormat::GenericTypographic());
  format.SetLineAlignment(Gdiplus::StringAlignmentCenter);

  float x = aa;
  for (size_t r = 0; r < rows.size(); ++r) {
    if (r > 0) x += st.gap * 2.5f;
    for (size_t i = 0; i < rows[r].size(); ++i) {
      const Cap& c = rows[r][i];
      if (i > 0) x += st.gap;
      Gdiplus::RectF outer(x, aa, c.width, st.height);
      Gdiplus::RectF face(x, aa, c.width, st.height - st.depth);
      Gdiplus::GraphicsPath edge_path, face_path;
      AddRoundedRect(edge_path, outer, st.radius);
      AddRoundedRect(face_path, face, st.radius);
      Gdiplus::SolidBrush edge_brush(ArgbColor(c.edge));
      Gdiplus::SolidBrush face_brush(ArgbColor(c.face));
      g->FillPath(&edge_brush, &edge_path);
      g->FillPath(&face_brush, &face_path);
      if (st.border > 0) {
        Gdiplus::GraphicsPath inset;
        const float h = st.border / 2;
        AddRoundedRect(inset, Gdiplus::RectF(face.X + h, face.Y + h, face.Width - st.border, face.Height - st.border),
                       (std::max)(0.0f, st.radius - h));
        Gdiplus::Pen pen(ArgbColor(c.border), st.border);
        g->DrawPath(&pen, &inset);
      }

      // Centre glyph, symbol and label as one line inside the face.
      float content = TextWidth(*g, c.label, *font);
      const float symbol_w = c.symbol.empty() ? 0 : TextWidth(*g, c.symbol + L" ", symbol_font);
      const float glyph_w = c.glyph == kNone ? 0 : st.font_size + st.height * 0.12f;
      content += symbol_w + glyph_w;
      float cx = x + (c.width - content) / 2;
      const Gdiplus::Color text_color = ArgbColor(c.text);
      Gdiplus::SolidBrush text_brush(text_color);
      if (c.glyph != kNone) {
        DrawGlyph(*g, c.glyph, Gdiplus::RectF(cx, face.Y + (face.Height - st.font_size) / 2, st.font_size, st.font_size),
                  text_color);
        cx += glyph_w;
      }
      if (!c.symbol.empty()) {
        const std::wstring s = c.symbol + L" ";
        g->DrawString(s.c_str(), static_cast<INT>(s.size()), &symbol_font, Gdiplus::RectF(cx, face.Y, symbol_w + 1, face.Height),
                      &format, &text_brush);
        cx += symbol_w;
      }
      g->DrawString(c.label.c_str(), static_cast<INT>(c.label.size()), font.get(),
                    Gdiplus::RectF(cx, face.Y, c.width, face.Height), &format, &text_brush);
      x += c.width;
    }
  }
  g.reset();

  const POINT origin = AlignInArea(display.work, width, height, align_x_, align_y_, static_cast<int>(margin_ * dpi));
  fading_ = false;
  window_.Present(origin, 255);
}

void KeystrokeOverlay::BeginFadeOut() { fading_ = window_.visible(); }

bool KeystrokeOverlay::FadeStep() {
  if (!fading_) return false;
  const BYTE alpha = window_.alpha();
  if (alpha <= kFadeStep) {
    window_.Hide();
    fading_ = false;
    return false;
  }
  window_.SetAlpha(static_cast<BYTE>(alpha - kFadeStep));
  return true;
}
