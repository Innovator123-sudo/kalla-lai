import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/media/media_picker.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/features/auth/application/auth_cubit.dart';
import 'package:kalla_lai/features/auth/application/auth_gateway.dart';

enum _Step { document, upload, selfie, review, processing, done, rejected }

class _DocOption {
  const _DocOption(this.code, this.label, this.subtitle, this.icon, this.color);
  final String code;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
}

const _docOptions = [
  _DocOption('CITIZENSHIP', 'Nepali Citizenship Certificate', 'Nagarikta praman patra', Icons.article, Color(0xFF2563EB)),
  _DocOption('NID', 'National Identity Card (NID)', 'Rastriya parichaya patra', Icons.badge, KallaLaiColors.indigo),
  _DocOption('PASSPORT', 'Nepali Passport', 'Machine-readable passport', Icons.menu_book, Color(0xFF0D9488)),
  _DocOption('DRIVING_LICENSE', 'Driving Licence', 'Smart card driving licence', Icons.directions_car, KallaLaiColors.amber),
  _DocOption('VOTER_ID', 'Voter Identity Card', 'Election commission ID', Icons.how_to_vote, KallaLaiColors.green),
];

// Two-sided cards need a back photo; the passport data page and citizenship
// certificate are captured front-only. Keep in sync with the server.
const _twoSidedCards = {'NID', 'DRIVING_LICENSE', 'VOTER_ID'};

const _stageLabels = [
  'Checking photo quality',
  'Reading the document (Nepali → English)',
  'Confirming the document type',
  'Matching the name on the document',
  'Matching your face to the document',
  'Liveness screening',
  'Verification decision',
];

/// In-app Nepali document verification: choose a document, capture its front
/// (and back for two-sided cards) from the gallery or camera, take a selfie,
/// then run the real quality + Nepali OCR + document-type + name + face-match
/// pipeline on the API.
class DocumentVerificationScreen extends StatefulWidget {
  const DocumentVerificationScreen({super.key});

  @override
  State<DocumentVerificationScreen> createState() =>
      _DocumentVerificationScreenState();
}

class _DocumentVerificationScreenState
    extends State<DocumentVerificationScreen> {
  _Step _step = _Step.document;
  String? _documentType;
  PickedMedia? _documentImage;
  PickedMedia? _documentBackImage;
  PickedMedia? _selfieImage;
  int _processingStage = 0;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _result;

  String get _documentLabel =>
      _docOptions.firstWhere((o) => o.code == _documentType).label;

  bool get _requiresBack => _twoSidedCards.contains(_documentType);

  bool get _documentComplete =>
      _documentImage != null && (!_requiresBack || _documentBackImage != null);

  Future<void> _pickDocument({
    required bool fromCamera,
    bool back = false,
  }) async {
    setState(() => _error = null);
    try {
      final media = await pickImage(
        fromCamera: fromCamera,
        context: context,
        cameraFacingMode: 'environment',
      );
      if (!mounted || media == null) return;
      setState(() {
        if (back) {
          _documentBackImage = media;
        } else {
          _documentImage = media;
        }
      });
    } on MediaPickException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _pickSelfie({required bool fromCamera}) async {
    setState(() => _error = null);
    try {
      final media = await pickImage(
        fromCamera: fromCamera,
        context: context,
        cameraFacingMode: 'user',
      );
      if (!mounted || media == null) return;
      setState(() => _selfieImage = media);
    } on MediaPickException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _verify() async {
    if (!_documentComplete || _selfieImage == null || _documentType == null) {
      return;
    }
    final cubit = context.read<AuthCubit>();
    setState(() {
      _submitting = true;
      _error = null;
      _step = _Step.processing;
      _processingStage = 0;
    });

    // The API runs the stages in one request, so advance the checklist while it
    // works rather than claiming each stage finished. Real per-stage results
    // come back in `verification.stages` and are shown on the next screen.
    final ticker = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_processingStage < _stageLabels.length - 1) _processingStage++;
      });
    });

    IdentityFlowResult? result;
    try {
      result = await cubit.submitDocumentVerification(
        documentType: _documentType!,
        documentImage: _documentImage!.dataUrl,
        documentBackImage: _documentBackImage?.dataUrl,
        selfieImage: _selfieImage!.dataUrl,
      );
    } finally {
      ticker.cancel();
    }
    if (!mounted) return;

    if (result == null) {
      setState(() {
        _submitting = false;
        _step = _Step.review;
        _error =
            cubit.state.errorMessage ??
            'Verification could not be completed. Please try again.';
      });
      return;
    }

    final verification = result.verification;
    if (result.identityStatus == 'VERIFIED') {
      setState(() {
        _result = verification;
        _submitting = false;
        _step = _Step.done;
      });
      return;
    }

    // A rejection is a normal decision response, not a transport error. Show
    // the exact failed stage and reason so the user knows what to fix.
    setState(() {
      _result = verification;
      _submitting = false;
      _step = _Step.rejected;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity check'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed:
              _submitting ? null : () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _header(),
                const SizedBox(height: 20),
                switch (_step) {
                  _Step.document => _documentPicker(),
                  _Step.upload => _uploadStep(),
                  _Step.selfie => _selfieStep(),
                  _Step.review => _reviewStep(),
                  _Step.processing => _processingStep(),
                  _Step.done => _doneStep(),
                  _Step.rejected => _rejectedStep(),
                },
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _errorNotice(_error!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final (title, subtitle) = switch (_step) {
      _Step.document => ('Choose your document', 'Select a supported Nepali identity document to verify.'),
      _Step.upload => ('Upload your $_documentLabel', _requiresBack ? 'Add a clear photo of the front and the back.' : 'Add a clear photo of the full document.'),
      _Step.selfie => ('Confirm it’s you', 'Take a selfie so we can match your face to the document.'),
      _Step.review => ('Review and verify', 'Check your photos, then run the secure check.'),
      _Step.processing => ('Verifying…', 'Reading your document and matching your face.'),
      _Step.done => ('You’re verified', 'Your identity check is approved.'),
      _Step.rejected => ('Check not passed', 'Fix the item below and try again.'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: KallaLaiColors.indigo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            _step == _Step.done
                ? Icons.verified_outlined
                : _step == _Step.rejected
                    ? Icons.error_outline
                    : Icons.shield_outlined,
            color: _step == _Step.rejected
                ? KallaLaiColors.errorText
                : KallaLaiColors.indigo,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: KallaLaiColors.slate,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: KallaLaiColors.muted,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(KallaLaiRadii.lg),
      side: const BorderSide(color: KallaLaiColors.outline),
    ),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );

  Widget _documentPicker() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in _docOptions) ...[
          _DocTile(
            option: option,
            onTap: () => setState(() {
              _documentType = option.code;
              _documentImage = null;
              _documentBackImage = null;
              _step = _Step.upload;
            }),
          ),
          if (option != _docOptions.last) const SizedBox(height: 10),
        ],
      ],
    ),
  );

  Widget _captureButtons({
    required bool back,
    required bool hasImage,
  }) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _submitting ? null : () => _pickDocument(fromCamera: false, back: back),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Gallery'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _submitting ? null : () => _pickDocument(fromCamera: true, back: back),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(hasImage ? 'Retake' : 'Camera'),
        ),
      ),
    ],
  );

  Widget _uploadStep() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Front side', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_documentImage != null) ...[
          _preview(_documentImage!, 'Document front'),
          const SizedBox(height: 10),
        ],
        _captureButtons(back: false, hasImage: _documentImage != null),
        if (_requiresBack) ...[
          const SizedBox(height: 18),
          const Text('Back side', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_documentBackImage != null) ...[
            _preview(_documentBackImage!, 'Document back'),
            const SizedBox(height: 10),
          ],
          _captureButtons(back: true, hasImage: _documentBackImage != null),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: !_documentComplete
              ? null
              : () => setState(() => _step = _Step.selfie),
          child: const Text('Continue'),
        ),
        TextButton(
          onPressed: () => setState(() => _step = _Step.document),
          child: const Text('Choose a different document'),
        ),
      ],
    ),
  );

  Widget _selfieStep() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selfieImage != null) ...[
          _preview(_selfieImage!, 'Selfie'),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : () => _pickSelfie(fromCamera: true),
                icon: const Icon(Icons.photo_camera_front_outlined),
                label: const Text('Take selfie'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : () => _pickSelfie(fromCamera: false),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Face the camera in good light and keep your whole face visible.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KallaLaiColors.muted),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _selfieImage == null
              ? null
              : () => setState(() => _step = _Step.review),
          child: const Text('Continue'),
        ),
        TextButton(
          onPressed: () => setState(() => _step = _Step.upload),
          child: const Text('Back to document'),
        ),
      ],
    ),
  );

  Widget _reviewStep() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_documentLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (_documentImage != null) _preview(_documentImage!, 'Document front'),
        if (_documentBackImage != null) ...[
          const SizedBox(height: 12),
          _preview(_documentBackImage!, 'Document back'),
        ],
        const SizedBox(height: 12),
        if (_selfieImage != null) _preview(_selfieImage!, 'Selfie'),
        const SizedBox(height: 12),
        Text(
          'Kalla-Lai stores the verification decision, not your raw biometric media.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KallaLaiColors.muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submitting ? null : _verify,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Verify now'),
        ),
        TextButton(
          onPressed: _submitting ? null : () => setState(() => _step = _Step.upload),
          child: const Text('Retake document photos'),
        ),
      ],
    ),
  );

  Widget _processingStep() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < _stageLabels.length; i++) ...[
          Row(
            children: [
              Icon(
                i < _processingStage
                    ? Icons.check_circle
                    : i == _processingStage
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: i <= _processingStage
                    ? KallaLaiColors.indigo
                    : KallaLaiColors.outline,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _stageLabels[i],
                  style: TextStyle(
                    fontWeight: i == _processingStage ? FontWeight.w700 : FontWeight.w500,
                    color: i <= _processingStage ? KallaLaiColors.slate : KallaLaiColors.muted,
                  ),
                ),
              ),
            ],
          ),
          if (i != _stageLabels.length - 1) const SizedBox(height: 12),
        ],
      ],
    ),
  );

  Map<String, dynamic>? get _ocrResult =>
      _result?['ocr'] as Map<String, dynamic>?;

  Map<String, dynamic>? get _faceResult =>
      _result?['faceMatch'] as Map<String, dynamic>?;

  List<Map<String, dynamic>> get _resultStages {
    final raw = _result?['stages'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((stage) {
      return <String, dynamic>{
        'key': stage['key'],
        'label': stage['label'],
        'status': stage['status'],
        'detail': stage['detail'],
      };
    }).toList();
  }

  Widget _stageList({bool showDetails = false}) {
    if (_resultStages.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final stage in _resultStages) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                switch (stage['status']) {
                  'passed' => Icons.check_circle,
                  'failed' => Icons.cancel,
                  _ => Icons.remove_circle_outline,
                },
                size: 18,
                color: switch (stage['status']) {
                  'passed' => KallaLaiColors.successText,
                  'failed' => KallaLaiColors.errorText,
                  _ => KallaLaiColors.muted,
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage['label']?.toString() ?? '',
                      style: TextStyle(
                        fontWeight: stage['status'] == 'failed'
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: KallaLaiColors.slate,
                      ),
                    ),
                    if (showDetails &&
                        stage['status'] == 'failed' &&
                        (stage['detail']?.toString().isNotEmpty ?? false)) ...[
                      const SizedBox(height: 2),
                      Text(
                        stage['detail'].toString(),
                        style: const TextStyle(
                          color: KallaLaiColors.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _doneStep() {
    final ocr = _ocrResult;
    final face = _faceResult;
    final score = (face?['score'] as num?)?.toDouble();
    final name = (ocr?['fullNameEnglish']?.toString().isNotEmpty ?? false)
        ? ocr!['fullNameEnglish'].toString()
        : ocr?['fullName']?.toString();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KallaLaiColors.successText.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(KallaLaiRadii.md),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: KallaLaiColors.successText, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Approved · you can now apply for jobs',
                    style: TextStyle(color: KallaLaiColors.successText, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _resultRow('Document', _result?['documentLabel']?.toString() ?? _documentLabel),
          if (name != null && name.isNotEmpty) _resultRow('Name (OCR)', name),
          if (ocr?['documentNumber'] != null &&
              ocr!['documentNumber'].toString().isNotEmpty)
            _resultRow('Document no.', ocr['documentNumber'].toString()),
          if (score != null)
            _resultRow('Face match', '${(score * 100).toStringAsFixed(0)}%'),
          const SizedBox(height: 8),
          _stageList(),
          const SizedBox(height: 8),
          Text(
            _result?['note']?.toString() ??
            'Only the verification decision and the extracted document fields are stored. Your photos are not kept. Passive liveness screening is a screening step, not a guarantee against sophisticated spoofing.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KallaLaiColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _rejectedStep() {
    final reason =
        _result?['reason']?.toString() ??
        _error ??
        'The verification checks did not pass. Retake your photos and try again.';
    final ocr = _ocrResult;
    final name = (ocr?['fullNameEnglish']?.toString().isNotEmpty ?? false)
        ? ocr!['fullNameEnglish'].toString()
        : ocr?['fullName']?.toString();
    final detected = _result?['documentCheck'] is Map<String, dynamic>
        ? (_result!['documentCheck'] as Map<String, dynamic>)['detectedLabel']
              ?.toString()
        : null;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(KallaLaiRadii.md),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: KallaLaiColors.errorText, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reason,
                    style: const TextStyle(
                      color: KallaLaiColors.errorText,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (detected != null && detected.isNotEmpty)
            _resultRow('Document looks like', detected),
          if (name != null && name.isNotEmpty) _resultRow('Name read', name),
          if (ocr?['documentNumber'] != null &&
              ocr!['documentNumber'].toString().isNotEmpty)
            _resultRow('Document no.', ocr['documentNumber'].toString()),
          const SizedBox(height: 8),
          _stageList(showDetails: true),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => setState(() => _step = _Step.upload),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Retake photos'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setState(() {
              _documentType = null;
              _step = _Step.document;
            }),
            child: const Text('Choose a different document'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(color: KallaLaiColors.muted))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    ),
  );

  Widget _preview(PickedMedia media, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: KallaLaiColors.muted, fontSize: 12)),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(KallaLaiRadii.md),
        child: Image.memory(
          media.bytes,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 160,
            color: KallaLaiColors.outline.withValues(alpha: 0.3),
            child: const Center(child: Icon(Icons.image_outlined, size: 40)),
          ),
        ),
      ),
    ],
  );

  Widget _errorNotice(String message) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: KallaLaiColors.errorText),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: KallaLaiColors.errorText))),
      ],
    ),
  );
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.option, required this.onTap});

  final _DocOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: option.color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(KallaLaiRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KallaLaiRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: option.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(option.icon, color: option.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(option.subtitle, style: const TextStyle(color: KallaLaiColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: KallaLaiColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}