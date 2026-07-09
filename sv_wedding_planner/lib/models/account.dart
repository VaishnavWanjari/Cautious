/// The user's connected-account state. Connecting a Google/Gmail account gates
/// the AI Copilot and unlocks live, online-fetched suggestions.
///
/// This is a lightweight local representation. Wiring real Google OAuth
/// (`google_sign_in` + a backend token exchange) only needs to populate
/// [connected] and [email] here — the rest of the app reads this state.
class AccountState {
  final bool connected;
  final String email;

  const AccountState({this.connected = false, this.email = ''});

  AccountState copyWith({bool? connected, String? email}) => AccountState(
        connected: connected ?? this.connected,
        email: email ?? this.email,
      );
}
