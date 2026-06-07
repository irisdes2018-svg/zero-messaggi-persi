-- ============================================================
-- ZERO MESSAGGI PERSI — Schema Supabase (PostgreSQL)
-- Esegui intero file nel pannello: Supabase > SQL Editor > New query
-- ============================================================

-- ── 1. TABELLE ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS clients (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email          text UNIQUE NOT NULL,
  nomecompleto   text,
  telefono       text,   -- Numero WhatsApp gestore (con prefisso, es. +39333...)
  created_at     timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS properties (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id            uuid REFERENCES clients(id) ON DELETE CASCADE,
  nome                 text NOT NULL,
  whatsapp_number_id   text UNIQUE NOT NULL, -- ID numerico Meta (es. "123456789012345")
  checkin_ora          text DEFAULT '15:00',
  checkout_ora         text DEFAULT '11:00',
  indirizzo            text,
  access_code          text,
  wifi_name            text,
  wifi_password        text,
  trash_rules          text,
  parking_rules        text,
  local_tips           text,
  extra_rules          text,
  attivo               boolean DEFAULT true,
  created_at           timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS messages (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id   uuid REFERENCES properties(id) ON DELETE CASCADE,
  guest_phone   text NOT NULL,         -- Numero ospite con prefisso (es. +34612...)
  mittente      text NOT NULL          -- 'ospite' | 'ai' | 'host'
                CHECK (mittente IN ('ospite', 'ai', 'host')),
  testo         text NOT NULL,
  timestamp     timestamptz DEFAULT now()
);

-- ── 2. INDICI (performance) ──────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_messages_property_guest
  ON messages (property_id, guest_phone, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_properties_whatsapp
  ON properties (whatsapp_number_id);

-- ── 3. ROW LEVEL SECURITY ────────────────────────────────────
-- Attiva RLS su tutte le tabelle. Le policy permettono l'accesso
-- SOLO tramite service_role (usato da n8n) o all'utente autenticato
-- che è il proprietario del record.

ALTER TABLE clients    ENABLE ROW LEVEL SECURITY;
ALTER TABLE properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages   ENABLE ROW LEVEL SECURITY;

-- Policy: service_role (n8n) ha accesso totale — non è limitato da RLS
-- Nota: in Supabase il service_role bypassa RLS di default. Queste policy
-- servono per l'accesso futuro tramite JWT utente.

-- clients: ogni utente vede solo il proprio record
CREATE POLICY "clients_self_access" ON clients
  FOR ALL
  USING (auth.uid()::text = id::text);

-- properties: il gestore vede solo le sue strutture
CREATE POLICY "properties_owner_access" ON properties
  FOR ALL
  USING (
    client_id IN (
      SELECT id FROM clients WHERE id::text = auth.uid()::text
    )
  );

-- messages: il gestore vede i messaggi delle sue strutture
CREATE POLICY "messages_owner_access" ON messages
  FOR ALL
  USING (
    property_id IN (
      SELECT p.id FROM properties p
      JOIN clients c ON c.id = p.client_id
      WHERE c.id::text = auth.uid()::text
    )
  );

-- ── 4. REALTIME (opzionale, per dashboard live) ──────────────
-- Abilita la replica realtime sulla tabella messages
-- Dal pannello Supabase: Database > Replication > attiva 'messages'
-- Oppure esegui:

ALTER PUBLICATION supabase_realtime ADD TABLE messages;

-- ── 6. TABELLA PRENOTAZIONI (per workflow schedulati D1-D4) ──
-- Registra ogni prenotazione con i dati dell'ospite e i flag di invio messaggi

CREATE TABLE IF NOT EXISTS reservations (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id       uuid REFERENCES properties(id) ON DELETE CASCADE,
  guest_name        text NOT NULL,
  guest_phone       text NOT NULL,               -- Con prefisso internazionale, es. +39333...
  checkin_date      date NOT NULL,
  checkout_date     date NOT NULL,
  checkin_link      text,                         -- Link al form Web Check-in (es. Typeform, Tally)
  review_link       text,                         -- Link diretto alla pagina recensioni
  review_sent       boolean DEFAULT false,        -- true = messaggio recensione già inviato (D3)
  welcome_sent      boolean DEFAULT false,        -- true = messaggio benvenuto già inviato (D4)
  created_at        timestamptz DEFAULT now()
);

-- Indici per le query dei workflow schedulati
CREATE INDEX IF NOT EXISTS idx_reservations_checkin
  ON reservations (property_id, checkin_date);

CREATE INDEX IF NOT EXISTS idx_reservations_checkout
  ON reservations (property_id, checkout_date);

-- RLS per reservations
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reservations_owner_access" ON reservations
  FOR ALL
  USING (
    property_id IN (
      SELECT p.id FROM properties p
      JOIN clients c ON c.id = p.client_id
      WHERE c.id::text = auth.uid()::text
    )
  );

-- Realtime per reservations (utile per dashboard)
ALTER PUBLICATION supabase_realtime ADD TABLE reservations;

-- ── 7. COLONNE AGGIUNTIVE SU properties (workflow schedulati) ─
-- Aggiunte per allineamento con la direttiva D block
-- Nota: i flag review_sent/welcome_sent sono già nella tabella reservations
--       (per prenotazione). Le colonne su properties sono ridondanti ma
--       vengono aggiunte per rispettare la specifica originale.

ALTER TABLE properties ADD COLUMN IF NOT EXISTS
  extra_checkout_instructions text;

-- ── 8. COLONNA followup_sent (workflow D5) ───────────────────
-- Flag per tracciare l'invio del messaggio "come va?" T+1 dal check-in
ALTER TABLE reservations ADD COLUMN IF NOT EXISTS
  followup_sent boolean DEFAULT false;

-- ── 5. DATI DI TEST (da rimuovere in produzione) ─────────────
-- Decommenta per inserire un cliente e una struttura demo

/*
INSERT INTO clients (email, nomecompleto, telefono)
VALUES ('demo@zeromessaggipersi.it', 'Mario Rossi', '+393331234567')
RETURNING id;

-- Sostituisci 'CLIENT_ID_QUI' con l'uuid restituito sopra
INSERT INTO properties (
  client_id, nome, whatsapp_number_id,
  checkin_ora, checkout_ora, indirizzo,
  access_code, wifi_name, wifi_password,
  trash_rules, parking_rules, local_tips, extra_rules
) VALUES (
  'CLIENT_ID_QUI',
  'Villa Atlantico',
  '123456789012345',
  '15:00', '11:00',
  'Calle Ejemplo 1, Playa Blanca, Lanzarote',
  '4821',
  'VillaAtlantico_5G',
  'ospiti2024',
  'Differenziata: lunedì plastica, giovedì organico. Contenitori nel ripostiglio.',
  'Parcheggio privato incluso: posto auto n°3 davanti al cancello.',
  'Ristorante El Golfo (5 min a piedi), spiaggia Papagayo (10 min auto).',
  'Silenzio dopo le 22:00. Vietato fumare in casa. Max 4 ospiti.'
);
*/
