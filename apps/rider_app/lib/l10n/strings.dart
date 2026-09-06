import 'package:flutter/widgets.dart';

/// Every user-facing string in the rider app, in English and Bangla.
///
/// Hand-rolled rather than generated from .arb files: the string set is small,
/// this keeps the build free of codegen, and the two translations sit next to
/// each other so they can't drift apart unnoticed.
class Strings {
  const Strings(this.isBn);

  /// True when the device (or the user's override) is Bangla.
  final bool isBn;

  static Strings of(BuildContext context) =>
      Strings(Localizations.localeOf(context).languageCode == 'bn');

  /// Locales the app ships translations for.
  static const supportedLocales = [Locale('en'), Locale('bn')];

  String _(String en, String bn) => isBn ? bn : en;

  // Auth
  String get welcomeBack => _('Welcome back', 'আবার স্বাগতম');
  String get createAccount => _('Create account', 'অ্যাকাউন্ট তৈরি করুন');
  String get fullName => _('Full name', 'পুরো নাম');
  String get phoneNumber => _('Phone number', 'ফোন নম্বর');
  String get email => _('Email', 'ইমেইল');
  String get password => _('Password', 'পাসওয়ার্ড');
  String get signIn => _('Sign in', 'সাইন ইন');
  String get signOut => _('Sign out', 'সাইন আউট');
  String get pleaseWait => _('Please wait…', 'একটু অপেক্ষা করুন…');
  String get haveAccount =>
      _('Already have an account? Sign in', 'অ্যাকাউন্ট আছে? সাইন ইন করুন');
  String get newHere =>
      _('New here? Create an account', 'নতুন? অ্যাকাউন্ট তৈরি করুন');
  String get required => _('Required', 'আবশ্যক');
  String get enterValidEmail =>
      _('Enter a valid email', 'সঠিক ইমেইল দিন');
  String get tooShort => _('Too short', 'খুব ছোট');

  // Booking
  String get bookATaxi => _('Book a taxi', 'ট্যাক্সি বুক করুন');
  String get pickupAddress => _('Pickup address', 'যেখান থেকে উঠবেন');
  String get dropoffAddress => _('Dropoff address', 'যেখানে নামবেন');
  String get useCurrentLocation =>
      _('Use current location', 'বর্তমান অবস্থান নিন');
  String get getFareEstimate => _('Get fare estimate', 'ভাড়ার ধারণা নিন');
  String get requestTaxi => _('Request taxi', 'ট্যাক্সি ডাকুন');
  String get estimatedFare => _('Estimated fare', 'আনুমানিক ভাড়া');
  String get finalFare => _('Final fare', 'চূড়ান্ত ভাড়া');
  String get calculating => _('Calculating…', 'হিসাব হচ্ছে…');
  String get enterBothAddresses =>
      _('Enter both pickup and dropoff.', 'ওঠা ও নামার ঠিকানা দুটোই দিন।');
  String get couldNotEstimate => _(
        'Could not get a fare estimate. Check the addresses and try again.',
        'ভাড়ার হিসাব পাওয়া যায়নি। ঠিকানা দেখে আবার চেষ্টা করুন।',
      );
  String get couldNotRequest => _(
        'Could not request a ride. Please try again.',
        'যাত্রার অনুরোধ পাঠানো যায়নি। আবার চেষ্টা করুন।',
      );
  String get rideInProgress =>
      _('You have a ride in progress', 'আপনার একটি যাত্রা চলছে');

  // Ride status
  String get yourRide => _('Your ride', 'আপনার যাত্রা');
  String get findingDriver =>
      _('Finding you a driver…', 'ড্রাইভার খোঁজা হচ্ছে…');
  String get driverOnWay => _('Driver is on the way', 'ড্রাইভার আসছেন');
  String get driverArrived =>
      _('Your driver has arrived', 'ড্রাইভার পৌঁছে গেছেন');
  String get tripInProgress => _('Trip in progress', 'যাত্রা চলছে');
  String get tripCompleted => _('Trip completed', 'যাত্রা শেষ');
  String get rideCancelled => _('Ride cancelled', 'যাত্রা বাতিল');
  String get noDriversFound =>
      _('No drivers found', 'কোনো ড্রাইভার পাওয়া যায়নি');
  String get callDriver => _('Call driver', 'ড্রাইভারকে ফোন করুন');
  String get cancelRide => _('Cancel ride', 'যাত্রা বাতিল করুন');
  String get done => _('Done', 'সম্পন্ন');

  // Payment
  String get cancelRideQuestion =>
      _('Cancel this ride?', 'এই যাত্রা বাতিল করবেন?');
  String get keepRide => _('Keep ride', 'যাত্রা রাখুন');
  String get cancelFree => _(
        'You can cancel this one free of charge.',
        'এই যাত্রাটি বিনা খরচে বাতিল করতে পারবেন।',
      );
  String cancelFeeWarning(String fee) => _(
        'Your driver is already on the way, so cancelling now costs $fee.',
        'আপনার ড্রাইভার ইতিমধ্যেই রওনা দিয়েছেন, তাই এখন বাতিল করলে $fee লাগবে।',
      );
  String get cancellationFee => _('Cancellation fee', 'বাতিলের ফি');
  String get cancellationFeeExplained => _(
        'Your driver had already set off, so this fee goes to them for the '
            'journey out.',
        'ড্রাইভার আগেই রওনা দিয়েছিলেন, তাই এই ফি তাঁর যাতায়াতের জন্য '
            'তাঁকেই দেওয়া হয়।',
      );
  String get payYourFare => _('Pay your fare', 'ভাড়া পরিশোধ করুন');
  String get payByCardOrCash => _(
        'Pay securely by card, or settle in cash with your driver.',
        'কার্ডে নিরাপদে দিন, অথবা ড্রাইভারকে নগদে দিন।',
      );
  String get paymentFailed => _(
        'That payment did not go through. Try again or pay in cash.',
        'পেমেন্ট হয়নি। আবার চেষ্টা করুন বা নগদে দিন।',
      );
  String get cardUnavailable => _(
        'Card payment unavailable — please pay in cash.',
        'কার্ডে পেমেন্ট সম্ভব নয় — অনুগ্রহ করে নগদে দিন।',
      );
  String get opening => _('Opening…', 'খোলা হচ্ছে…');
  String payByCard(String amount) =>
      _('Pay $amount by card', '$amount কার্ডে দিন');
  String paidAmount(String amount) => _('Paid — $amount', 'পরিশোধিত — $amount');

  // Rating
  String get rateYourDriver =>
      _('Rate your driver', 'ড্রাইভারকে রেটিং দিন');
  String get submitRating => _('Submit rating', 'রেটিং জমা দিন');
  String get saving => _('Saving…', 'জমা হচ্ছে…');
  String get ratingFailed => _(
        'Could not save your rating. Please try again.',
        'রেটিং জমা হয়নি। আবার চেষ্টা করুন।',
      );
  String ratedTrip(int stars) =>
      _('You rated this trip $stars ⭐', 'আপনি $stars ⭐ দিয়েছেন');

  // History
  String get rideHistory => _('Ride history', 'যাত্রার ইতিহাস');
  String get noRidesYet => _('No rides yet.', 'এখনো কোনো যাত্রা নেই।');

  // Errors
  String get somethingWentWrong => _(
        'Something went wrong. Try again.',
        'কিছু একটা সমস্যা হয়েছে। আবার চেষ্টা করুন।',
      );
  String get accountSuspended => _(
        'Your account has been suspended.',
        'আপনার অ্যাকাউন্ট স্থগিত করা হয়েছে।',
      );
  String get emailInUse => _(
        'This email is already registered.',
        'এই ইমেইল দিয়ে আগেই নিবন্ধন হয়েছে।',
      );
  String get weakPassword =>
      _('Password is too weak.', 'পাসওয়ার্ডটি দুর্বল।');
  String get signInFailed => _(
        'Sign-in failed. Check your details.',
        'সাইন ইন হয়নি। তথ্য যাচাই করুন।',
      );
}
