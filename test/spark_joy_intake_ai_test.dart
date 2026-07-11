import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_intake_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('парсит прямое назначение оригинала в осмотр', () {
    final result = parseIntakeDistributionResult(
      '{"items":[{"hash":"ABC","section":"inspection",'
      '"documentKind":"","group":"body","element":"hood"}]}',
    );
    expect(result.single.hash, 'abc');
    expect(result.single.section, SparkIntakeAiSection.inspection);
    expect(result.single.group, 'body');
    expect(result.single.element, 'hood');
  });

  test('СТС направляет оригинал в материалы и сохраняет тип документа', () {
    final result = parseIntakeDistributionResult(
      '{"items":[{"hash":"def","section":"materials",'
      '"documentKind":"vehicle_doc","group":"body","element":"hood"}]}',
    );
    expect(result.single.section, SparkIntakeAiSection.materials);
    expect(result.single.documentKind, SparkIntakeDocumentKind.vehicleDoc);
    expect(result.single.group, isEmpty);
    expect(result.single.element, isEmpty);
  });

  test('неизвестный раздел безопасно превращается в unknown', () {
    final result = parseIntakeDistributionResult(
      '{"items":[{"hash":"123","section":"invented"}]}',
    );
    expect(result.single.section, SparkIntakeAiSection.unknown);
  });

  test('понимает legacy category незавершённой версии', () {
    final result = parseIntakeDistributionResult(
      '{"items":[{"hash":"123","category":"vehicle_doc"}]}',
    );
    expect(result.single.section, SparkIntakeAiSection.materials);
    expect(result.single.documentKind, SparkIntakeDocumentKind.vehicleDoc);
  });
}
