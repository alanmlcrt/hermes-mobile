import 'dart:convert';
import 'dart:io';

import '../models/app_error.dart';
import '../models/attachment.dart';
import '../models/connection_gateway.dart';
import '../models/profile.dart';
import 'file_limits.dart';

enum AttachOutcome { uploaded, refused, uncertain }

class AttachResult {
  const AttachResult(this.outcome, {this.reference, this.errorCode});
  final AttachOutcome outcome;
  final String? reference;
  final String? errorCode;
}

/// Sends only bytes from the application's private copy to the frozen session.
class AttachmentTransport {
  const AttachmentTransport(this.gateway, this.timeout, this.limits);
  final ConnectionGateway gateway;
  final Duration timeout;
  final FileLimits limits;

  Future<AttachResult> upload(
    Attachment attachment,
    ProfileKey profile,
    String runtime,
  ) async {
    final generation = gateway.socketGeneration;
    final connection = gateway.snapshot.connection?.key;
    final refusal = limits.refusal(attachment.mediaType, attachment.bytes);
    if (refusal != null) {
      return AttachResult(AttachOutcome.refused, errorCode: refusal);
    }
    try {
      final bytes = await File(attachment.localPath).readAsBytes();
      if (bytes.length != attachment.bytes) {
        return const AttachResult(
          AttachOutcome.refused,
          errorCode: 'attachment.missing',
        );
      }
      final image = attachment.isImage;
      if (gateway.socketGeneration != generation ||
          gateway.snapshot.connection?.key != connection) {
        return const AttachResult(
          AttachOutcome.refused,
          errorCode: 'attachment.scope_changed',
        );
      }
      final result = await gateway.call(
        image ? 'image.attach_bytes' : 'file.attach',
        image
            ? {
                'session_id': runtime,
                'profile': profile.value,
                'content_base64': base64Encode(bytes),
                'filename': attachment.name,
                'ext': attachment.mediaType == 'image/jpeg' ? 'jpg' : 'png',
              }
            : {
                'session_id': runtime,
                'profile': profile.value,
                'data_url':
                    'data:${attachment.mediaType};base64,${base64Encode(bytes)}',
                'name': attachment.name,
              },
        timeout: timeout,
      );
      if (gateway.socketGeneration != generation ||
          gateway.snapshot.connection?.key != connection) {
        return const AttachResult(
          AttachOutcome.uncertain,
          errorCode: 'attachment.unknown',
        );
      }
      if (result['attached'] == false) {
        return const AttachResult(
          AttachOutcome.refused,
          errorCode: 'attachment.refused',
        );
      }
      if (result['attached'] != true) {
        return const AttachResult(
          AttachOutcome.uncertain,
          errorCode: 'attachment.unknown',
        );
      }
      String? firstReference(List<Object?> candidates) {
        for (final candidate in candidates) {
          if (candidate is String && candidate.trim().isNotEmpty) {
            return candidate.trim();
          }
        }
        return null;
      }

      final reference = image
          ? firstReference([
              if (result['text'] is String &&
                  RegExp(r'^@image:[^\s]+$')
                      .hasMatch((result['text'] as String).trim()))
                result['text'],
              if (result['path'] is String &&
                  RegExp(r'^(?:/|~/|\./)[^\r\n]+$')
                      .hasMatch(result['path'] as String))
                '@image:${result['path']}',
            ])
          : firstReference([result['ref_text'], result['ref_path']]);
      if (reference == null) {
        return const AttachResult(
          AttachOutcome.uncertain,
          errorCode: 'attachment.unknown',
        );
      }
      return AttachResult(AttachOutcome.uploaded, reference: reference);
    } on RpcError catch (error) {
      final rejected = const {
        -32700,
        -32600,
        -32601,
        -32602,
      }.contains(error.code);
      return AttachResult(
        rejected ? AttachOutcome.refused : AttachOutcome.uncertain,
        errorCode: rejected ? 'rpc.${error.code}' : 'attachment.unknown',
      );
    } on AppError catch (error) {
      return AttachResult(
        error.code == 'rpc.uncertain'
            ? AttachOutcome.uncertain
            : AttachOutcome.refused,
        errorCode: error.code == 'rpc.uncertain'
            ? 'attachment.unknown'
            : error.code,
      );
    } on FileSystemException {
      return const AttachResult(
        AttachOutcome.refused,
        errorCode: 'attachment.missing',
      );
    } catch (_) {
      return const AttachResult(
        AttachOutcome.uncertain,
        errorCode: 'attachment.unknown',
      );
    }
  }
}
