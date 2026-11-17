class XeroxConfig {
  const XeroxConfig({
    this.edge = 0.9,
    this.contrast = 32,
    this.smooth = 0,
    this.grain = 0.5,
    this.invert = false,
  });

  final double edge;
  final double contrast;
  final double smooth;
  final double grain;
  final bool invert;
}

const xeroxConfig = XeroxConfig();
