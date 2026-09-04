import 'package:flutter/widgets.dart';

/// Every user-facing string in the driver app, in English and Bangla.
/// Mirrors the rider app's approach — see apps/rider_app/lib/l10n/strings.dart.
class Strings {
  const Strings(this.isBn);

  final bool isBn;

  static Strings of(BuildContext context) =>
      Strings(Localizations.localeOf(context).languageCode == 'bn');

  static const supportedLocales = [Locale('en'), Locale('bn')];

  String _(String en, String bn) => isBn ? bn : en;

  // Auth
  String get driverSignIn => _('Driver Sign In', 'ড্রাইভার সাইন ইন');
  String get email => _('Email', 'ইমেইল');
  String get password => _('Password', 'পাসওয়ার্ড');
  String get signIn => _('Sign in', 'সাইন ইন');
  String get signOut => _('Sign out', 'সাইন আউট');
  String get signingIn => _('Signing in…', 'সাইন ইন হচ্ছে…');
  String get applyHere =>
      _('New driver? Apply here', 'নতুন ড্রাইভার? এখানে আবেদন করুন');
  String get required => _('Required', 'আবশ্যক');
  String get enterValidEmail => _('Enter a valid email', 'সঠিক ইমেইল দিন');
  String get minChars => _('Min 6 characters', 'কমপক্ষে ৬ অক্ষর');
  String get min8Chars => _('Min 8 characters', 'কমপক্ষে ৮ অক্ষর');
  String get invalidCredentials =>
      _('Invalid email or password.', 'ইমেইল বা পাসওয়ার্ড ভুল।');
  String get accountSuspended => _(
        'Your account has been suspended. Contact support.',
        'আপনার অ্যাকাউন্ট স্থগিত। সাপোর্টে যোগাযোগ করুন।',
      );
  String get signInFailed => _(
        'Sign-in failed. Check your connection.',
        'সাইন ইন হয়নি। ইন্টারনেট সংযোগ দেখুন।',
      );

  // Application
  String get driverApplication => _('Driver Application', 'ড্রাইভার আবেদন');
  String get yourDetails => _('Your details', 'আপনার তথ্য');
  String get fullName => _('Full name', 'পুরো নাম');
  String get phoneNumber => _('Phone number', 'ফোন নম্বর');
  String get vehicle => _('Vehicle', 'গাড়ি');
  String get make => _('Make (e.g. Toyota)', 'ব্র্যান্ড (যেমন Toyota)');
  String get model => _('Model (e.g. Prius)', 'মডেল (যেমন Prius)');
  String get colour => _('Colour', 'রং');
  String get plate => _('Registration plate', 'রেজিস্ট্রেশন নম্বর');
  String get submitApplication => _('Submit application', 'আবেদন জমা দিন');
  String get submitting => _('Submitting…', 'জমা হচ্ছে…');
  String get reviewNotice => _(
        'Your application will be reviewed by our team. '
            'You can go online once approved.',
        'আপনার আবেদন আমাদের টিম যাচাই করবে। '
            'অনুমোদন পেলে আপনি অনলাইনে যেতে পারবেন।',
      );
  String get emailInUse => _(
        'An account with this email already exists.',
        'এই ইমেইল দিয়ে আগেই অ্যাকাউন্ট আছে।',
      );
  String get weakPassword => _('Password is too weak.', 'পাসওয়ার্ডটি দুর্বল।');
  String get registrationFailed => _(
        'Registration failed. Check your connection.',
        'নিবন্ধন হয়নি। ইন্টারনেট সংযোগ দেখুন।',
      );

  // Approval states
  String get applicationStatus => _('Application status', 'আবেদনের অবস্থা');
  String get underReview => _(
        'Your application is under review.',
        'আপনার আবেদন যাচাই করা হচ্ছে।',
      );
  String get notApproved => _(
        'Your application was not approved.',
        'আপনার আবেদন অনুমোদিত হয়নি।',
      );
  String get willNotify => _(
        "We'll notify you as soon as you're approved. "
            'This screen updates automatically.',
        'অনুমোদন পেলে সাথে সাথে জানানো হবে। '
            'এই স্ক্রিন নিজে থেকেই আপডেট হয়।',
      );
  String get contactSupport => _(
        'Please contact support for more information.',
        'বিস্তারিত জানতে সাপোর্টে যোগাযোগ করুন।',
      );

  // Documents
  String get documents => _('Documents', 'কাগজপত্র');
  String get verificationDocuments =>
      _('Verification documents', 'যাচাইয়ের কাগজপত্র');
  String get uploadDocuments => _('Upload documents', 'কাগজপত্র আপলোড করুন');
  String get reviewDocuments => _('Review documents', 'কাগজপত্র দেখুন');
  String get documentsIntro => _(
        'Upload a clear photo of each document. Our team reviews them '
            'before approving your account.',
        'প্রতিটি কাগজের স্পষ্ট ছবি আপলোড করুন। অনুমোদনের আগে '
            'আমাদের টিম এগুলো যাচাই করবে।',
      );
  String get documentsIncomplete => _(
        "Your documents are still incomplete — we can't review your "
            'application until they\'re uploaded.',
        'আপনার কাগজপত্র এখনো অসম্পূর্ণ — আপলোড না করলে আবেদন '
            'যাচাই করা যাবে না।',
      );
  String get allDocumentsUploaded => _(
        'All documents uploaded. Your application is ready for review.',
        'সব কাগজপত্র আপলোড হয়েছে। আবেদন যাচাইয়ের জন্য প্রস্তুত।',
      );
  String get uploaded => _('Uploaded', 'আপলোড হয়েছে');
  String get notUploaded => _('Not uploaded yet', 'এখনো আপলোড হয়নি');
  String get upload => _('Upload', 'আপলোড');
  String get replace => _('Replace', 'বদলান');
  String get uploadFailed => _(
        'Upload failed. Check your connection and try again.',
        'আপলোড হয়নি। সংযোগ দেখে আবার চেষ্টা করুন।',
      );
  String get expiryDate => _('Expiry date', 'মেয়াদ শেষের তারিখ');
  String get setExpiryDate =>
      _('Set expiry date', 'মেয়াদের তারিখ দিন');
  String get expiryMissing => _(
        'Expiry date needed',
        'মেয়াদের তারিখ দরকার',
      );
  String get expiryRequiredNotice => _(
        'Licence and insurance must show when they run out. We remind you '
            'before they do.',
        'লাইসেন্স ও বিমার মেয়াদ কবে শেষ হবে তা দিতে হবে। শেষ হওয়ার '
            'আগে আমরা মনে করিয়ে দেব।',
      );
  String expiresOn(String date) =>
      _('Valid until $date', '$date পর্যন্ত বৈধ');
  String expiresInDays(int days) => _(
        'Expires in $days day${days == 1 ? '' : 's'}',
        '$days দিনে মেয়াদ শেষ',
      );
  String get expired => _('Expired', 'মেয়াদ শেষ');
  String get documentsExpiredTitle => _(
        'You are offline — a document expired',
        'আপনি অফলাইন — একটি কাগজের মেয়াদ শেষ',
      );
  String get documentsExpiredBody => _(
        'Upload the renewed document with its new expiry date. Our team '
            'puts you back online once it checks out.',
        'নতুন মেয়াদসহ কাগজটি আপলোড করুন। যাচাই হলে আমাদের টিম '
            'আপনাকে আবার অনলাইনে ফিরিয়ে আনবে।',
      );
  String get documentsExpiringSoon => _(
        'A document expires soon — renew it before you are taken offline.',
        'একটি কাগজের মেয়াদ শেষ হতে চলেছে — অফলাইন হওয়ার আগে নবায়ন করুন।',
      );
  String get drivingLicence => _('Driving licence', 'ড্রাইভিং লাইসেন্স');
  String get insuranceCertificate =>
      _('Insurance certificate', 'বিমার সনদ');
  String get vehiclePhoto => _('Vehicle photo', 'গাড়ির ছবি');

  // Home / online
  String get youAreOnline => _('You are online', 'আপনি অনলাইনে আছেন');
  String get youAreOffline => _('You are offline', 'আপনি অফলাইনে আছেন');
  String get goOnlineForRequests => _(
        'Go online to receive ride requests.',
        'যাত্রার অনুরোধ পেতে অনলাইনে যান।',
      );
  String get waitingForRequests =>
      _('Waiting for ride requests…', 'যাত্রার অনুরোধের অপেক্ষায়…');
  String get rideNoLongerAvailable =>
      _('Ride no longer available.', 'যাত্রাটি আর নেই।');

  // Active ride
  String get headingToPickup =>
      _('Heading to pickup', 'যাত্রীর কাছে যাচ্ছেন');
  String get waitingForRider =>
      _('Waiting for rider', 'যাত্রীর অপেক্ষায়');
  String get tripInProgress => _('Trip in progress', 'যাত্রা চলছে');
  String get iHaveArrived => _('I have arrived', 'আমি পৌঁছেছি');
  String get startTrip => _('Start trip', 'যাত্রা শুরু');
  String get completeTrip => _('Complete trip', 'যাত্রা শেষ');
  String get navigateToPickup =>
      _('Navigate to pickup', 'যাত্রীর কাছে পথ দেখান');
  String get navigateToDropoff =>
      _('Navigate to dropoff', 'গন্তব্যে পথ দেখান');
  String get cancelRide => _('Cancel ride', 'যাত্রা বাতিল করুন');
  String get cancelRideQuestion =>
      _('Cancel this ride?', 'যাত্রাটি বাতিল করবেন?');
  String get cancelWarning => _(
        'Frequent cancellations affect your standing.',
        'বারবার বাতিল করলে আপনার রেটিং-এ প্রভাব পড়ে।',
      );
  String get keepRide => _('Keep ride', 'যাত্রা রাখুন');
  String get callRider => _('Call rider', 'যাত্রীকে ফোন করুন');
  String riderName(String name) => _('Rider: $name', 'যাত্রী: $name');

  // Earnings & payouts
  String get earnings => _('Earnings', 'আয়');
  String get netEarnings =>
      _('Net earnings (last 50 trips)', 'নিট আয় (শেষ ৫০ যাত্রা)');
  String get noCompletedTrips =>
      _('No completed trips yet.', 'এখনো কোনো যাত্রা সম্পন্ন হয়নি।');
  String get setUpPayouts => _('Set up payouts', 'পেমেন্ট সেটআপ করুন');
  String get payoutIntro => _(
        'Add your bank details with Stripe so card fares reach you '
            'automatically. Until then riders have to pay you in cash.',
        'Stripe-এ ব্যাংকের তথ্য দিন যাতে কার্ডের ভাড়া নিজে থেকেই আপনার '
            'কাছে আসে। ততক্ষণ যাত্রীদের নগদে দিতে হবে।',
      );
  String get payoutOpenFailed => _(
        'Could not open payout setup. Please try again.',
        'পেমেন্ট সেটআপ খোলা যায়নি। আবার চেষ্টা করুন।',
      );
  String get opening => _('Opening…', 'খোলা হচ্ছে…');
  String fareAndCommission(String fare, String commission) => _(
        'Fare $fare · commission $commission',
        'ভাড়া $fare · কমিশন $commission',
      );
}
