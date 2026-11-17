int xeroxSeed(String identity) {
  var hash = 0x811c9dc5;
  for (final unit in identity.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash % 65521;
}
