import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_api_cc/presentation/bloc/chats/chats_bloc.dart';
import 'package:cloud_api_cc/presentation/pages/chats/widgets/chat_list.dart';
import 'package:cloud_api_cc/presentation/pages/chats/widgets/chat_taken_view.dart';
import 'package:cloud_api_cc/presentation/pages/chats/widgets/conversation_view.dart';
import 'package:cloud_api_cc/presentation/pages/chats/widgets/profile_panel.dart';

/// Página principal de chats.
///
/// En mobile muestra una sola vista a la vez:
/// lista → conversación → perfil, con navegación back.
class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> with WidgetsBindingObserver {
  bool _showProfile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final bloc = context.read<ChatsBloc>();
    bloc.add(ChatsLoadRequested());
    bloc.startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<ChatsBloc>().stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<ChatsBloc>().add(ChatsRefreshSilent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatsBloc, ChatsState>(
      builder: (context, state) {
        if (state.chatTaken) {
          return ChatTakenView(
            onBack: () => context.read<ChatsBloc>().add(ChatsDismissTaken()),
          );
        }

        // Si hay un hilo seleccionado y se pide el perfil
        if (_showProfile && state.detail != null) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) setState(() => _showProfile = false);
            },
            child: ProfilePanel(
              detail: state.detail!,
              onBack: () => setState(() => _showProfile = false),
            ),
          );
        }

        // Si hay un hilo seleccionado, mostrar conversación
        if (state.selectedId != null) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) context.read<ChatsBloc>().add(ChatsBackToList());
            },
            child: ConversationView(
              detail: state.detail,
              loading: state.loadingDetail,
              sending: state.sending,
              sendNotice: state.sendNotice,
              sendRevision: state.sendRevision,
              restoreLastMessage: state.restoreLastMessage,
              onBack: () => context.read<ChatsBloc>().add(ChatsBackToList()),
              onShowProfile: () => setState(() => _showProfile = true),
              onSendMessage: (body, {mediaPath, mediaName}) {
                context.read<ChatsBloc>().add(
                  ChatsSendMessage(
                    body: body,
                    mediaPath: mediaPath,
                    mediaName: mediaName,
                  ),
                );
              },
            ),
          );
        }

        // Vista por defecto: lista de chats
        return ChatList(
          conversations: state.conversations,
          loading: state.loadingList,
          archivedCount: state.archivedCount,
          onSelectConversation: (id) {
            context.read<ChatsBloc>().add(ChatsSelectConversation(id));
          },
        );
      },
    );
  }
}
