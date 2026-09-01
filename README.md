# Chat App

Docelowo: całkowicie anonimowy czat, w którym system sam losowo
dobiera rozmówcę (1-na-1), z rejestracją samym hasłem (bez loginu).
Budowany etapami - obecny stan poniżej.

## Architektura

Backend i frontend to dwa osobne, niepowiązane ze sobą projekty,
komunikujące się wyłącznie przez WebSocket.

| Warstwa                              | Backend (`nauka-fastapi/app/`) | Frontend (`app0/lib/`) |
|---------------------------------------|--------------------------------|-----------------------------------|
| Adresy / co użytkownik "odwiedza"     | `routers/`                     | `screens/`                        |
| Logika (co się dzieje w środku)       | `services/`                    | `services/`                       |
| Kształt danych                        | `models/`                      | `models/`                         |

## Backend

```bash
cd nauka-fastapi
python -m venv venv
source venv/bin/activate      # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```

Serwer nasłuchuje na `ws://localhost:8000/ws/{username}`.

## Frontend

```bash
cd app0
flutter pub get
flutter run
```

**Uwaga na adres serwera** (`lib/services/chat_service.dart`,
metoda `connect()`):
- Emulator Android: `ws://10.0.2.2:8000/...` (aktualnie ustawione)
- Chrome / Windows desktop / prawdziwe urządzenie w tej samej sieci:
  zamień `10.0.2.2` na `localhost` albo adres IP komputera z
  uruchomionym backendem.

## Stan backendu (etap 1: matchmaking - PRZETESTOWANY, bugi naprawione)

Backend przeszedł z modelu "1 wspólny czat, broadcast do
wszystkich" na model "matchmaking 1-na-1, izolowane pokoje":

- **Poczekalnia** (`waiting_room`): nowy użytkownik bez pary trafia
  tutaj i czeka.
- **Parowanie** (`_match_or_wait`): gdy ktoś już czeka, nowy
  użytkownik zostaje z nim sparowany; oboje dostają wiadomość
  systemową o połączeniu. Wydzielone jako osobna metoda, bo ta
  sama logika jest potrzebna zarówno przy nowym połączeniu, jak i
  gdy partner zostaje "uwolniony" po ostatecznym zamknięciu pokoju.
- **Izolacja**: wiadomości trafiają WYŁĄCZNIE do przypisanego
  partnera (`send_personal_message`), nie do wszystkich - potwierdzone
  testem z trzecią osobą w poczekalni, która niczego nie odbiera.
- **Grace period reconnect**: rozłączenie nie kończy rozmowy od
  razu - partner dostaje ostrzeżenie, a rozłączony ma 60s na
  powrót pod tym samym username. Jeśli wróci, pokój jest
  wznawiany (z nowym obiektem WebSocket) bez utraty rozmowy. Jeśli
  nie wróci, pokój zostaje ostatecznie zamknięty, partner
  powiadomiony, i WRACA do matchmakingu (nie zostaje "zawieszony").

Cały ten scenariusz (parowanie, izolacja, rozłączenie, powrót w
oknie 60s, dalsza wymiana wiadomości bez duplikatów) został ręcznie
przetestowany przez wtyczkę przeglądarki do WebSocket, na 3-4
użytkownikach naraz.

**Bugi napotkane i naprawione po drodze** (warto znać, jeśli
rozbudowujesz ten kod dalej):
1. Wpis w `disconnect_tasks` nie był usuwany po naturalnym
   wygaśnięciu grace period (tylko przy reconnect) - kolejne
   połączenie tego username błędnie trafiało w gałąź reconnectu
   mimo braku pokoju → `KeyError`. Naprawione przez `finally` z
   `disconnect_tasks.pop(username, None)`.
2. Wysłanie wiadomości do partnera, który stracił połączenie (ale
   jego grace period jeszcze trwa), rzucało wyjątek, który wylatywał
   aż do pętli w `chat.py` i błędnie kończył połączenie NADAWCY, nie
   martwego partnera. Naprawione przez `try/except` wokół
   `partner_ws.send_text(...)` w `send_personal_message`.
3. Partner pozostawał "zawieszony" (bez wpisu w `rooms` ani
   `waiting_room`) po ostatecznym zamknięciu pokoju - nigdy nie
   mógł zostać sparowany ponownie. Naprawione przez wywołanie
   `_match_or_wait` dla uwolnionego partnera, WYŁĄCZNIE w gałęzi
   naturalnego wygaśnięcia (nie w `finally`, bo to uruchamiałoby
   się też przy udanym reconnect i niszczyło poprawnie odbudowaną
   parę).

**Ważna zasada:** frontend wysyła do serwera WYŁĄCZNIE surowy
tekst wiadomości - backend sam zna nadawcę (ma go z URL,
`/ws/{username}`) i sam skleja pełną wiadomość (`Message`) przed
wysłaniem jej do partnera.

## Stan frontendu (NIEZSYNCHRONIZOWANY z nowym backendem)

Frontend (`app0/lib/`) wciąż jest zbudowany pod **stary**
model backendu (1 wspólny czat, wszyscy widzą wszystkich) i **nie
działa poprawnie** z obecnym backendem matchmakingowym - to
kolejny krok do zrobienia. W szczególności:

- `ChatService` ma własny mechanizm reconnectu (exponential
  backoff), niezależny od grace period backendu - te dwa
  mechanizmy nie są ze sobą zestrojone i prawdopodobnie się gryzą
  (do zweryfikowania).
- UI (`chat_screen.dart`) nie ma pojęcia o stanach "czekam na
  rozmówcę" / "jestem w parze" / "rozmówca odszedł, dobierz
  nowego" - pokazuje tylko płaską listę wiadomości.
- Przycisk "wyślij" ma docelowo zamieniać się w "dobierz
  rozmówcę" po zakończeniu rozmowy - jeszcze niezaimplementowane.

## Do zrobienia (kolejne etapy)

1. **[W TRAKCIE]** Zsynchronizować frontend z nowym backendem
   matchmakingowym (rozpoznawanie stanów rozmowy, przycisk "dobierz
   rozmówcę").
2. Ekran logowania (obecnie `username` jest na sztywno wpisane
   w `lib/main.dart`).
3. Rejestracja/logowanie samym hasłem (baza danych, hashowanie,
   sesje/tokeny) - docelowa, w pełni anonimowa tożsamość konta.