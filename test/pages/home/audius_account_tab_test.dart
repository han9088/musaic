import 'dart:convert';

import 'package:audius_sdk/audius_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/bottom_sheet_host.dart';
import 'package:musaic/features/music/playback/now_playing_capsule.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/pages/home/home_sheet.dart';
import 'package:musaic/services/music/audius_account.dart';
import 'package:musaic/services/music/audius_music_provider.dart';
import 'package:musaic/services/music/music_source_controller.dart';
import 'package:musaic/ui/bottom_sheet/bottom_sheet.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets(
    'Audius account tab is source-bound and changes the canvas only on request',
    (tester) async {
      final previous = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
      final redirect = Uri.parse('com.deskbtm.musaic.audius://oauth/callback');
      final client = MockClient((request) async {
        final response = switch (request.url.path) {
          '/v1/oauth/token' => {
            'access_token': 'access',
            'refresh_token': 'refresh',
            'expires_in': 3600,
            'refresh_expires_in': 86400,
            'scope': 'read',
          },
          '/v1/oauth/revoke' => <String, Object?>{},
          '/v1/me' => {
            'data': {'id': 'listener-id', 'handle': 'listener'},
          },
          '/v1/playlists/trending' => {
            'data': [
              {'id': 'trending', 'playlist_name': 'Trending', 'is_album': true},
            ],
          },
          '/v1/users/listener-id/library/tracks' => {
            'data': [
              {
                'item': {'id': 'saved-song', 'title': 'My saved song'},
              },
            ],
          },
          '/v1/users/listener-id/library/albums' => {
            'data': [
              {
                'item': {
                  'id': 'saved-album',
                  'playlist_name': 'My saved album',
                  'is_album': true,
                },
              },
            ],
          },
          '/v1/users/listener-id/playlists' => {
            'data': [
              {'id': 'own-list', 'playlist_name': 'My public list'},
              {
                'id': 'private-list',
                'playlist_name': 'Private list',
                'is_private': true,
              },
            ],
          },
          _ => throw StateError('Unexpected URL ${request.url}'),
        };
        return http.Response(jsonEncode(response), 200);
      });
      final store = _MemoryStore();
      var authorizations = 0;
      final account = AudiusAccount(
        oauth: AudiusOAuth(
          clientId: 'fake-client',
          redirectUri: redirect,
          client: client,
        ),
        store: store,
        openBrowser: (url) async {
          authorizations++;
          return redirect.replace(
            queryParameters: {
              'state': url.queryParameters['state'],
              'code': 'one-time-code',
            },
          );
        },
      );
      final sources = MusicSourceController(
        audiusAccount: account,
        createAudius: () =>
            AudiusMusicProvider(sdk: AudiusSdk(httpClient: client)),
      );
      addTearDown(client.close);
      addTearDown(account.dispose);
      addTearDown(sources.dispose);
      await tester.binding.setSurfaceSize(const Size(420, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppBottomSheetHost(
            child: HomeSheet(sources: sources, child: const SizedBox.expand()),
          ),
        ),
      );
      final host = DeskBottomSheet.of(tester.element(find.byType(HomeSheet)));
      final control = find.byType(NowPlayingCapsule);
      expect(control, findsOneWidget);
      await tester.drag(control, const Offset(0, -140));
      await tester.pumpAndSettle();
      expect(host.isPresented, isTrue);
      expect(find.byType(TabBar), findsNothing);
      host.topSheetController!.expand();
      await tester.pumpAndSettle();

      await sources.selectAudius();
      await tester.pumpAndSettle();
      final tabs = find.byType(TabBar);
      expect(tester.widget<TabBar>(tabs).tabs, hasLength(2));
      expect(sources.catalog.value!.single.title, 'Trending');
      final logoTab = find.descendant(of: tabs, matching: find.byType(Image));
      final logo = tester.widget<Image>(logoTab);
      expect(logo.semanticLabel, 'Audius');
      expect(
        (logo.image as AssetImage).assetName,
        'assets/branding/audius_glyph_color.png',
      );
      expect(
        find.descendant(of: tabs, matching: find.text('Audius')),
        findsNothing,
      );
      final pages = find.byType(TabBarView);
      await tester.drag(pages, const Offset(-320, 0));
      await tester.pumpAndSettle();
      expect(find.text('Connect Audius'), findsOneWidget);
      await tester.drag(pages, const Offset(320, 0));
      await tester.pumpAndSettle();
      expect(find.text('Connect Audius'), findsNothing);
      await tester.tap(logoTab);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect Audius'));
      await tester.pumpAndSettle();
      expect(find.text('@listener'), findsOneWidget);
      expect(sources.catalog.value!.single.title, 'Trending');
      final savedSession = store.value;
      expect(savedSession, isNotNull);

      await sources.selectMock2();
      await tester.pumpAndSettle();
      expect(tabs, findsNothing);
      expect(store.value, savedSession);
      await sources.selectAudius();
      await tester.pumpAndSettle();
      await tester.tap(logoTab);
      await tester.pumpAndSettle();
      expect(find.text('@listener'), findsOneWidget);
      expect(authorizations, 1);
      expect(store.value, savedSession);

      await tester.tap(find.text('My Audius'));
      await tester.pumpAndSettle();
      expect(find.text('My saved song'), findsOneWidget);
      await tester.tap(find.text('My public playlists'));
      await tester.pumpAndSettle();
      expect(find.text('My public list'), findsOneWidget);
      expect(find.text('Private list'), findsNothing);
      await tester.tap(find.text('Favorite albums'));
      await tester.pumpAndSettle();
      expect(find.text('My saved album'), findsOneWidget);
      expect(sources.catalog.value!.single.title, 'Trending');
      await tester.tap(find.text('Show favorite albums on the canvas'));
      await tester.pumpAndSettle();
      expect(sources.catalog.value!.single.title, 'My saved album');
      final provider = sources.provider;
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(sources.provider, same(provider));
      expect(sources.catalog.value!.single.title, 'Trending');
      expect(find.text('Connect Audius'), findsOneWidget);
      expect(store.value, isNull);

      await sources.selectMock();
      await tester.pumpAndSettle();
      expect(tabs, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _MemoryStore implements AudiusSessionStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String session) async => value = session;

  @override
  Future<void> clear() async => value = null;
}
