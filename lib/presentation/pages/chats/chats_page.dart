import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_api_cc/presentation/bloc/chats/chats_bloc.dart';
import 'package:cloud_api_cc/presentation/pages/chats/widgets/chat_list.dart';
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

class _ChatsPageState extends State<ChatsPage> {
  bool _showProfile = false;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ChatsBloc>();
    bloc.add(ChatsLoadRequested());
    bloc.startPolling();
  }

  @override
  void dispose() {
    context.read<ChatsBloc>().stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatsBloc, ChatsState>(
      builder: (context, state) {
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
              onBack: () => context.read<ChatsBloc>().add(ChatsBackToList()),
              onShowProfile: () => setState(() => _showProfile = true),
              onSendMessage: (body) {
                context.read<ChatsBloc>().add(ChatsSendMessage(body: body));
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
