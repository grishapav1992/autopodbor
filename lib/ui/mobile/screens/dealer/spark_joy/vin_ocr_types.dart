class VinOcrResult {
  const VinOcrResult({
    required this.supported,
    required this.vin,
    required this.rawText,
    this.error,
  });

  final bool supported;
  final String vin;
  final String rawText;
  final String? error;

  const VinOcrResult.unsupported({
    this.error = 'OCR-сканирование VIN недоступно на этой платформе.',
  }) : supported = false,
       vin = '',
       rawText = '';
}
