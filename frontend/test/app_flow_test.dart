import 'package:dukaan360_app/app.dart';
import 'package:dukaan360_app/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

/// Lets data load, staggered/delayed animations start and finish. (The app has endless
/// animations, so pumpAndSettle would never return.)
Future<void> _flush(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(seconds: 3));
}

/// A pushed route (sheet / dialog) needs one frame to appear, then time to animate in.
Future<void> _routeIn(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

Future<FakeApi> _boot(WidgetTester tester, {bool offline = false, bool onboarded = true}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'onboarded': onboarded});
  final prefs = await SharedPreferences.getInstance();
  final api = FakeApi(offline: offline);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(api),
    ],
    child: const DukaanApp(),
  ));
  await tester.pump(const Duration(milliseconds: 1800)); // splash
  await tester.pump(const Duration(milliseconds: 700)); // splash -> shell fade
  await _flush(tester);
  return api;
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await _flush(tester);
}

/// The lists build lazily, so drag the page up until the target exists, then make it visible.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -350));
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(target, findsOneWidget, reason: 'target never appeared while scrolling');
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('dashboard shows real numbers, decline banner and chart', (tester) async {
    await _boot(tester);
    expect(find.text('Dukaan360'), findsWidgets);
    expect(find.text('₹60,029'), findsOneWidget); // hero: last 7 days
    expect(find.text('-20.0%'), findsOneWidget);
    expect(find.text('Check my shop'), findsOneWidget);

    await _scrollTo(tester, find.text('₹11,50,730')); // all sales, Indian grouping
    expect(find.text('₹11,50,730'), findsOneWidget);
    await _scrollTo(tester, find.text('Your sales: past and next 7 days'));
    expect(find.text('Your sales: past and next 7 days'), findsOneWidget);
    await _flush(tester);
  });

  testWidgets('home explains the situation in plain sentences and says what to do', (tester) async {
    await _boot(tester);
    expect(find.text('What needs your attention'), findsOneWidget);
    expect(find.textContaining('That is 20% less than last week'), findsOneWidget);
    expect(find.textContaining('29 regular customers have not come for 2 weeks or more'), findsOneWidget);
    expect(find.text('See offers to win them back'), findsOneWidget);
    // no jargon on the first screen
    expect(find.textContaining('forecast', findRichText: true, skipOffstage: false), findsNothing);
    expect(find.textContaining('at-risk', findRichText: true, skipOffstage: false), findsNothing);
    expect(find.textContaining('z-score', findRichText: true, skipOffstage: false), findsNothing);
  });

  testWidgets('first launch shows a 3-screen welcome, then the app', (tester) async {
    await _boot(tester, onboarded: false);
    expect(find.text('See your shop clearly'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Find customers who stopped coming'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Win them back, you stay in control'), findsOneWidget);
    expect(find.textContaining('Nothing is sent without you'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await _flush(tester);
    expect(find.text('Check my shop'), findsOneWidget); // now on the Home screen

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarded'), true); // and it is not shown again
  });

  testWidgets('welcome can be skipped', (tester) async {
    await _boot(tester, onboarded: false);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await _flush(tester);
    expect(find.text('What needs your attention'), findsOneWidget);
  });

  testWidgets('help button explains the chart in simple words', (tester) async {
    await _boot(tester);
    await _scrollTo(tester, find.text('Your sales: past and next 7 days'));
    final info = find.byTooltip('What does this mean?').first;
    await tester.ensureVisible(info);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(info);
    await _routeIn(tester);
    expect(find.text('How is the "expected" part made?'), findsOneWidget);
    expect(find.textContaining('It is an estimate to help you plan'), findsOneWidget);
  });

  testWidgets('server down shows a clear message and retry', (tester) async {
    await _boot(tester, offline: true);
    expect(find.text("Can't connect"), findsOneWidget);
    expect(find.text('Try again'), findsWidgets);
    expect(find.text('No connection. Trying again…'), findsOneWidget); // banner
  });

  testWidgets('recovers by itself when the server comes back (no manual Retry)', (tester) async {
    final api = await _boot(tester, offline: true);
    expect(find.text("Can't connect"), findsOneWidget);

    api.offline = false; // backend started / USB tunnel reconnected
    await tester.pump(const Duration(seconds: 7)); // next auto-retry tick
    await _flush(tester);

    expect(find.text("Can't connect"), findsNothing);
    expect(find.text('₹60,029'), findsOneWidget);
    // the banner slides away: still in the tree, but fully transparent
    final banner = find.ancestor(of: find.text('No connection. Trying again…'), matching: find.byType(AnimatedOpacity));
    expect(tester.widget<AnimatedOpacity>(banner.first).opacity, 0);
  });

  testWidgets('customers tab lists at-risk customers without phone numbers', (tester) async {
    await _boot(tester);
    await _tapTab(tester, 'Customers');
    expect(find.text('My Customers'), findsOneWidget);
    expect(find.text('19%'), findsOneWidget); // ring
    expect(find.text('Stopped coming'), findsWidgets); // plain words, not "At Risk"
    expect(find.text('Customers who stopped coming'), findsOneWidget);
    expect(find.text('At Risk'), findsNothing);

    await _scrollTo(tester, find.text('Manisha Wagh'));
    expect(find.text('Manisha Wagh'), findsOneWidget);
    expect(find.text('Last came 26 Oct  •  19 days ago'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget); // HIGH shown as plain "Urgent"
    expect(find.text('Slowing down'), findsWidgets);
    expect(find.textContaining('phone', findRichText: true), findsNothing);
  });

  testWidgets('alerts tab shows alerts most serious first', (tester) async {
    await _boot(tester);
    await _tapTab(tester, 'Warnings');
    expect(find.text('Things that need your attention. The most serious are at the top.'), findsOneWidget);
    expect(find.text('Sales Decline Warning'), findsOneWidget);
    expect(find.text('Unusual Activity Detected'), findsOneWidget);
    expect(find.text('₹12,000'), findsOneWidget); // amount formatted
    expect(find.text('Serious'), findsWidgets); // HIGH shown in plain words
    expect(find.textContaining('What to do:'), findsWidgets); // every warning says what to do
    expect(find.textContaining('z-score'), findsNothing);
    // HIGH is listed above MEDIUM
    final high = tester.getTopLeft(find.text('Sales Decline Warning')).dy;
    final medium = tester.getTopLeft(find.text('Unusual Activity Detected')).dy;
    expect(high, lessThan(medium));
  });

  testWidgets('approve flow: draft -> confirm -> "sent (Demo Mode)"', (tester) async {
    final api = await _boot(tester);
    await _tapTab(tester, 'Offers');

    // the 3-step guide and plain headline are on screen
    expect(find.text('Offers to win customers back'), findsOneWidget);
    expect(find.text('Check my shop'), findsWidgets);
    expect(find.text('Read the offer'), findsOneWidget);

    final approve = find.text('Send this offer'); // FilledButton.icon is a private subclass: match by label
    await _scrollTo(tester, approve);
    expect(find.text('वापसी का खास ऑफर'), findsOneWidget);
    expect(find.text('Waiting for you'), findsWidgets);
    expect(find.text('Customers who stopped coming (29)'), findsOneWidget);
    await tester.tap(approve);
    await _routeIn(tester);

    // confirmation sheet with the demo-mode notice
    expect(find.text('Send this offer?'), findsOneWidget);
    expect(find.textContaining('Demo Mode: no real WhatsApp or SMS'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Yes, send (demo)')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _routeIn(tester); // success dialog
    await tester.pump(const Duration(seconds: 2));

    expect(api.approveCalls, 1);
    expect(find.text('Sent!'), findsOneWidget);
    expect(find.text('Campaign sent successfully (Demo Mode).'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _flush(tester);
    expect(find.textContaining('Sent in Demo Mode'), findsOneWidget);
    expect(find.text('Send this offer'), findsNothing); // no button on a sent campaign
  });

  testWidgets('edit sheet saves the new wording', (tester) async {
    final api = await _boot(tester);
    await _tapTab(tester, 'Offers');
    final edit = find.text('Change');
    await _scrollTo(tester, edit);
    await tester.tap(edit);
    await _routeIn(tester);

    expect(find.text('Change the message'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Message to customers'), 'Naya sandesh');
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.lastEditMessage, 'Naya sandesh');
    expect(find.text('Message updated'), findsOneWidget); // toast is visible for ~3s
    await _flush(tester);
  });

  testWidgets('ask AI sheet answers a suggested question', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Ask AI'));
    await _routeIn(tester);
    expect(find.text('Which customers are likely to stop visiting?'), findsOneWidget);

    await tester.tap(find.text('Which customers are likely to stop visiting?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _flush(tester);

    expect(find.textContaining('29 regular customers have not visited'), findsOneWidget);
    expect(find.text('From your data'), findsOneWidget); // fallback answers are labelled honestly
  });
}
