/// API 路径和分页参数的公共校验。
String pathSegment(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
  return Uri.encodeComponent(value);
}

void validatePagination({int? offset, int? limit}) {
  if (offset != null && offset < 0) {
    throw ArgumentError.value(offset, 'offset', 'Must be zero or greater.');
  }
  if (limit != null && limit <= 0) {
    throw ArgumentError.value(limit, 'limit', 'Must be greater than zero.');
  }
}
