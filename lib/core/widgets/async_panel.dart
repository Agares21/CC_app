import 'package:flutter/material.dart';

class AsyncPanel extends StatelessWidget {
  const AsyncPanel({super.key, required this.future, required this.builder});
  final Future<dynamic> future;
  final Widget Function(BuildContext, dynamic) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Text(
            'No se pudo cargar la información.\n${snapshot.error}',
            textAlign: TextAlign.center,
          ),
        );
      }
      return builder(context, snapshot.data);
    },
  );
}
