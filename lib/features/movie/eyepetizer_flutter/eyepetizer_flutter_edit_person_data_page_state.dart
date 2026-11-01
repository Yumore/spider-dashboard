import 'dart:async';

import 'package:dashboard/features/movie/eyepetizer_flutter/eyepetizer_flutter_cover_image_widget.dart';
import 'package:dashboard/app/platform/app_platform.dart';
import 'package:dashboard/app/platform/app_toast.dart';
import 'package:dashboard/features/movie/eyepetizer_flutter/eyepetizer_flutter_date_util.dart';
import 'package:dashboard/features/movie/eyepetizer_flutter/eyepetizer_flutter_edit_person_data_page.dart';
import 'package:dashboard/features/movie/eyepetizer_flutter/eyepetizer_flutter_exception.dart';
import 'package:dashboard/features/movie/eyepetizer_flutter/eyepetizer_flutter_item_person_data_input_widget.dart';
import 'package:dashboard/features/movie/eyepetizer_flutter/eyepetizer_flutter_person_repository.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// State for [EyepetizerFlutterEditPersonDataPage].
///
/// Deviations from the source, all forced by host dependencies or by the
/// picker's current API:
///
/// * `image_picker`'s `getImage` is gone; `pickImage` returns an `XFile` whose
///   `path` is uploaded exactly as before;
/// * `date_format` is not a host dependency, so the birthday string is produced
///   by [EyepetizerFlutterDateUtil.formatBirthdaySeconds] — which reproduces the
///   source's `DateTime.fromMicrosecondsSinceEpoch(birthday * 1000)` reading,
///   including its near-1970 result;
/// * the picked file is not previewed locally (that needed `dart:io` and an
///   `assets` avatar placeholder); the uploaded URL returned by the API is what
///   the cover/avatar show.
class EyepetizerFlutterEditPersonDataPageState
    extends State<EyepetizerFlutterEditPersonDataPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _jobController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late final EyepetizerFlutterPersonRepository _repository;
  late final bool _ownsRepository;

  String _coverUrl = '';
  String _avatarUrl = '';
  String _currentType = EyepetizerFlutterEditPersonDataPage.typeCover;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ownsRepository = widget.repository == null;
    _repository = widget.repository ?? EyepetizerFlutterPersonRepository();
    final userInfo = widget.userInfo;
    if (userInfo != null) {
      _nameController.text = userInfo.name ?? '';
      _genderController.text = userInfo.gender == 'male' ? '男' : '女';
      _birthdayController.text =
          EyepetizerFlutterDateUtil.formatBirthdaySeconds(userInfo.birthday);
      _cityController.text = userInfo.city ?? '';
      _universityController.text = userInfo.university ?? '';
      _jobController.text = userInfo.job ?? '';
      _descriptionController.text = userInfo.description;
      _coverUrl = userInfo.cover;
      _avatarUrl = userInfo.icon;
    } else {
      _genderController.text = '女';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genderController.dispose();
    _birthdayController.dispose();
    _cityController.dispose();
    _universityController.dispose();
    _jobController.dispose();
    _descriptionController.dispose();
    if (_ownsRepository) _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: <Widget>[
          SafeArea(
            child: Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const Spacer(),
                const Text('编辑个人资料'),
                const Spacer(),
                TextButton(
                  onPressed: _saving ? null : save,
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    GestureDetector(
                      onTap: () => unawaited(
                        getImage(
                          type: EyepetizerFlutterEditPersonDataPage.typeCover,
                        ),
                      ),
                      child: EyepetizerFlutterCoverImageWidget(
                        imageUrl: _coverUrl.isEmpty ? null : _coverUrl,
                        width: double.infinity,
                        height: 160,
                      ),
                    ),
                    const Positioned(
                      right: 10,
                      bottom: 10,
                      child: Icon(Icons.camera_alt),
                    ),
                    Positioned(
                      left: 15,
                      top: 90,
                      child: GestureDetector(
                        onTap: () => unawaited(
                          getImage(
                            type:
                                EyepetizerFlutterEditPersonDataPage.typeAvatar,
                          ),
                        ),
                        child: EyepetizerFlutterCoverImageWidget(
                          imageUrl: _avatarUrl.isEmpty ? null : _avatarUrl,
                          width: 80,
                          height: 80,
                          borderRadius: 100,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: <Widget>[
                      EyepetizerFlutterItemPersonDataInputWidget(
                        title: '名字',
                        controller: _nameController,
                      ),
                      EyepetizerFlutterItemPersonDataInputWidget(
                        title: '性别',
                        controller: _genderController,
                      ),
                      EyepetizerFlutterItemPersonDataInputWidget(
                        title: '生日',
                        controller: _birthdayController,
                      ),
                      EyepetizerFlutterItemPersonDataInputWidget(
                        title: '所在地',
                        controller: _cityController,
                      ),
                      EyepetizerFlutterItemPersonDataInputWidget(
                        title: '学校',
                        controller: _universityController,
                      ),
                      EyepetizerFlutterItemPersonDataInputWidget(
                        title: '职业',
                        controller: _jobController,
                      ),
                      EyepetizerFlutterItemPersonDataInputWidget(
                        title: '简介',
                        controller: _descriptionController,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The source's camera/gallery chooser, then an immediate upload of the
  /// picked file.
  Future<void> getImage({required String type}) async {
    _currentType = type;
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('请选择'),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Text('相机'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            child: const Text('相册'),
          ),
        ],
      ),
    );
    if (source == null) return;
    if (!AppPlatform.supportsFileSystem || !AppPlatform.supportsImagePicker) {
      // Web 上 image_picker 返回 blob 路径，无法作为本地文件上传。
      await AppToast.show(msg: '当前平台暂不支持上传图片');
      return;
    }
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    await uploadPicture(picked.path);
  }

  /// The source's `uploadPicture`: the response's `item.url` lands in the cover
  /// or the avatar, depending on which picker started the upload.
  Future<void> uploadPicture(String filePath) async {
    try {
      final value = await _repository.uploadPicture(filePath);
      if (!mounted) return;
      setState(() {
        if (_currentType == EyepetizerFlutterEditPersonDataPage.typeCover) {
          _coverUrl = value.item?.url ?? '';
        } else {
          _avatarUrl = value.item?.url ?? '';
        }
      });
    } on EyepetizerFlutterException catch (error) {
      await AppToast.show(msg: error.message);
    }
  }

  /// `EditPersonDataState.save` — `error == 0` is success.
  Future<void> save() async {
    setState(() => _saving = true);
    try {
      final value = await _repository.savePersonData(
        cover: _coverUrl,
        avatar: _avatarUrl,
        name: _nameController.text,
        gender: _genderController.text,
        birthday: _birthdayController.text,
        city: _cityController.text,
        university: _universityController.text,
        job: _jobController.text,
        description: _descriptionController.text,
      );
      if ((value.error ?? -1) == 0) {
        await AppToast.show(msg: '保存成功');
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        await AppToast.show(msg: '保存失败');
      }
    } on EyepetizerFlutterException catch (error) {
      await AppToast.show(msg: error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
