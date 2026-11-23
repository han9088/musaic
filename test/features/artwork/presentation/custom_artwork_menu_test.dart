import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/artwork/model/artwork_identity.dart';
import 'package:musaic/features/artwork/model/artwork_request.dart';
import 'package:musaic/features/artwork/pipeline/artwork_pipeline.dart';
import 'package:musaic/features/artwork/presentation/custom_artwork_menu.dart';
import 'package:musaic/features/artwork/presentation/custom_artwork_scope.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/storage/music/custom_artwork_store.dart';
import 'package:musaic/ui/dialogs/app_alert_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final class _PickedImage extends PlatformFile {
  _PickedImage(this.image);

  final Uint8List image;
  @override
  String get name => 'image.jpg';
  @override
  Uri get uri => Uri.file(name);
  @override
  int lengthSync() => image.length;
  @override
  Future<int> length() async => image.length;
  @override
  Future<Uint8List> readAsBytes() async => image;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(image);
  @override
  Never get xFile => throw UnsupportedError('Test uses readAsBytes');
}

class _ImagePicker extends FilePickerPlatform {
  PlatformFile? selection;
  FileType? type;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.type = type;
    return selection;
  }
}

void main() {
  sqfliteFfiInit();

  testWidgets(
    'long press saves and restores a cover for a song without artwork',
    (tester) async {
      final folder = Directory.systemTemp.createTempSync('musaic-cover-');
      final path = '${folder.path}/covers.sqlite';
      final factory = databaseFactoryFfi;
      final store = CustomArtworkStore(factory: factory, path: path);
      final originalPicker = FilePickerPlatform.instance;
      final picker = _ImagePicker()
        ..selection = _PickedImage(
          File('assets/albums/0.jpg').readAsBytesSync(),
        );
      FilePickerPlatform.instance = picker;
      addTearDown(() async {
        FilePickerPlatform.instance = originalPicker;
        await factory.deleteDatabase(path);
        folder.deleteSync(recursive: true);
        store.dispose();
      });
      const request = ArtworkRequest(
        source: 'local:song:42',
        identity: ArtworkIdentity('local:library:song:42'),
      );
      final pipeline = ArtworkPipeline(customArtwork: store);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CustomArtworkScope(
            store: store,
            child: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => GestureDetector(
                    key: const ValueKey('song-cover'),
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: customArtworkMenuAction(
                      context,
                      request.source,
                      request.identity,
                    ),
                    child: const SizedBox.square(dimension: 100),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final empty = pipeline.acquireForDisplay(
        request,
        directories: null,
        directoryRevision: 0,
      );
      expect(await empty.future, isNull);
      await tester.longPress(find.byKey(const ValueKey('song-cover')));
      await tester.pump();
      expect(find.byType(AppDialogSurface), findsOneWidget);
      expect(find.text('Restore original cover'), findsNothing);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add cover'));
      await tester.pumpAndSettle();
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (store.revisionOf(request.customArtworkKey) == null &&
          DateTime.now().isBefore(deadline)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(picker.type, FileType.image);
      expect(store.revisionOf(request.customArtworkKey), 1);
      final custom = (await tester.runAsync(() async {
        final cover = pipeline.acquireForDisplay(
          request,
          directories: null,
          directoryRevision: 0,
        );
        final result = await cover.future;
        cover.release();
        return result;
      }))!;
      expect(custom.image, isA<MemoryImage>());
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('song-cover')));
      await tester.pumpAndSettle();
      expect(find.text('Change cover'), findsOneWidget);
      picker.selection = null;
      await tester.tap(find.text('Change cover'));
      await tester.pumpAndSettle();
      expect(store.revisionOf(request.customArtworkKey), 1);

      await tester.longPress(find.byKey(const ValueKey('song-cover')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore original cover'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(customArtworkMenuVisible.value, isTrue);
      await tester.pumpAndSettle();
      expect(customArtworkMenuVisible.value, isFalse);

      final restoreDeadline = DateTime.now().add(const Duration(seconds: 5));
      while (store.revisionOf(request.customArtworkKey) != null &&
          DateTime.now().isBefore(restoreDeadline)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(store.revisionOf(request.customArtworkKey), isNull);
      expect(await pipeline.resolve(request, directories: null), isNull);
      empty.release();
      await tester.runAsync(() async {
        await (await factory.openDatabase(path)).close();
        final reopened = CustomArtworkStore(factory: factory, path: path);
        await reopened.load();
        expect(reopened.revisionOf(request.customArtworkKey), isNull);
        await reopened.save(
          request.customArtworkKey,
          (custom.image as MemoryImage).bytes,
        );
        final replacement = await ArtworkPipeline(customArtwork: reopened)
            .resolve(request, directories: null);
        expect(replacement!.sourceKey, isNot(custom.sourceKey));
        reopened.dispose();
      });
    },
  );
}
