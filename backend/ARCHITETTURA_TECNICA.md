# Zero Messaggi Persi — Architettura Tecnica e Analisi di Fattibilità

> Analisi del progetto (sito `zero_messaggi_persi` + dashboard `zero-dashboard`) e
> progettazione del sistema tecnico ottimale: ingestione prenotazioni multi-canale →
> database → messaggi WhatsApp automatici dal post-prenotazione alla richiesta recensione.

---

## 1. Stato attuale del progetto

| Componente | Tecnologia | Stato |
|---|---|---|
| Sito marketing | HTML statico (Netlify) | Funzionante |
| Dashboard operativa | Next.js + Supabase Auth (Vercel) | Pagine pronte, dati parzialmente mock |
| Database | Supabase (PostgreSQL + RLS + Realtime) | **Due schemi divergenti** (vedi §5.1) |
| Automazioni | n8n (workflow D1–D5) | Workflow D5 presente nel repo |
| Messaggistica | WhatsApp Cloud API (Meta) | Template-based, multi-numero per struttura |

L'impianto generale è corretto: Supabase come fonte unica di verità, n8n come motore
di automazione, WhatsApp Cloud API per l'invio. I problemi sono nei dettagli (schema,
scheduling, multi-tenancy, ingestione OTA) — analizzati sotto.

---

## 2. Architettura di riferimento

```
┌─────────────── INGESTIONE PRENOTAZIONI ───────────────┐
│                                                        │
│  Email dirette ──► n8n (IMAP trigger) ──► AI parsing ─┐│
│  Booking.com  ──► email conferma host ──► AI parsing ─┤│
│  Channel Mgr  ──► webhook (Smoobu/Beds24/Lodgify) ────┤│
│  PMS          ──► webhook / polling API ──────────────┤│
│  Airbnb       ──► (vedi §4.3 — via CM o form ospite) ─┤│
│  Inserimento manuale ──► Dashboard (form) ────────────┤│
│                                                       ││
└───────────────────────────────────────────────────────┘│
                                                          ▼
                              ┌────────────────────────────────────┐
                              │  SUPABASE — tabella bookings       │
                              │  (stato: da_confermare/confermata) │
                              └───────────────┬────────────────────┘
                                              │ trigger/insert
                                              ▼
                              ┌────────────────────────────────────┐
                              │  scheduled_messages                │
                              │  (un record per ogni messaggio     │
                              │   futuro: D1…D5, con send_at)      │
                              └───────────────┬────────────────────┘
                                              │ cron n8n ogni 10 min
                                              ▼
                              ┌────────────────────────────────────┐
                              │  DISPATCHER n8n                    │
                              │  - prende i messaggi scaduti       │
                              │  - invia template WhatsApp         │
                              │  - aggiorna status/retry           │
                              └───────────────┬────────────────────┘
                                              ▼
                                    WhatsApp Cloud API (Meta)
                                              │
                            webhook inbound ◄─┘
                                              ▼
                          messages/conversations (dashboard inbox,
                          flag problema_segnalato → blocca recensione)
```

### Sequenza messaggi (per prenotazione)
| Step | Quando | Tipo |
|---|---|---|
| D1 Conferma/benvenuto | subito dopo ingestione (se telefono noto) | template `utility` |
| D2 Pre check-in (istruzioni, codici, wifi) | T−1 giorno dal check-in | template `utility` |
| D3 Follow-up "tutto ok?" | T+1 dal check-in | template `utility` |
| D4 Pre check-out (istruzioni uscita) | T−1 dal check-out | template `utility` |
| D5 Richiesta recensione | T+1 dal check-out, **solo se** `problema_segnalato = false` | template `marketing/utility` |

---

## 3. Decisione chiave: tabella `scheduled_messages` al posto dei flag

**Problema attuale:** i workflow D1–D5 usano cron giornalieri + flag booleani
(`welcome_sent`, `review_sent`, `followup_sent`) con query del tipo
"check-in = ieri AND flag = false". È fragile:

1. Se n8n è giù il giorno X, la query del giorno X+1 non matcha più → **messaggio perso per sempre**.
2. Ogni nuovo messaggio richiede una colonna flag + un workflow nuovo.
3. Le date sono calcolate in UTC nel codice JS (`new Date().toISOString()`) → errori di fuso orario (l'Italia è UTC+1/+2: una prenotazione può risultare "ieri" o "oggi" a seconda dell'ora).

**Soluzione:** alla creazione della prenotazione, un trigger Postgres (o il workflow di
ingestione) genera N righe in `scheduled_messages`:

```sql
CREATE TABLE scheduled_messages (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id    uuid REFERENCES bookings(id) ON DELETE CASCADE,
  message_type  text NOT NULL,          -- 'benvenuto' | 'pre_checkin' | 'followup' | 'pre_checkout' | 'recensione'
  send_at       timestamptz NOT NULL,   -- calcolato con fuso 'Europe/Rome'
  status        text NOT NULL DEFAULT 'pending', -- pending | sent | failed | skipped | cancelled
  attempts      int DEFAULT 0,
  last_error    text,
  sent_at       timestamptz
);
CREATE INDEX idx_sched_due ON scheduled_messages (status, send_at);
```

Un **unico workflow dispatcher** n8n (cron ogni 10 minuti) fa:
`SELECT ... WHERE status='pending' AND send_at <= now()` → invia → marca `sent` o
incrementa `attempts` (max 3, poi `failed` + notifica al gestore). Vantaggi:

- **Recupero automatico**: se n8n era giù, al riavvio i messaggi scaduti partono comunque.
- **Idempotenza e retry** integrati.
- Cancellazione prenotazione → `cancelled` su tutti i pending (gestita dal webhook del CM).
- La logica "salta recensione se problema segnalato" è un semplice check al momento dell'invio.
- Un solo workflow da mantenere invece di 5.

---

## 4. Ingestione per canale: fattibilità e soluzioni

### 4.1 Email di clienti privati (prenotazioni dirette) — ✅ FATTIBILE
- n8n **IMAP/Gmail trigger** sulla casella del gestore (o un alias dedicato tipo
  `prenotazioni@struttura.it` inoltrato a una casella centrale).
- Parsing con **LLM** (Claude Haiku: costo trascurabile) → estrae nome, telefono, date,
  n. ospiti in JSON strutturato.
- **Punto critico:** il parsing AI può sbagliare (date ambigue, email in lingue diverse,
  email che non sono prenotazioni). **Soluzione:** la prenotazione entra con stato
  `da_confermare`; la dashboard mostra una coda di revisione e il gestore conferma con
  un click (o via messaggio WhatsApp al gestore stesso). Nessun messaggio parte prima
  della conferma. Dopo qualche settimana di fiducia si può attivare l'auto-conferma
  per i casi ad alta confidenza.

### 4.2 Booking.com — ⚠️ FATTIBILE CON WORKAROUND
- **API ufficiale (Connectivity Partner): non realisticamente accessibile.** Booking
  richiede certificazione come partner di connettività con requisiti (volumi, audit)
  fuori portata per una startup al lancio. *Non risolvibile per via diretta.*
- **Soluzione A (consigliata): passare da un channel manager** già certificato (§4.4).
- **Soluzione B: parsing delle email** che Booking invia al gestore.
- **Punto critico (VERIFICATO sulle email reali, giu 2026):** la notifica standard di
  Booking è **minimale**: contiene solo n. prenotazione, struttura e data di arrivo
  (nell'oggetto) + link all'extranet. **Niente nome, telefono, né data di partenza.**
  Gestione implementata: la prenotazione entra in dashboard con stato
  **`da_completare`** (nessun messaggio parte); il gestore apre il link extranet
  contenuto nell'email, copia telefono/nome/partenza (1 minuto) e porta lo stato a
  `confermata` → la sequenza si genera da sola. Possibili miglioramenti:
  1) attivare nell'extranet le **email di prenotazione dettagliate** (Account →
  Notifiche email), se disponibili per la struttura: contengono nome e spesso telefono;
  2) channel manager (risolve alla radice).
- Anche col telefono, alcuni numeri Booking sono errati. Fallback: messaggio via
  canale Booking con link al form di web check-in che raccoglie il numero WhatsApp.

### 4.3 Airbnb — ✅ FATTIBILE via "messaggio programmato + email" (flusso a 2 email)
Premesse:
- **Airbnb non ha API pubblica** (accesso solo per partner approvati — non ottenibile).
- Prima della conferma Airbnb maschera i contatti; **dopo la conferma** lo scambio di
  numeri di telefono in chat è consentito e non viene censurato.
- **Il feed iCal** di Airbnb dà solo le date (e un codice prenotazione), nessun contatto.

**Flusso operativo (senza channel manager):**
1. Il gestore configura su Airbnb un **messaggio programmato** (funzione nativa di
   Airbnb, gratuita) che parte automaticamente alla conferma della prenotazione:
   *"Benvenuto! Per inviarti le istruzioni di check-in su WhatsApp, rispondi con il
   tuo numero di telefono"* (in alternativa: link al form di web check-in).
2. **Email #1 — conferma prenotazione**: Airbnb la invia al gestore. n8n la
   intercetta (inoltro automatico verso la casella di ingestione, §4.7) → AI parsing →
   crea la prenotazione in `bookings` con stato `telefono_mancante`
   (chiave: `booking_source='airbnb'` + `booking_ref` = codice prenotazione).
3. L'ospite risponde in chat Airbnb col numero. **Email #2 — notifica messaggio**:
   Airbnb invia al gestore l'email con il testo della risposta. n8n la intercetta →
   estrae il numero (LLM + validazione `libphonenumber`) → **aggiorna (upsert) la
   prenotazione esistente** abbinandola per codice prenotazione/nome ospite →
   genera le righe `scheduled_messages` per i passi rimanenti.
4. Da qui la sequenza WhatsApp procede normalmente. Il consenso (opt-in, §6.2) è
   implicito e pulito: è l'ospite stesso che fornisce il numero per essere contattato.

**Requisito di progettazione che ne deriva (vale per tutti i canali): l'ingestione è
sempre un UPSERT.** Ogni prenotazione può arrivare in più momenti e arricchirsi:
prima i dati base, poi il telefono, poi eventuali modifiche di date o cancellazioni.
Chiave naturale di deduplica: `(booking_source, booking_ref)`; in mancanza di ref,
matching su struttura + nome ospite + date. Ad ogni update: ricalcolo di `send_at`
sui messaggi pending (date cambiate) o `cancelled` (prenotazione annullata).

**Punti critici:**
- Se l'ospite non risponde col numero → reminder automatico in chat Airbnb (secondo
  messaggio programmato a T+24h) + alert in dashboard; ultimo fallback: il gestore lo
  chiede di persona. Senza numero, niente WhatsApp — limite non aggirabile.
- Il parsing dipende dal formato delle email Airbnb, che può cambiare: l'LLM è robusto
  ai cambi di layout, ma serve un alert se un'email attesa non viene riconosciuta
  (coda "email non interpretate" in dashboard).

### 4.4 Channel Manager / PMS — ✅ FATTIBILE (canale d'integrazione primario)
È la via maestra: il CM è già connesso a Booking, Airbnb, Vrbo ecc. e ha API pubbliche.

| Provider | API | Webhook prenotazioni | Note |
|---|---|---|---|
| **Smoobu** | ✅ pubblica, API key | ✅ | Molto diffuso tra piccoli host, già previsto in dashboard |
| **Beds24** | ✅ pubblica | ✅ | Economico, potente, diffuso in Italia |
| **Lodgify** | ✅ pubblica | ✅ | Già previsto in dashboard |
| **Octorate / Krossbooking** | ✅ (su richiesta) | parziale | Diffusi in Italia |
| **Hospitable** | ✅ | ✅ | Forte su messaggistica Airbnb |

**Implementazione:** un endpoint webhook per provider (n8n webhook node o route API
Next.js) → normalizzazione in formato `bookings` → upsert con `booking_ref` come
chiave di deduplicazione → generazione `scheduled_messages`.
Gestire anche gli eventi di **modifica e cancellazione** (aggiornare date →
ricalcolare `send_at`; cancellare → `cancelled` sui pending).

**Consiglio strategico:** lanciare con **un solo CM supportato bene (Smoobu o Beds24)**
+ email parsing + inserimento manuale. Aggiungere gli altri su richiesta dei clienti.

### 4.5 iCal — ✅ utile solo come rete di sicurezza
Polling ogni 30 min dei feed iCal: dà date e codice prenotazione, **mai i contatti**.
Serve per accorgersi di prenotazioni non intercettate dagli altri canali → genera un
"draft" in dashboard che il gestore completa col telefono.

### 4.6 Inserimento manuale — ✅ il fallback universale (da costruire subito)
Form in dashboard `prenotazioni`: nome, telefono, date, struttura, lingua →
insert + generazione automatica della sequenza. Copre il 100% dei casi limite ed è
il modo più rapido per andare in produzione col primo cliente.

### 4.7 Casella di ingestione email (meccanismo comune a tutti i clienti)
Tutto il flusso email (dirette, Booking, Airbnb) converge su un unico meccanismo:

1. Ad ogni cliente viene assegnato un **alias dedicato**, es.
   `villarossi@inbox.zeromessaggipersi.it` (un solo dominio, alias illimitati).
2. In onboarding il cliente imposta **una regola di inoltro automatico** dalla sua
   casella (Gmail/Outlook: 5 minuti di configurazione, guidata da noi) per le email
   da `automated@airbnb.com`, `noreply@booking.com` e per le richieste dirette.
3. n8n monitora la casella centrale, identifica il cliente dall'alias di destinazione,
   classifica l'email (nuova prenotazione / messaggio ospite / modifica / cancellazione /
   altro) e fa parsing con LLM → upsert in `bookings`.
4. Email non classificabili → coda "da rivedere" in dashboard, mai scartate in silenzio.

Questo è il cuore del servizio per i clienti senza CM/PMS (§4.8) e non richiede al
cliente nessun acquisto né competenza tecnica.

---

## 4-bis. Segmentazione clienti: come si raccolgono i dati in ogni caso

Domanda da fare in fase commerciale: **"Usi un channel manager o un PMS? Quale?"**
La risposta determina il percorso tecnico di onboarding.

### Tipo A — Cliente CON channel manager (Smoobu, Beds24, Lodgify, Octorate, Krossbooking…)
- **Raccolta dati:** integrazione diretta col CM via **API + webhook**. Il CM è già
  collegato a Booking, Airbnb, Vrbo, sito proprio: riceviamo da un'unica fonte
  prenotazioni nuove, **modifiche e cancellazioni** in tempo reale.
- **Telefono:** per Booking quasi sempre presente; per Airbnb spesso mascherato →
  si applica comunque il flusso §4.3 (messaggio programmato; alcuni CM, es.
  Smoobu/Hospitable, possono inviare loro il messaggio in chat Airbnb via API).
- **Onboarding:** il cliente genera una API key dal suo CM e la incolla in dashboard
  (pagina Integrazioni, già predisposta). Zero email parsing necessario.
- **Sforzo nostro:** un connettore per ogni marca di CM. Si parte con 1–2 e si
  aggiungono a richiesta.

### Tipo B — Cliente CON solo PMS (gestionali hotel: Ericsoft, Passepartout, Scidoo, Slope…)
Tre sotto-casi, da verificare PMS per PMS in onboarding:
1. **PMS con API/webhook pubbliche** → si tratta come un CM (Tipo A).
2. **PMS senza API ma con export** (report email automatici, CSV pianificati) →
   n8n fa parsing dell'export sulla casella di ingestione (§4.7), con polling
   schedulato. Aggiornamenti meno tempestivi (dipende dalla frequenza dell'export)
   ma sufficienti: i messaggi D2–D5 si giocano su scala di giorni, non di minuti.
3. **PMS chiuso** (nessuna API, nessun export) → il cliente ricade nel Tipo C: le
   email delle OTA arrivano comunque alla sua casella, e per le prenotazioni
   inserite solo nel PMS resta l'inserimento manuale in dashboard.

### Tipo C — Cliente SENZA channel manager e SENZA PMS (piccoli host, B&B — il target principale)
- **Raccolta dati:** 100% via casella di ingestione (§4.7):
  - Booking.com → parsing email di conferma all'host (nome, date, telefono).
  - Airbnb → flusso a 2 email con messaggio programmato (§4.3).
  - Prenotazioni dirette (email/telefono/Instagram) → parsing email dove possibile,
    altrimenti **form di inserimento manuale** in dashboard (30 secondi a prenotazione).
- **Modifiche/cancellazioni:** Booking e Airbnb inviano email anche per queste →
  stessi parser, upsert sulla prenotazione esistente. Rete di sicurezza opzionale:
  feed iCal (§4.5) per accorgersi di discrepanze sul calendario.
- **Onboarding:** solo la regola di inoltro email + configurazione del messaggio
  programmato su Airbnb (lo facciamo insieme al cliente in una call da 20 minuti).
- È il segmento che giustifica il posizionamento "done-for-you": nessun software da
  comprare, nessuna integrazione da capire.

| | Tipo A (CM) | Tipo B (PMS) | Tipo C (nessuno) |
|---|---|---|---|
| Fonte dati | API/webhook CM | API o export PMS | Email + manuale |
| Tempestività | Tempo reale | Minuti–ore | Minuti (email) |
| Telefono Booking | ✅ | ✅ | ✅ (in email) |
| Telefono Airbnb | flusso §4.3 | flusso §4.3 | flusso §4.3 |
| Modifiche/cancellazioni | automatiche | dipende dall'export | email di notifica |
| Sforzo onboarding | API key | analisi caso per caso | inoltro email |

---

## 5. Problemi critici trovati nel codice attuale

### 5.1 ⛔ Schemi database divergenti (da risolvere prima di tutto)
- Repo sito: `backend/supabase_schema.sql` → tabella **`reservations`** (con flag
  `welcome_sent`, `review_sent`, `followup_sent`).
- Repo dashboard: `supabase/migrations/...sql` → tabella **`bookings`**
  (con `workflow_step`, `booking_source`, `guest_language`) + riferimenti a una
  tabella **`conversations` che non è definita in nessuno dei due schemi**.

**Soluzione:** unificare su **`bookings`** (più completa: ha lingua, sorgente, ref,
stato). Migrare i dati di `reservations` se esistono, eliminare i flag a favore di
`scheduled_messages` (§3), e definire esplicitamente `conversations`:

```sql
CREATE TABLE conversations (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id         uuid REFERENCES properties(id) ON DELETE CASCADE,
  booking_id          uuid REFERENCES bookings(id) ON DELETE SET NULL,
  guest_phone         text NOT NULL,
  problema_segnalato  boolean DEFAULT false,
  last_message_at     timestamptz,
  UNIQUE (property_id, guest_phone)
);
-- messages.conversation_id uuid REFERENCES conversations(id)
```

### 5.2 ⛔ RLS rotta: `clients.id` non coincide con `auth.uid()`
Le policy confrontano `auth.uid()` con `clients.id`, ma `clients.id` è generato con
`gen_random_uuid()` e non ha alcun legame con `auth.users`. Risultato: **un utente
loggato in dashboard non vede nessun dato** (o, se si "aggiusta" a mano, rischio di
vederne troppi). **Soluzione:**

```sql
-- clients.id DEVE essere l'id di auth.users
ALTER TABLE clients ADD CONSTRAINT clients_auth_fk
  FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
-- creazione automatica del profilo al signup
CREATE OR REPLACE FUNCTION handle_new_user() RETURNS trigger AS $$
BEGIN
  INSERT INTO public.clients (id, email) VALUES (new.id, new.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

### 5.3 ⛔ Multi-tenancy WhatsApp: token unico per tutti i clienti

**Cos'è una WABA (in parole semplici):** WhatsApp Business Account = il "contenitore"
che Meta assegna a un'azienda verificata. Dentro la WABA vivono: i numeri di telefono
abilitati all'invio, i template approvati e il token di accesso. Oggi il progetto ha
**una WABA (quella di Zero Messaggi Persi) con un solo numero**: questo È già il
"modello centralizzato", nella sua forma minima.

- **Modello A — WABA centralizzata (consigliato per partire):** si continua con la
  WABA di ZMP e si aggiungono numeri dedicati (uno per struttura o uno per cliente)
  dentro la stessa WABA. Un token, una gestione, template condivisi. Limiti: i numeri
  risultano "di ZMP" agli occhi di Meta; il tetto di numeri per WABA parte basso
  (~2) e sale con la verifica business e la qualità degli invii (fino a 20+).
  Con un numero unico per tutti i clienti si può perfino partire (il template cita il
  nome della struttura), ma il rischio è condiviso: se un cliente genera segnalazioni
  spam, il rating del numero penalizza tutti → appena possibile, un numero per cliente.
- **Modello B — WABA per cliente (Embedded Signup):** ogni gestore collega la *propria*
  WABA tramite un popup di login Meta dentro la nostra dashboard. È la strada giusta
  a regime (il numero è del cliente, il rischio è isolato, niente tetto di numeri).

**Quanto è difficile ottenere l'Embedded Signup?** Burocratico ma fattibile, senza
requisiti di volume (a differenza di Booking.com):
1. App Meta for Developers + **verifica business** della società ZMP su Meta Business
   Manager (documenti aziendali; giorni → 2-3 settimane).
2. **App Review** per i permessi `whatsapp_business_management` e
   `whatsapp_business_messaging` (si registra un video demo del flusso; 1–2 settimane).
3. Totale realistico: **3–6 settimane di pratiche**, una tantum.

**Scorciatoia se le pratiche si bloccano:** appoggiarsi a un BSP (Business Solution
Provider: 360dialog, Twilio, Vonage…) che l'Embedded Signup ce l'ha già — onboarding
dei numeri cliente in giornata, in cambio di un piccolo costo per numero/messaggio.

**In ogni caso:** salvare il token per-tenant in `integrations.config` **cifrato**
(Supabase Vault o pgcrypto), mai in chiaro nel JSONB.

### 5.4 ⚠️ Fuso orario
Tutti i calcoli date nei workflow usano UTC. **Soluzione:** colonna
`properties.timezone` (default `'Europe/Rome'`) e calcolo di `send_at` con
`(checkin_date::timestamp AT TIME ZONE properties.timezone)` lato Postgres,
non in JavaScript dentro n8n.

### 5.5 ⚠️ Normalizzazione telefoni
I numeri arrivano in formati diversi ("333 1234567", "0039333…"). WhatsApp vuole E.164
senza `+` nel campo `to`. **Soluzione:** funzione di normalizzazione unica nel punto di
ingestione (libreria `libphonenumber` in n8n code node o edge function) + validazione;
numeri non validi → prenotazione in stato `telefono_mancante` con alert in dashboard.

### 5.6 ⚠️ Nessuna gestione dello stato di consegna WhatsApp
La Cloud API invia webhook di stato (`sent`/`delivered`/`failed`, incl.
"numero non su WhatsApp"). **Soluzione:** webhook n8n che aggiorna
`scheduled_messages.status`; su `failed` per "no WhatsApp" → fallback email
(se disponibile) + notifica al gestore.

---

## 6. Vincoli WhatsApp (non aggirabili — da progettare attorno)

### 6.1 Finestra 24 ore — NON RISOLVIBILE, gestibile
Fuori dalla finestra di 24h dall'ultimo messaggio dell'ospite si possono inviare **solo
template pre-approvati** da Meta. Tutti i messaggi D1–D5 sono per definizione fuori
finestra → **tutti template**. Le risposte libere (anche AI) sono possibili solo entro
24h dalla risposta dell'ospite. Tempi di approvazione template: da minuti a giorni;
prevedere i template in **it/en/de/fr/es** fin da subito (campo `guest_language` già
presente — bene).

### 6.2 Opt-in obbligatorio — rischio di policy, mitigabile
Meta richiede il consenso dell'ospite prima di contattarlo. Se gli ospiti segnalano i
messaggi come spam, il **quality rating del numero scende fino al blocco**. Mitigazioni:
- Prenotazioni dirette: consenso nei termini di prenotazione.
- Booking: primo messaggio di categoria `utility`, strettamente legato alla
  prenotazione, con identificazione chiara e possibilità di "STOP".
- Airbnb: l'opt-in arriva dal form di check-in (l'ospite fornisce lui il numero) —
  è il caso più pulito.
- Tabella/colonna `opt_out` rispettata dal dispatcher.

### 6.3 Costi
Pricing per conversazione (categoria utility ~€0,03–0,04 in Italia, marketing di più).
~5 conversazioni per soggiorno → costo per prenotazione < €0,20. Irrilevante sul
prezzo del servizio, ma da monitorare per il modello B multi-WABA.

---

## 7. Cosa NON è risolvibile (riepilogo onesto)

| Problema | Risolvibile? | Mitigazione |
|---|---|---|
| API diretta Airbnb | ❌ No (partner-only) | Channel manager + form check-in |
| Telefono reale ospite Airbnb in automatico | ❌ No (mascherato by design) | L'ospite lo fornisce via form; senza, niente WhatsApp |
| API diretta Booking.com per una startup | ❌ No di fatto | Email parsing + channel manager |
| Messaggi liberi fuori finestra 24h | ❌ No (policy Meta) | Template approvati multilingua |
| Garanzia che il numero ospite sia su WhatsApp | ❌ No | Webhook di stato + fallback email |
| Azzerare il rischio segnalazioni spam | ❌ No | Opt-in, categoria utility, opt-out, qualità dei testi |

Tutto il resto (ingestione email, CM, scheduling affidabile, multi-tenancy, inbox,
recensione condizionata) è **fattibile** con lo stack già scelto.

---

## 8. Roadmap consigliata

1. **Unificare lo schema DB** (bookings + conversations + scheduled_messages, fix RLS
   §5.2, timezone, opt_out) — è il prerequisito di tutto.
2. **Form inserimento manuale** in dashboard + generazione automatica sequenza.
3. **Dispatcher unico n8n** (sostituisce D1–D5) + webhook stati WhatsApp.
4. **Template Meta** approvati in IT/EN per i 5 messaggi.
5. **Email parsing** (dirette + conferme Booking) con coda di conferma in dashboard.
6. **Integrazione Smoobu (o Beds24)** via webhook: copre Booking + Airbnb date/nomi.
7. **Form web check-in** proprietario (raccolta telefono + consenso, sblocco codici).
8. **Inbox conversazioni** con webhook inbound + flag `problema_segnalato`
   (manuale prima, AI poi) → recensione condizionata.
9. A regime: Embedded Signup Meta (modello B), altri CM, risposte AI in finestra 24h.

Con i punti 1–4 il servizio è **vendibile al primo cliente** (inserimento manuale +
automazione completa dei messaggi). I punti 5–7 eliminano progressivamente il lavoro
manuale.
