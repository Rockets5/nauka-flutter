/// Stan rozmowy z punktu widzenia interfejsu - na jakim etapie
/// matchmakingu jest użytkownik.
///
/// To jest OSOBNA oś od stanu połączenia (socket żyje / łączę
/// ponownie / poddałem się). Obie są niezależne: można być `paired`
/// i jednocześnie mieć chwilową przerwę w połączeniu.
///
/// [ChatService] wylicza ten stan z wiadomości systemowych
/// przychodzących z backendu (pole `event`, patrz [SystemEvent])
/// i wystawia go jako `Stream<ConversationState>`. Ekran tylko
/// renderuje - nie parsuje sam żadnych tekstów.
enum ConversationState {
  /// Czekam w poczekalni na dobranie rozmówcy.
  waiting,

  /// Rozmawiam z przydzielonym rozmówcą.
  paired,

  /// Rozmówca chwilowo stracił połączenie - trwa grace period
  /// (60s po stronie backendu), może jeszcze wrócić. Wciąż
  /// "jestem w parze", tylko rozmówca teraz milczy.
  partnerAway,

  /// Rozmówca odszedł na dobre (nacisnął "następny" albo nie
  /// wrócił w oknie grace period). Trzeba nacisnąć "dobierz
  /// rozmówcę", żeby wejść w kolejne parowanie.
  partnerLeft,
}
