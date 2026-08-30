# Chat App

Prosty czat na żywo: backend FastAPI (WebSocket) + frontend Flutter.

## Architektura

Backend i frontend to dwa osobne, niepowiązane ze sobą projekty,
komunikujące się wyłącznie przez WebSocket. Oba stosują ten sam
podział odpowiedzialności:

| Warstwa                              | Backend (`chat_backend/app/`) | Frontend (`chat_frontend/lib/`) |
|---------------------------------------|--------------------------------|-----------------------------------|
| Adresy / co użytkownik "odwiedza"     | `routers/`                     | `screens/`                        |
| Logika (co się dzieje w środku)       | `services/`                    | `services/`                       |
| Kształt danych                        | `models/`                      | `models/`                         |

## Backend

```bash
cd chat_backend
python -m venv venv
source venv/bin/activate      # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```

Serwer nasłuchuje na `ws://localhost:8000/ws/{username}`.

## Frontend

```bash
cd chat_frontend
flutter pub get
flutter run
```

**Uwaga na adres serwera** (`lib/services/chat_service.dart`,
metoda `connect()`):
- Emulator Android: `ws://10.0.2.2:8000/...` (aktualnie ustawione)
- Chrome / Windows desktop / prawdziwe urządzenie w tej samej sieci:
  zamień `10.0.2.2` na `localhost` albo adres IP komputera z
  uruchomionym backendem.

## Stan projektu

Działa:
- Połączenie, wysyłanie i odbieranie wiadomości, z pełną,
  rosnącą historią.
- Wiadomości systemowe: gdy użytkownik się rozłączy, backend
  rozsyła do pozostałych informację o tym fakcie (wyświetlaną
  na froncie inaczej niż zwykłe wiadomości).
- Obsługa utraty połączenia: frontend rozróżnia błąd połączenia
  (`onError`) od jego zamknięcia (`onDone`) i pokazuje stosowny
  komunikat zamiast ciszy / wiecznego ładowania.

Ważna zasada, na którą warto uważać przy rozbudowie: frontend
(`ChatService.sendMessage`) wysyła do serwera WYŁĄCZNIE surowy
tekst wiadomości, bez pakowania w JSON z polem `user` - backend
sam już zna nazwę użytkownika (ma ją z adresu URL,
`/ws/{username}`) i to on skleja pełną wiadomość przed
rozesłaniem. Wysłanie gotowego JSON-a z frontendu spowodowałoby,
że backend potraktowałby go jako zwykły tekst i zagnieździłby go
wewnątrz kolejnego pola `text`.

Do zrobienia:
- Ekran logowania (obecnie `username` jest na sztywno wpisane
  w `lib/main.dart`).
- Ponowne łączenie (reconnect) po utracie połączenia - obecnie
  `_connectionError` ustawia się raz i na stałe, bez prób
  automatycznego ponownego połączenia.
- Adres serwera w `chat_service.dart` jest na sztywno ustawiony
  na `10.0.2.2` (adres wymagany na emulatorze Androida) - na
  innych platformach (web, desktop, prawdziwe urządzenie) trzeba
  go tymczasowo zmieniać ręcznie; docelowo warto to zautomatyzować.