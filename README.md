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

Działa: połączenie, wysyłanie i odbieranie wiadomości (wyświetlana
jest aktualnie tylko najnowsza wiadomość - `Stream` sam z siebie
nie pamięta historii).

Do zrobienia:
- Rosnąca lista wiadomości (`.listen()` + `setState` +
  `ListView.builder` zamiast samego `StreamBuilder`).
- Ekran logowania (obecnie `username` jest na sztywno wpisane
  w `lib/main.dart`).
- Obsługa `snapshot.hasError` w UI (obecnie błąd połączenia
  pokazuje się tylko jako nieskończone ładowanie, bez komunikatu).
