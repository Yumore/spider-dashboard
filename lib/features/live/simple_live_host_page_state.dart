import 'dart:io';

import 'package:flutter/material.dart';
import 'package:simple_live_app/embedded.dart' as mobile;
import 'package:simple_live_tv_app/embedded.dart' as television;

import 'simple_live_host_page.dart';

class SimpleLiveEmbeddedPageState extends State<SimpleLiveEmbeddedPage> {
  bool? _useTelevisionEdition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _useTelevisionEdition ??=
        Platform.isAndroid && MediaQuery.sizeOf(context).width >= 850;
  }

  @override
  Widget build(BuildContext context) => _useTelevisionEdition == true
      ? television.SimpleLiveTvEmbeddedPage(
          key: const ValueKey('simple-live-tv'),
        )
      : mobile.SimpleLiveEmbeddedPage(
          key: const ValueKey('simple-live-mobile'),
        );
}
