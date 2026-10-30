import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/activity_details.dart';

void main() {
  test('famille d’un outil Hermes d’après son nom', () {
    expect(ActivityKind.forTool('terminal'), ActivityKind.command);
    expect(ActivityKind.forTool('read_file'), ActivityKind.fileRead);
    expect(ActivityKind.forTool('browser_click'), ActivityKind.webBrowse);
    expect(ActivityKind.forTool('browser_vision'), ActivityKind.imageAnalyze);
    expect(ActivityKind.forTool('cronjob_manage'), ActivityKind.schedule);
    expect(ActivityKind.forTool('write_file 💻'), ActivityKind.fileCreate);
    expect(ActivityKind.forTool('mcp_inconnu'), ActivityKind.tool);
    expect(ActivityKind.forTool(null), ActivityKind.tool);
  });

  test('résumé d’un appel : arguments d’abord, repli masqué par args', () {
    expect(
      ActivityDetails.summary({
        'args': {'command': 'ls -la\nsuite'},
      }),
      'ls -la',
    );
    expect(
      ActivityDetails.summary({'args': <String, Object?>{}, 'args_text': 'x'}),
      isNull,
    );
    expect(ActivityDetails.summary({'args_text': 'repli'}), 'repli');
    expect(ActivityDetails.summary({}), isNull);
  });
}
