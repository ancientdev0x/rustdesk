import 'dart:ui';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

class CmTray with TrayListener {
  bool _isShowing = false;
  bool _listenerAdded = false;
  VoidCallback? onDisconnect;

  bool get isShowing => _isShowing;

  Future<void> show() async {
    if (!isWindows) return;
    if (!_listenerAdded) {
      trayManager.addListener(this);
      _listenerAdded = true;
    }
    await trayManager.setIcon('assets/tray-icon.ico');
    await updateToolTip();
    final menu = Menu(
      items: [
        MenuItem(
          key: 'show',
          label: translate('Open'),
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'disconnect',
          label: translate('Disconnect'),
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
    _isShowing = true;
  }

  Future<void> updateToolTip() async {
    if (!isWindows) return;
    final appName = bind.mainGetAppNameSync();
    final count = gFFI.serverModel.clients.length;
    await trayManager.setToolTip('$appName ($count)');
  }

  Future<void> hide() async {
    if (!isWindows) return;
    _isShowing = false;
    await trayManager.destroy();
  }

  Future<void> restoreCmWindow() async {
    await hide();
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
    windowOnTop(null);
  }

  @override
  void onTrayIconMouseDown() {
    restoreCmWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      restoreCmWindow();
    } else if (menuItem.key == 'disconnect') {
      hide().then((_) {
        if (onDisconnect != null) {
          onDisconnect!();
        } else {
          windowManager.close();
        }
      });
    }
  }

  void dispose() {
    if (_listenerAdded) {
      trayManager.removeListener(this);
      _listenerAdded = false;
    }
  }
}

final cmTray = CmTray();
