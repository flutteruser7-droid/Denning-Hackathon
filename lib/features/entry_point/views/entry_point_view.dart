import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/rive_utils.dart';
import '../../home/views/home_view.dart';
import '../models/menu_item_model.dart';
import '../viewmodels/entry_point_view_model.dart';
import 'widgets/btm_nav_item.dart';
import 'widgets/menu_btn.dart';
import 'widgets/side_bar.dart';

class EntryPointView extends StatefulWidget {
  final EntryPointViewModel? viewModel;

  const EntryPointView({super.key, this.viewModel});

  @override
  State<EntryPointView> createState() => _EntryPointViewState();
}

class _EntryPointViewState extends State<EntryPointView>
    with SingleTickerProviderStateMixin {
  late final EntryPointViewModel _viewModel;
  late AnimationController _animationController;
  late Animation<double> scalAnimation;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? EntryPointViewModel();

    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200))
      ..addListener(
        () {
          setState(() {});
        },
      );
    scalAnimation = Tween<double>(begin: 1, end: 0.8).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.fastOutSlowIn));
    animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.fastOutSlowIn));

    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (_viewModel.isSideBarOpen) {
      if (_animationController.value == 0) {
        _animationController.forward();
      }
    } else {
      if (_animationController.value == 1) {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onMenuButtonPressed() {
    _viewModel.toggleSidebar();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          extendBody: true,
          resizeToAvoidBottomInset: false,
          backgroundColor: backgroundColor2,
          body: Stack(
            children: [
              AnimatedPositioned(
                width: 288,
                height: MediaQuery.of(context).size.height,
                duration: const Duration(milliseconds: 200),
                curve: Curves.fastOutSlowIn,
                left: _viewModel.isSideBarOpen ? 0 : -288,
                top: 0,
                child: SideBar(viewModel: _viewModel),
              ),
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(
                      1 * animation.value - 30 * (animation.value) * pi / 180),
                child: Transform.translate(
                  offset: Offset(animation.value * 265, 0),
                  child: Transform.scale(
                    scale: scalAnimation.value,
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(
                        Radius.circular(_animationController.value > 0 ? 24 : 0),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          if (_viewModel.isSideBarOpen) {
                            _viewModel.toggleSidebar();
                          }
                        },
                        child: const HomeView(),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.fastOutSlowIn,
                left: _viewModel.isSideBarOpen ? 220 : 0,
                top: 16,
                child: MenuBtn(
                  press: _onMenuButtonPressed,
                  riveOnInit: (artboard) {
                    final controller = StateMachineController.fromArtboard(
                        artboard, "State Machine");

                    artboard.addController(controller!);

                    _viewModel.isMenuOpenInput =
                        controller.findInput<bool>("isOpen") as SMIBool;
                    _viewModel.isMenuOpenInput?.value = true;
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: Transform.translate(
            offset: Offset(0, 100 * animation.value),
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.only(
                    left: 12, top: 12, right: 12, bottom: 12),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: backgroundColor2.withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: backgroundColor2.withValues(alpha: 0.3),
                      offset: const Offset(0, 20),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ...List.generate(
                      _viewModel.bottomNavItems.length,
                      (index) {
                        MenuItemModel navBar = _viewModel.bottomNavItems[index];
                        return BtmNavItem(
                          navBar: navBar,
                          press: () {
                            if (navBar.rive.status != null) {
                              RiveUtils.chnageSMIBoolState(navBar.rive.status!);
                            }
                            _viewModel.updateSelectedBottomNav(navBar);
                          },
                          riveOnInit: (artboard) {
                            navBar.rive.status = RiveUtils.getRiveInput(
                              artboard,
                              stateMachineName: navBar.rive.stateMachineName,
                            );
                          },
                          selectedNav: _viewModel.selectedBottomNav,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Alias for backward compatibility
typedef EntryPoint = EntryPointView;
