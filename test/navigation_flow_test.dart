import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive_animation/features/entry_point/data/navigation_repository.dart';
import 'package:rive_animation/features/home/views/home_view.dart';
import 'package:rive_animation/features/home/views/widgets/course_card.dart';
import 'package:rive_animation/features/home/views/widgets/secondary_course_card.dart';
import 'package:rive_animation/features/chat/views/chat_view.dart';

void main() {
  group('Navigation & Layout Restoration Tests', () {
    test('NavigationRepository provides 5 bottom nav items and 5 browse sidebar items', () {
      final repo = LocalNavigationRepository();
      expect(repo.getBottomNavItems().length, 5);
      expect(repo.getSidebarMenus().length, 5);
      expect(repo.getSidebarMenus()[0].title, "Home");
      expect(repo.getSidebarMenus()[1].title, "Chat with AI");
      expect(repo.getSidebarMenus2().length, 2);
    });

    testWidgets('HomeView renders Courses and Recent sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeView(),
        ),
      );

      // Verify Courses header and cards
      expect(find.text("Courses"), findsOneWidget);
      expect(find.byType(CourseCard), findsNWidgets(2));
      expect(find.text("Animations in SwiftUI"), findsOneWidget);
      expect(find.text("Animations in Flutter"), findsOneWidget);

      // Verify Recent header and cards
      expect(find.text("Recent"), findsOneWidget);
      expect(find.byType(SecondaryCourseCard), findsNWidgets(4));
      expect(find.text("State Machine"), findsOneWidget);
      expect(find.text("Flutter with Rive"), findsOneWidget);
    });

    testWidgets('ChatView can be navigated to and has working Back to Home button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatView()),
                  );
                },
                child: const Text("Open Chat"),
              ),
            ),
          ),
        ),
      );

      // Open ChatView
      await tester.tap(find.text("Open Chat"));
      await tester.pumpAndSettle();

      // Verify ChatView is open
      expect(find.byType(ChatView), findsOneWidget);
      expect(find.text("Chat with AI"), findsWidgets);
      expect(find.byTooltip("Back to Home"), findsOneWidget);

      // Tap back button
      await tester.tap(find.byTooltip("Back to Home"));
      await tester.pumpAndSettle();

      // Verified returned to previous screen
      expect(find.byType(ChatView), findsNothing);
      expect(find.text("Open Chat"), findsOneWidget);
    });
  });
}
