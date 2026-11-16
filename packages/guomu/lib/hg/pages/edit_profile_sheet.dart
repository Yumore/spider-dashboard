import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/app_controllers.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_adaptive_sheet.dart';
import '../widgets/secure_cover.dart';

const List<String> kHgAvatarPalette = [
  '#4FB37A',
  '#56C4A7',
  '#5C7FD1',
  '#65AADD',
  '#6E8494',
  '#6EC9CB',
  '#7B6FD4',
  '#7BC862',
  '#8C8C8C',
  '#9B5FC7',
  '#A695E7',
  '#A8C256',
  '#B07C5A',
  '#C25B4E',
  '#C86FC0',
  '#D0567F',
  '#E0A33E',
  '#E17076',
  '#EE7AAE',
  '#FAA774',
];

Future<bool?> showEditProfileSheet(BuildContext context, HgUser user) {
  return showHgAdaptiveSheetBuilder<bool>(
    context,
    childScrollable: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => _EditProfileSheet(user: user),
  );
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.user});

  final HgUser user;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nickname;
  late final TextEditingController _sign;
  late String _avatarColor;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: widget.user.nickname);
    _sign = TextEditingController(text: widget.user.sign);
    final current = widget.user.avatarColor.toUpperCase();
    _avatarColor = kHgAvatarPalette.contains(current)
        ? current
        : kHgAvatarPalette.first;
  }

  @override
  void dispose() {
    _nickname.dispose();
    _sign.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().updateProfile(
        nickname: _nickname.text,
        sign: _sign.text,
        avatarColor: _avatarColor,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = cleanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        decoration: BoxDecoration(
          color: context.hgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 9, 20, 18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E4E6),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF5F5F64),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    '编辑资料',
                    style: TextStyle(
                      color: Color(0xFF1E1E21),
                      fontSize: 25,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: HgAvatar(
                      name: _nickname.text,
                      url: widget.user.avatar,
                      size: 80,
                      color: colorFromHex(_avatarColor),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      '选择官方头像色板',
                      style: TextStyle(
                        color: Color(0xFF85858A),
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: kHgAvatarPalette.length,
                    itemBuilder: (context, index) {
                      final colorHex = kHgAvatarPalette[index];
                      final selected = colorHex == _avatarColor;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _avatarColor = colorHex);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          decoration: BoxDecoration(
                            color: colorFromHex(colorHex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? HgColors.ink
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: selected
                                ? const [
                                    BoxShadow(
                                      color: Color(0x22000000),
                                      blurRadius: 9,
                                      offset: Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const _EditLabel('昵称'),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: _nickname,
                    maxLength: 20,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.next,
                    decoration: _editDecoration(
                      context: context,
                      hint: '请输入昵称',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return '请输入昵称';
                      if (text.length > 20) return '昵称不能超过 20 个字符';
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  const _EditLabel('个性签名'),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: _sign,
                    maxLength: 100,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    decoration: _editDecoration(
                      context: context,
                      hint: '写一句介绍，可不填',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB8442C),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: HgColors.ink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFB9B9BD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '保存资料',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _editDecoration({
    required BuildContext context,
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.hgMuted, fontSize: 13),
      filled: true,
      fillColor: context.hgSurfaceMuted,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF242427), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD36B56)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD36B56), width: 1.2),
      ),
    );
  }
}

class _EditLabel extends StatelessWidget {
  const _EditLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF5F5F64),
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
