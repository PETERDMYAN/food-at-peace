import 'package:http/http.dart' as http;

/// Submits user feedback to a Google Form.
///
/// Fill these from your form's "Get pre-filled link":
///  - [formResponseUrl]: the form URL with `/viewform` replaced by
///    `/formResponse`, e.g.
///    `https://docs.google.com/forms/d/e/FORM_ID/formResponse`
///  - [messageEntryId] / [emailEntryId]: the `entry.NNNNNNN` field ids that
///    appear in the pre-filled link.
class FeedbackService {
  // Wired to the "Food at Peace Feedback" Google Form (email collection off).
  static const String formResponseUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLSfkdrCf9Ugiv1mY4gcdiDKsJBs44Jj8zq2ojMINdnftEMyolQ/formResponse';
  static const String messageEntryId = 'entry.531227680';
  static const String emailEntryId = '';

  /// True once the Google Form details above have been filled in.
  bool get isConfigured =>
      formResponseUrl.isNotEmpty && messageEntryId.isNotEmpty;

  Future<bool> submit({required String message, String? email}) async {
    if (!isConfigured) return false;
    final body = <String, String>{messageEntryId: message};
    if (emailEntryId.isNotEmpty && email != null && email.isNotEmpty) {
      body[emailEntryId] = email;
    }
    try {
      final res = await http.post(Uri.parse(formResponseUrl), body: body);
      return res.statusCode >= 200 && res.statusCode < 400;
    } catch (_) {
      return false;
    }
  }
}
