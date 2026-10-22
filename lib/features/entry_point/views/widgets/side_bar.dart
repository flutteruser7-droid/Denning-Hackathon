import 'package:flutter/material.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/utils/rive_utils.dart';
import '../../../auth/views/sign_in_view.dart';
import '../../../chat/views/chat_view.dart';
import '../../viewmodels/entry_point_view_model.dart';
import 'info_card.dart';
import 'side_menu.dart';

class SideBar extends StatelessWidget {
  final EntryPointViewModel? viewModel;

  const SideBar({super.key, this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel ?? EntryPointViewModel();
    final currentUser = FirebaseAuthService().currentUser;
    final displayName = currentUser?.displayName?.isNotEmpty == true
        ? currentUser!.displayName!
        : (currentUser?.email != null && currentUser!.email!.isNotEmpty
            ? currentUser.email!.split('@').first
            : "User");
    final displayBio = currentUser?.email?.isNotEmpty == true
        ? currentUser!.email!
        : "Active Account";

    return SafeArea(
      child: SizedBox(
        width: 288,
        height: double.infinity,
        child: Material(
          color: const Color(0xFF17203A),
          borderRadius: const BorderRadius.all(
            Radius.circular(30),
          ),
          clipBehavior: Clip.antiAlias,
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: ListenableBuilder(
              listenable: vm,
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoCard(
                      name: displayName,
                      bio: displayBio,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 24, top: 32, bottom: 16),
                              child: Text(
                                "Browse".toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium!
                                    .copyWith(color: Colors.white70),
                              ),
                            ),
                            ...vm.sidebarMenus.map((menu) => SideMenu(
                                  menu: menu,
                                  selectedMenu: vm.selectedSideMenu,
                                  press: () {
                                    if (menu.rive.status != null) {
                                      RiveUtils.chnageSMIBoolState(
                                          menu.rive.status!);
                                    }
                                    vm.updateSelectedSideMenu(menu);

                                    // Close the sidebar
                                    if (vm.isSideBarOpen) {
                                      vm.toggleSidebar();
                                    }

                                    // Navigate to AI Chat screen if selected
                                    if (menu.title == "Chat with AI") {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ChatView(),
                                        ),
                                      );
                                    }
                                  },
                                  riveOnInit: (artboard) {
                                    menu.rive.status = RiveUtils.getRiveInput(
                                        artboard,
                                        stateMachineName:
                                            menu.rive.stateMachineName);
                                  },
                                )),
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 24, top: 40, bottom: 16),
                              child: Text(
                                "History".toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium!
                                    .copyWith(color: Colors.white70),
                              ),
                            ),
                            ...vm.sidebarMenus2.map((menu) => SideMenu(
                                  menu: menu,
                                  selectedMenu: vm.selectedSideMenu,
                                  press: () {
                                    if (menu.rive.status != null) {
                                      RiveUtils.chnageSMIBoolState(
                                          menu.rive.status!);
                                    }
                                    vm.updateSelectedSideMenu(menu);
                                    if (vm.isSideBarOpen) {
                                      vm.toggleSidebar();
                                    }
                                  },
                                  riveOnInit: (artboard) {
                                    menu.rive.status = RiveUtils.getRiveInput(
                                        artboard,
                                        stateMachineName:
                                            menu.rive.stateMachineName);
                                  },
                                )),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 24, right: 24, bottom: 24),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFF77D8E),
                            size: 24,
                          ),
                          title: const Text(
                            "Log Out",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          onTap: () async {
                            await PreferencesService().clearAuthPreferences();
                            await FirebaseAuthService().signOut();
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignInView(),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
