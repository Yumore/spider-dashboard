import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'hongguo_app.dart';
import 'video_enhancement_assets.dart';
import 'short_drama_module_page.dart';

class ShortDramaModulePageState extends State<ShortDramaModulePage> {
  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    VideoEnhancementAssets.registerLicenses();
  }

  @override
  Widget build(BuildContext context) =>
      AppBootstrap(hostTheme: Theme.of(context));
}
