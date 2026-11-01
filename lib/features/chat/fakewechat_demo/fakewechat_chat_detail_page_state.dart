import 'package:dashboard/app/platform/app_platform.dart';
import 'package:dashboard/features/chat/fakewechat_demo/fakewechat_chat_ai.dart';
import 'package:dashboard/features/chat/fakewechat_demo/fakewechat_chat_detail_page.dart';
import 'package:dashboard/features/chat/fakewechat_demo/fakewechat_control_panel.dart';
import 'package:dashboard/features/chat/fakewechat_demo/fakewechat_conversation_model.dart';
import 'package:dashboard/features/chat/fakewechat_demo/fakewechat_demo_config.dart';
import 'package:dashboard/features/chat/fakewechat_demo/fakewechat_marker.dart';
import 'package:dashboard/features/chat/fakewechat_demo/fakewechat_message.dart';
import 'package:dashboard/features/chat/fakewechat_demo/fakewechat_message_bubble.dart';
import 'package:dashboard/features/chat/fakewechat_demo/fakewechat_time_marker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FakeWechatChatDetailPageState extends State<FakeWechatChatDetailPage> {
  late final FakeWechatConversationModel _conversation;
  late final FakeWechatChatAi _ai;
  late final bool _ownsConversation;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _inputMode = true;
  bool _toolkitVisible = false;
  bool _recorderUnavailable = false;
  String _inputText = '';

  @override
  void initState() {
    super.initState();
    _ownsConversation = widget.conversation == null;
    _conversation =
        widget.conversation ??
        FakeWechatConversationModel(friend: widget.friend);
    _ai = widget.ai ?? FakeWechatChatAi();
    _ai.start(_handleReply);
  }

  @override
  void dispose() {
    _ai.dispose();
    if (_ownsConversation) {
      _conversation.dispose();
    }
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleReply(String reply) {
    if (!mounted) {
      return;
    }
    setState(() {
      _conversation.appendReply(reply, sender: _ai.replier);
    });
    _scrollToBottom();
  }

  void _send() {
    final String text = _textController.text;
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _conversation.sendText(text);
      _textController.clear();
      _inputText = '';
      _toolkitVisible = false;
    });
    _scrollToBottom();
  }

  void _toggleInputMode() {
    setState(() {
      _inputMode = !_inputMode;
      _toolkitVisible = false;
    });
    if (_inputMode) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
  }

  void _toggleToolkit() {
    setState(() {
      _toolkitVisible = !_toolkitVisible;
      if (_toolkitVisible) {
        _inputMode = true;
        _focusNode.unfocus();
      }
    });
  }

  void _showRecorderUnavailable() {
    setState(() {
      _recorderUnavailable = true;
    });
  }

  Future<void> _handleToolkitTap(String label) async {
    setState(() {
      _toolkitVisible = false;
    });
    switch (label) {
      case '相册':
        await _pickImage(ImageSource.gallery);
        return;
      case '拍摄':
        await _pickImage(ImageSource.camera);
        return;
      default:
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label 未迁入静态演示')));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!AppPlatform.supportsImagePicker) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前平台暂不支持选择图片')));
      return;
    }
    try {
      final XFile? picked = await ImagePicker().pickImage(source: source);
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _conversation.appendOutgoingImage(picked.path);
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法选择图片：$error')));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final ScrollController controller = _conversation.scrollController;
      if (!controller.hasClients) {
        return;
      }
      final double target = (_conversation.items.length * 60)
          .toDouble()
          .clamp(0.0, controller.position.maxScrollExtent)
          .toDouble();
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showMessageMenu(FakeWechatMessage message) async {
    final String? action = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 300, 100, 300),
      items: const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'delete', child: Text('删除')),
        PopupMenuItem<String>(value: 'copy', child: Text('复制')),
      ],
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'delete') {
      setState(() {
        _conversation.removeItem(message);
      });
    }
  }

  void _showAudioUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(FakeWechatDemoConfig.audioUnavailableMessage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Object> items = _conversation.items;
    return Scaffold(
      backgroundColor: FakeWechatDemoConfig.pageBackground,
      appBar: AppBar(title: Text(widget.friend.name), elevation: 0.5),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _conversation.scrollController,
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: items.length,
              itemBuilder: (BuildContext context, int index) {
                final Object item = items[index];
                if (item is FakeWechatMarker) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: FakeWechatTimeMarker(text: item.text),
                  );
                }
                final FakeWechatMessage message = item as FakeWechatMessage;
                return Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10, top: 5),
                  child: GestureDetector(
                    onLongPress: () => _showMessageMenu(message),
                    child: FakeWechatMessageBubble(
                      message: message,
                      onTapSound: _showAudioUnavailable,
                    ),
                  ),
                );
              },
            ),
          ),
          FakeWechatControlPanel(
            inputMode: _inputMode,
            controller: _textController,
            focusNode: _focusNode,
            canSend: _inputMode && _inputText.isNotEmpty,
            toolkitVisible: _toolkitVisible,
            recorderUnavailable: _recorderUnavailable,
            onToggleInputMode: _toggleInputMode,
            onChanged: (String value) {
              setState(() {
                _inputText = value;
              });
            },
            onSend: _send,
            onRecordPressed: _showRecorderUnavailable,
            onToggleToolkit: _toggleToolkit,
            onToolkitTap: _handleToolkitTap,
          ),
        ],
      ),
    );
  }
}
