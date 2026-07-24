import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_api_cc/core/notifications/push_service.dart';

void main() {
  test('usa un id estable por conversación para mostrar y cancelar', () {
    expect(notificationIdForConversation(42), 42);
    expect(notificationIdForConversation(0x8000002A), 42);
  });

  test('recupera el chat del payload que lanzó la aplicación', () {
    expect(
      conversationIdFromNotificationPayload('{"conversation_id":731}'),
      731,
    );
    expect(conversationIdFromNotificationPayload('731'), 731);
    expect(conversationIdFromNotificationPayload(null), isNull);
  });
}
