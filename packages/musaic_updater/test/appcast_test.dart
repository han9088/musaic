import 'package:flutter_test/flutter_test.dart';
import 'package:musaic_updater/musaic_updater.dart';
import 'package:version/version.dart';

void main() {
  group('Appcast', () {
    test('parses release metadata and retains HTML description', () async {
      final appcast = Appcast(osVersion: Version.parse('14.0.0'));
      const xml = '''
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>MUSAIC Updates</title>
    <item>
      <title>MUSAIC 1.2.0</title>
      <description><![CDATA[<h2>New canvas</h2><p>Album artwork layout.</p>]]></description>
      <pubDate>Mon, 23 Nov 2026 10:00:00 +0800</pubDate>
      <enclosure url="https://example.com/musaic-1.2.0.zip"
        sparkle:version="1.2.0" sparkle:shortVersionString="1.2.0"
        sparkle:edSignature="test-signature" length="12345"
        type="application/octet-stream" />
      <sparkle:minimumSystemVersion>13.0.0</sparkle:minimumSystemVersion>
      <sparkle:minimumUpdateVersion>1.0.0</sparkle:minimumUpdateVersion>
      <sparkle:tags><sparkle:criticalUpdate /></sparkle:tags>
    </item>
    <item>
      <title>MUSAIC 1.1.0</title>
      <description>Bug fixes</description>
      <enclosure url="https://example.com/musaic-1.1.0.zip" sparkle:version="1.1.0" />
    </item>
  </channel>
</rss>
''';

      final items = await appcast.parseAppcastItems(xml);
      expect(items, hasLength(2));
      expect(items!.first.title, 'MUSAIC 1.2.0');
      expect(items.first.itemDescription, contains('<h2>New canvas</h2>'));
      expect(items.first.edSignature, 'test-signature');
      expect(items.first.minimumUpdateVersion, '1.0.0');
      expect(items.first.isCriticalUpdate, isTrue);
      expect(appcast.bestItem()?.versionString, '1.2.0');
      expect(appcast.bestCriticalItem()?.versionString, '1.2.0');
    });

    test('rejects empty or malformed XML without throwing', () async {
      final appcast = Appcast(osVersion: Version.parse('14.0.0'));
      expect(await appcast.parseAppcastItems(''), isNull);
      expect(await appcast.parseAppcastItems('<rss><channel>'), isNull);
    });
  });
}
