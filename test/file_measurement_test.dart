import 'package:flutter_test/flutter_test.dart';

import '../tool/mesure_pieces_jointes.dart';

Map<String, dynamic> _limite({
  List<int> acceptedBytes = const [],
  List<int> refusedBytes = const [],
  List<int> acceptedCounts = const [],
  List<int> refusedCounts = const [],
  List<int> unverifiedBytes = const [],
  List<int> unverifiedCounts = const [],
  List<String> mediaTypes = const [],
  List<String> receipts = const [],
  List<Map<String, dynamic>> evidence = const [],
}) {
  return summarizeLimit(
    acceptedBytes: acceptedBytes,
    refusedBytes: refusedBytes,
    acceptedCounts: acceptedCounts,
    refusedCounts: refusedCounts,
    unverifiedBytes: unverifiedBytes,
    unverifiedCounts: unverifiedCounts,
    mediaTypes: mediaTypes,
    receipts: receipts,
    evidence: evidence,
    measuredAt: '2026-10-24T12:00:00Z',
  );
}

void main() {
  group('classifyOutcome', () {
    test('ACCEPTÉ : une pièce reçue et confirmée est acceptée', () {
      expect(
        classifyOutcome(
          present: true,
          error: null,
          uncertain: false,
          acceptedCount: 1,
          receiptConfirmed: true,
        ),
        Outcome.accepted,
      );
    });

    test('REFUSÉ : une pièce présente mais rejetée est refusée', () {
      expect(
        classifyOutcome(
          present: true,
          error: 'http_413',
          uncertain: false,
          acceptedCount: 0,
          receiptConfirmed: false,
        ),
        Outcome.refused,
      );
    });

    test('ABSENT : une méthode manquante reste absente', () {
      expect(
        classifyOutcome(
          present: false,
          error: 'method_missing',
          uncertain: false,
          acceptedCount: 0,
          receiptConfirmed: false,
        ),
        Outcome.absent,
      );
    });

    test('INCERTAIN : une mesure douteuse reste non vérifiée', () {
      expect(
        classifyOutcome(
          present: true,
          error: null,
          uncertain: true,
          acceptedCount: 0,
          receiptConfirmed: false,
        ),
        Outcome.unverified,
      );
    });

    test('INCERTAIN : un envoi sans reçu serveur reste non vérifié', () {
      expect(
        classifyOutcome(
          present: true,
          error: null,
          uncertain: false,
          acceptedCount: 1,
          receiptConfirmed: false,
        ),
        Outcome.unverified,
      );
    });
  });

  group('summarizeLimit', () {
    test('ACCEPTÉ : sans refus, la borne basse est le plus grand accepté', () {
      final limite = _limite(acceptedBytes: [1000]);
      expect(limite['maxBytes'], 1000);
      expect(limite['maxBytesVerified'], isTrue);
      expect((limite['threshold'] as Map)['bytes'], 'lower-bound');
    });

    test('REFUSÉ : le seuil se situe entre le plus grand accepté et le plus '
        'petit refus', () {
      final limite = _limite(acceptedBytes: [1000], refusedBytes: [2000]);
      expect(limite['maxBytes'], 1000);
      expect(limite['maxBytesVerified'], isTrue);
      expect((limite['threshold'] as Map)['bytes'], 'between');
    });

    test('REFUSÉ : la limite la plus restrictive est retenue', () {
      final limite = _limite(
        acceptedBytes: [1000, 2500],
        refusedBytes: [3000, 2000],
      );
      expect(limite['maxBytes'], 1000);
      expect((limite['threshold'] as Map)['bytes'], 'between');
    });

    test(
      'REFUSÉ : sans accepté sous le plafond, aucun seuil n\'est mesuré',
      () {
        final limite = _limite(refusedBytes: [2000]);
        expect(limite['maxBytes'], isNull);
        expect(limite['maxBytesVerified'], isFalse);
        expect(limite['verified'], isFalse);
        expect((limite['threshold'] as Map)['bytes'], 'not-measured');
      },
    );

    test('INCERTAIN : seules des observations non vérifiées ne produisent '
        'aucune limite', () {
      final limite = _limite(unverifiedBytes: [1500], unverifiedCounts: [2]);
      expect(limite['maxBytes'], isNull);
      expect(limite['maxCount'], isNull);
      expect(limite['verified'], isFalse);
      expect((limite['threshold'] as Map)['bytes'], 'not-measured');
      expect((limite['threshold'] as Map)['count'], 'not-measured');
    });

    test('NOMBRE : un refus au-delà du compte accepté fixe la limite', () {
      final limite = _limite(acceptedCounts: [3], refusedCounts: [4]);
      expect(limite['maxCount'], 3);
      expect(limite['maxCountVerified'], isTrue);
      expect((limite['threshold'] as Map)['count'], 'between');
    });

    test(
      'NOMBRE : sans refus, le compte accepté reste une borne inférieure',
      () {
        final limite = _limite(acceptedCounts: [3]);
        expect(limite['maxCount'], isNull);
        expect(limite['maxCountVerified'], isFalse);
        expect((limite['threshold'] as Map)['count'], 'lower-bound');
      },
    );

    test('NOMBRE : un plafond de un ne permet aucune valeur vérifiée', () {
      final limite = _limite(acceptedCounts: [0], refusedCounts: [1]);
      expect(limite['maxCount'], isNull);
      expect(limite['maxCountVerified'], isFalse);
      expect((limite['threshold'] as Map)['count'], 'not-measured');
    });

    test('les preuves identiques sont dédupliquées, pas les preuves '
        'distinctes', () {
      final limite = _limite(
        evidence: [
          {
            'surface': 'file.attach',
            'receipt': 'history-attached-context',
            'bytes': 1000,
            'count': 1,
            'at': '2026-10-24T12:00:00Z',
          },
          {
            'surface': 'file.attach',
            'receipt': 'history-attached-context',
            'bytes': 1000,
            'count': 1,
            'at': '2026-10-24T12:00:00Z',
          },
          {
            'surface': 'file.attach',
            'receipt': 'history-image-reference',
            'bytes': 2000,
            'count': 1,
            'at': '2026-10-24T12:00:00Z',
          },
        ],
      );
      expect(limite['evidence'], hasLength(2));
    });
  });

  group('visionVerdict', () {
    test('IMAGE / MODÈLE : un refus explicite est consigné comme tel', () {
      final verdict = visionVerdict(
        answer: "Je ne peux pas voir l'image",
        marker: 'banane',
      );
      expect(verdict.analyzes, isFalse);
      expect(verdict.evidence, 'denial');
    });

    test('IMAGE / MODÈLE : un marqueur observé prouve l\'analyse', () {
      final verdict = visionVerdict(answer: 'BANANE', marker: 'banane');
      expect(verdict.analyzes, isTrue);
      expect(verdict.evidence, 'marker');
    });

    test('IMAGE / MODÈLE : une réponse neutre reste non observée', () {
      final verdict = visionVerdict(
        answer: 'Réponse neutre sans indication.',
        marker: 'banane',
      );
      expect(verdict.analyzes, isNull);
      expect(verdict.evidence, 'unobserved');
    });

    test('IMAGE / MODÈLE : marqueur et dénégation restent ambigus', () {
      final verdict = visionVerdict(
        answer: "Je ne vois pas l'image, mais je lis BANANE.",
        marker: 'banane',
      );
      expect(verdict.analyzes, isNull);
      expect(verdict.evidence, 'ambiguous');
    });
  });

  group('receiptVerdict', () {
    test('IMAGE : une occurrence commune ne prouve pas trois copies', () {
      final verdict = receiptVerdict(
        surface: 'image.attach_bytes',
        content: '@image:/config/shared.jpg',
        attachments: List.generate(3, (_) => ['/config/shared.jpg']),
      );
      expect(verdict.received, 1);
    });

    test('IMAGE : comparaison exacte et retrait de tous les échos du prompt', () {
      const prompt = '@image:/config/a.jpg texte';
      final verdict = receiptVerdict(
        surface: 'image.attach_bytes',
        content: '$prompt\n$prompt\n@image:/config/a.jpg.backup',
        submittedPrompt: prompt,
        attachments: [
          ['/config/a.jpg'],
        ],
      );
      expect(verdict.confirmed, isFalse);
      expect(verdict.received, 0);
    });

    test('FILE.ATTACH : l\'écho du prompt seul ne confirme pas', () {
      final verdict = receiptVerdict(
        surface: 'file.attach',
        content: '@file:attachments/a.txt Mesure [mesure:abc]',
        attachments: [
          ['@file:attachments/a.txt'],
        ],
      );
      expect(verdict.confirmed, isFalse);
      expect(verdict.received, 0);
      expect(verdict.receipt, isNull);
    });

    test('FILE.ATTACH : le bloc serveur confirme chaque pièce', () {
      final verdict = receiptVerdict(
        surface: 'file.attach',
        content:
            '@file:attachments/a.txt @file:attachments/b.pdf Mesure\n\n'
            '--- Attached Context ---\n\n'
            '📄 @file:attachments/a.txt\n'
            '📎 @file:attachments/b.pdf (application/pdf, 1 KB)',
        attachments: [
          ['@file:attachments/a.txt'],
          ['@file:attachments/b.pdf'],
        ],
      );
      expect(verdict.confirmed, isTrue);
      expect(verdict.received, 2);
      expect(verdict.receipt, 'history-attached-context');
    });

    test('FILE.ATTACH : une pièce absente du bloc reste non confirmée', () {
      final verdict = receiptVerdict(
        surface: 'file.attach',
        content:
            '@file:attachments/a.txt @file:attachments/b.pdf Mesure\n\n'
            '--- Attached Context ---\n\n'
            '📄 @file:attachments/a.txt',
        attachments: [
          ['@file:attachments/a.txt'],
          ['@file:attachments/b.pdf'],
        ],
      );
      expect(verdict.confirmed, isTrue);
      expect(verdict.received, 1);
    });

    test('IMAGE : les lignes @image: du serveur confirment la réception', () {
      final verdict = receiptVerdict(
        surface: 'image.attach_bytes',
        content:
            'Décris cette image. [mesure:abc]\n'
            '@image:/config/upload_1.png\n'
            '@image:/config/upload_2.png',
        attachments: [
          ['/config/upload_1.png'],
          ['/config/upload_2.png'],
        ],
      );
      expect(verdict.confirmed, isTrue);
      expect(verdict.received, 2);
      expect(verdict.receipt, 'history-image-reference');
    });

    test('IMAGE : sans ligne @image:, le prompt seul ne confirme pas', () {
      final verdict = receiptVerdict(
        surface: 'rest.image-upload',
        content: 'Décris cette image. [mesure:abc]',
        attachments: [
          ['/config/upload_1.png'],
        ],
      );
      expect(verdict.confirmed, isFalse);
      expect(verdict.received, 0);
    });
  });

  group('hasUsableTransport', () {
    Map<String, dynamic> contract({
      required String status,
      required int accepted,
      String surface = 'file.attach',
    }) {
      return {
        'transports': {
          'file.attach': {
            'status': surface == 'file.attach' ? status : 'absent',
            'proof': surface == 'file.attach'
                ? {'accepted': accepted}
                : null,
          },
          'rest.image-upload': {
            'status': surface == 'rest.image-upload' ? status : 'present',
            'proof': {'accepted': 1},
          },
        },
      };
    }

    test('un file.attach présent avec preuve acceptée est exploitable', () {
      expect(
        hasUsableTransport(contract(status: 'present', accepted: 1)),
        isTrue,
      );
    });

    test('un file.attach présent qui refuse tout n\'est pas exploitable', () {
      expect(
        hasUsableTransport(contract(status: 'present', accepted: 0)),
        isFalse,
      );
    });

    test('une route image ne débloque pas à la place de file.attach', () {
      expect(
        hasUsableTransport(
          contract(
            status: 'present',
            accepted: 1,
            surface: 'rest.image-upload',
          ),
        ),
        isFalse,
      );
    });
  });
}
