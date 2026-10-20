// lib/core/utils/enum_utils.dart
//
// Shared enum helpers — every model re-implements label/fromString with a
// switch. One generic pair replaces all of them; each model keeps a small
// const map of its own labels next to the enum it belongs to.

/// Display label for [value], looked up in [labels]. Falls back to [value.name].
String enumLabel<T extends Enum>(T value, Map<T, String> labels) =>
    labels[value] ?? value.name;

/// Parse [value] back into an enum via [lookup] (keys are case-insensitive).
/// Returns [defaultValue] when no match is found.
T enumFromString<T>(
  String? value,
  Map<String, T> lookup, {
  required T defaultValue,
}) {
  if (value == null) return defaultValue;
  return lookup[value.toLowerCase()] ?? lookup[value] ?? defaultValue;
}