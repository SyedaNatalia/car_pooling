import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});
  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _sub;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _isOffline = results.every((r) => r == ConnectivityResult.none));
    });
  }

  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOffline = results.every((r) => r == ConnectivityResult.none));
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(child: widget.child),
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        child: _isOffline
            ? SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('No internet connection',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
              )
            : const SizedBox.shrink(),
      ),
    ]);
  }
}
