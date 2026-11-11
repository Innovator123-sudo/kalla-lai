/// Non-web platforms let the intro start with sound, so there is nothing to
/// wait for; this exists only so the conditional import resolves everywhere.
void Function() onUserGesture(void Function() callback) => () {};
