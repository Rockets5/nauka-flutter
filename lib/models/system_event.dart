/// Rodzaj zdarzenia niesiony przez wiadomość systemową z backendu
/// (pole `event` w JSON-ie).
///
/// Odpowiednik backendowego `SystemEvent` z Pydantic (patrz
/// `app/models/message.py`). To jest "sygnał dla maszyny" - UI
/// przełącza na jego podstawie stan rozmowy, zamiast parsować polski
/// tekst przeznaczony dla człowieka. Dzięki temu poprawka literówki
/// albo tłumaczenie interfejsu niczego nie psuje.
///
/// To jest "enhanced enum" - enum z własnym polem ([wire]) i metodą
/// ([fromWire]). Potrzebne, bo backend serializuje warianty w
/// snake_case ("partner_disconnected"), a konwencja Darta to
/// camelCase (partnerDisconnected) - nie da się ich mapować
/// automatycznie po nazwie.
enum SystemEvent {
  waiting('waiting'),
  paired('paired'),
  partnerDisconnected('partner_disconnected'),
  partnerReconnected('partner_reconnected'),
  partnerLeft('partner_left');

  /// Nazwa tego wariantu tak, jak przychodzi w JSON-ie z backendu.
  final String wire;

  const SystemEvent(this.wire);

  /// Zamienia surową wartość z JSON-a na wariant enuma.
  ///
  /// Zwraca `null` dla brakującej albo nieznanej wartości:
  /// - zwykłe wiadomości od użytkowników nie mają pola `event`,
  /// - nowsza wersja backendu mogłaby dodać event, którego ta
  ///   wersja apki jeszcze nie zna - lepiej go zignorować niż
  ///   wywrócić całą aplikację.
  static SystemEvent? fromWire(String? raw) {
    for (final event in values) {
      if (event.wire == raw) return event;
    }
    return null;
  }
}
