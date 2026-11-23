#ifndef RUNNER_ENCODABLE_H_
#define RUNNER_ENCODABLE_H_

#include <flutter/encodable_value.h>

#include <cstdint>
#include <string>

// Lenient readers for maps sent over the platform channel. Missing or
// mistyped values return the fallback.

inline const flutter::EncodableValue* Field(const flutter::EncodableMap& map,
                                            const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  return it == map.end() ? nullptr : &it->second;
}

inline double GetDouble(const flutter::EncodableMap& map, const char* key,
                        double fallback = 0) {
  const auto* v = Field(map, key);
  if (!v) return fallback;
  if (const auto* d = std::get_if<double>(v)) return *d;
  if (const auto* i = std::get_if<int32_t>(v)) return *i;
  if (const auto* l = std::get_if<int64_t>(v)) return static_cast<double>(*l);
  return fallback;
}

inline int64_t GetInt(const flutter::EncodableMap& map, const char* key,
                      int64_t fallback = 0) {
  const auto* v = Field(map, key);
  if (!v) return fallback;
  if (const auto* i = std::get_if<int32_t>(v)) return *i;
  if (const auto* l = std::get_if<int64_t>(v)) return *l;
  return fallback;
}

inline bool GetBool(const flutter::EncodableMap& map, const char* key,
                    bool fallback = false) {
  const auto* v = Field(map, key);
  const auto* b = v ? std::get_if<bool>(v) : nullptr;
  return b ? *b : fallback;
}

inline std::string GetString(const flutter::EncodableMap& map,
                             const char* key) {
  const auto* v = Field(map, key);
  const auto* s = v ? std::get_if<std::string>(v) : nullptr;
  return s ? *s : std::string();
}

inline const flutter::EncodableMap* GetMap(const flutter::EncodableMap& map,
                                           const char* key) {
  const auto* v = Field(map, key);
  return v ? std::get_if<flutter::EncodableMap>(v) : nullptr;
}

inline const flutter::EncodableList* GetList(const flutter::EncodableMap& map,
                                             const char* key) {
  const auto* v = Field(map, key);
  return v ? std::get_if<flutter::EncodableList>(v) : nullptr;
}

inline uint32_t GetColor(const flutter::EncodableMap& map, const char* key) {
  return static_cast<uint32_t>(GetInt(map, key, 0));
}

#endif  // RUNNER_ENCODABLE_H_
