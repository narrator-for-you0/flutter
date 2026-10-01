/// The rotating tip copy behind the Saving Tips and Campus Budget Tips cards.
///
/// Both cards show exactly one tip per day. The day is the only state — there is
/// no shuffle and nothing persisted — so opening the app twice in one day always
/// shows the same tip, and a new one appears at local midnight without the app
/// needing to know anything happened.
///
/// The pools are long enough (12 each) that the same tip doesn't come back
/// within the cycle, which is the whole point: a tip you read this morning
/// should still feel fresh next week.
///
/// The peso figures in [body] are deliberately plain strings like `₱40/day`.
/// They're authored prose, not computed amounts, so they don't go through
/// `formatPeso` — that helper is for numbers the app calculates.
library;

/// One tip: [title] is the bold lead-in, [body] finishes the sentence.
/// The colon between them is added by the widget, not stored here.
class Tip {
  final String title;
  final String body;

  const Tip(this.title, this.body);

  @override
  String toString() => 'Tip($title)';
}

/// Anchor for the rotation. Any fixed date works; this one is arbitrary and only
/// matters in that it never moves.
final DateTime _epoch = DateTime.utc(2024, 1, 1);

/// Days between [day] and the epoch, in UTC so a daylight-saving jump can't
/// shift the count by one and make the tip change a few hours early or late.
int _daysSinceEpoch(DateTime day) {
  final utc = DateTime.utc(day.year, day.month, day.day);
  return utc.difference(_epoch).inDays;
}

/// Which entry of a [length]-long pool [day] lands on.
///
/// Built on days-since-epoch rather than `DateTime.weekday` on purpose:
/// `weekday` only has 7 values, so with 12 tips, five of them could never be
/// shown. This also guarantees the index advances by exactly one per day and
/// wraps, whatever the pool length.
///
/// [offset] shifts the starting point so two cards sharing this pool size don't
/// show the same tip on the same day.
int dayIndex(DateTime day, int length, {int offset = 0}) {
  if (length <= 0) {
    throw ArgumentError.value(length, 'length', 'must be greater than zero');
  }
  final raw = (_daysSinceEpoch(day) + offset) % length;
  // Dart's % can return a negative value for a negative dividend; dates before
  // the epoch would otherwise index off the front of the list.
  return raw < 0 ? raw + length : raw;
}

/// The tip a card should show on [now].
///
/// When [isUrgent] is true the date picks from [urgent] instead of [pool], so
/// someone who is nearly out of money gets advice about that situation rather
/// than a cheerful line about meal prepping. The urgent pool rotates daily too,
/// so they don't see the same warning twice running.
///
/// Falls back to [pool] if [urgent] is empty, so a card without a warning set
/// still works.
Tip pickTip({
  required List<Tip> pool,
  required List<Tip> urgent,
  required DateTime now,
  required bool isUrgent,
  int offset = 0,
}) {
  final source = isUrgent && urgent.isNotEmpty ? urgent : pool;
  return source[dayIndex(now, source.length, offset: offset)];
}

/// Fraction of the budget at which the tip cards switch to urgent advice.
///
/// Deliberately above the 75% mark where the Budget screen already shows its
/// own `CAUTION` banner, so a user near the limit doesn't get warned by two
/// things at once.
const double kUrgentBudgetFraction = 0.9;

/// Whether [spent] against [budget] is tight enough to swap in an urgent tip.
///
/// False when there's no budget set — nagging someone who hasn't budgeted yet
/// would be meaningless, and the app treats a zero budget as "not tracking".
bool isBudgetUrgent({required double spent, required double budget}) {
  if (budget <= 0) return false;
  if (spent >= budget) return true;
  return spent / budget >= kUrgentBudgetFraction;
}

// ---------------------------------------------------------------------------
// Copy
// ---------------------------------------------------------------------------

/// Shown on Home. Money management rather than where to eat cheap — the campus
/// card covers that. Starts with the original tumbler tip.
const List<Tip> savingTips = [
  Tip(
    'Refill, don\'t repurchase',
    'A refillable tumbler saves up to ₱40/day on bottled drinks — over ₱1,200 a '
        'month.',
  ),
  Tip(
    'Pockets, not plans',
    'Split your allowance into a daily pocket the moment you get paid, then spend '
        'from one pocket a day.',
  ),
  Tip(
    'Two no-spend days a week',
    'Two days without any purchases is roughly ₱400 saved a month without '
        'skipping a single meal.',
  ),
  Tip(
    'Save before you spend',
    'Move savings out first and treat what\'s left as this month\'s money. What '
        'you never hand yourself is the easiest to not spend.',
  ),
  Tip(
    'Stack your QR rewards',
    'GCash and Maya cashback is worth more when you pay by QR than by cash — take '
        'whichever voucher is bigger.',
  ),
  Tip(
    'Watch the minimum',
    'A ₱40 fee on a ₱150 order is a 27% markup. Small orders plus delivery fees '
        'quietly cost more than the food.',
  ),
  Tip(
    'One grocery run a week',
    'Buying for the week at one store beats seven small convenience store stops, '
        'where prices are higher and impulse buys hide.',
  ),
  Tip(
    'Free before paid',
    'Campus Wi-Fi, the library, and free student hours cover study and '
        'entertainment before anything needs paying for.',
  ),
  Tip(
    'Cancel what you rarely use',
    'If you\'d cancel it today without thinking, cancel it now — you\'re only '
        'saving money if you actually let it go.',
  ),
  Tip(
    'Set a weekly ceiling',
    'Budget ÷ 4.3 is a realistic week. Staying under it beats trying to save the '
        'whole amount at month end.',
  ),
  Tip(
    'Pay cash for what you regret',
    'The one-tap problem is the whole problem. Physical cash makes an impulse '
        'cost a trip to the ATM.',
  ),
  Tip(
    'Leftovers are tomorrow\'s meal',
    'Extra spaghetti from dinner becomes baon the next day, which is one meal you '
        'get to skip buying.',
  ),
];

/// Advice for someone at or near their ceiling. Reads as a way forward, not a
/// scolding, since it interrupts whatever else they were reading.
const List<Tip> savingUrgentTips = [
  Tip(
    'Pause what isn\'t food',
    'Subscriptions, deliveries, and non-essentials can wait — keep the budget '
        'for meals and cut the rest this period.',
  ),
  Tip(
    'Move some out now',
    'If anything is still in savings, move what you can today. The period is '
        'already decided; new spending only makes it worse.',
  ),
  Tip(
    'Plan the next three meals',
    'Deciding tonight what you\'ll eat tomorrow stops a "just this once" purchase '
        'from becoming the pattern.',
  ),
];

/// Shown on the Budget tab. Eating and living cheaper around campus specifically.
/// Starts with the three tips that were already hardcoded on that card.
const List<Tip> campusTips = [
  Tip(
    'Silog & canteen combos',
    'Pair a rice plate with water instead of a bottled drink and lunch stays '
        'under ₱100.',
  ),
  Tip(
    'Student canteen QR promos',
    'Check the canteen QR for 5–10% vouchers — student discounts stack with '
        'regular promos more often than you\'d think.',
  ),
  Tip(
    'Merienda limit',
    'Cap mid-afternoon milk tea or snacks at 3 times a week. That\'s where '
        'untracked spending actually goes.',
  ),
  Tip(
    'Eat off-peak',
    'The rush-hour surcharge usually lifts an hour after peak. Waiting costs '
        'nothing but patience.',
  ),
  Tip(
    'Carinderia by the kilo',
    'Kilo rates are almost always cheaper per plate than a la carte, and two '
        'people can share one order.',
  ),
  Tip(
    'Palayok nights',
    'Buffet-style rice meals run cheaper than anything on the regular menu. '
        'Check whether your favourite place has one.',
  ),
  Tip(
    'Share the dorm fridge',
    'A shelf each, a shared restock, and a rule about labelling food — it\'s the '
        'cheapest kitchen on campus.',
  ),
  Tip(
    'Print in bulk or don\'t print',
    'Per-page pricing punishes small jobs. Printing a whole set at once is '
        'materially cheaper than the same pages one at a time.',
  ),
  Tip(
    'Bring your own tupperware',
    'Leftovers at campus food prices stop being leftovers. One container pays '
        'for itself after a couple of days.',
  ),
  Tip(
    'Group order once a week',
    'One person queues, everyone eats cheaper, and you all get home on time. '
        'It\'s faster than three separate canteen runs.',
  ),
  Tip(
    'Loaded is cheaper than bottled',
    'A personal load usually costs less per litre than buying bottled water '
        'daily, and it skips the plastic too.',
  ),
  Tip(
    'Plan around discount day',
    'If somewhere you like has a discount day, that\'s the day to eat there. '
        'Same food, lower cost, no willpower needed.',
  ),
];

/// Campus-specific advice for the tight end of the budget cycle.
const List<Tip> campusUrgentTips = [
  Tip(
    'Default to the cheapest meal',
    'Silog combo, canteen rice meal, or a carinderia plate — decide this in the '
        'morning so the choice isn\'t made while hungry.',
  ),
  Tip(
    'Cook once this week',
    'A single batch-cooked meal you can portion out beats several unplanned '
        'canteen buys.',
  ),
  Tip(
    'Pack tomorrow\'s baon tonight',
    'Anything already in a container is already paid for. The decision was made '
        'when you still had budget.',
  ),
];
