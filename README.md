# Zero Messaggi Persi — sito marketing

Sito statico in HTML (Tailwind via CDN) pubblicato su **Vercel** all'indirizzo **https://zeromessaggipersi.it**.
Questo repository contiene solo i file visibili agli utenti: brief, documenti tecnici e backend restano in locale (vedi `.gitignore`).

## Pagine

| File | Contenuto |
|---|---|
| `index.html` | Home: tutte le sezioni, con ancore `#come-funziona`, `#gestionali` e `#agenzie` (usate dal menu) |
| `prezzi.html` | Prezzi per i proprietari (€15/appartamento, minimo €49, primo mese gratis) |
| `contatti.html` | Contatti, WhatsApp e calendario Cal.com |
| `grazie.html` | Pagina di conferma (non più collegata a un form) |

`come-funziona.html`, `servizi.html` e `prova-gratuita.html` non esistono più: `vercel.json` reindirizza i vecchi indirizzi a `/#come-funziona` e `prezzi.html`.

I prezzi per le agenzie sono accordi privati e **non** vanno sul sito.
| `privacy.html` | Privacy Policy |
| `termini.html` | Condizioni d'uso |
| `eliminazione-dati.html` | Istruzioni per la cancellazione dei dati (richiesta anche da Meta) |

## Servizi esterni

- **Cal.com** — evento `zero-messaggi-persi/20min` in `contatti.html` e `grazie.html`. In `contatti.html` si carica **subito all'apertura della pagina** (scelta di Irene, 19/11/2026); in `grazie.html` solo al clic. Le altre pagine non contattano Cal.com.
- **WhatsApp** — link `wa.me/393425259174`.
- **Tailwind CSS** — caricato da `cdn.tailwindcss.com`.

Se aggiungi un nuovo servizio esterno, aggiornalo anche in `privacy.html`.

## Font e icone

I font (Libre Caslon Text, Manrope) e le icone Material Symbols sono ospitati in `fonts/` e caricati da `fonts/fonts.css`: nessuna richiesta a Google Fonts.

Il file delle icone contiene **solo le icone usate oggi** nel sito. Se ne aggiungi una nuova, rigenera `fonts/MaterialSymbolsOutlined-subset.woff2` da
`https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&icon_names=<elenco,alfabetico,separato,da,virgole>`.

## Privacy e cookie

- Il sito **non usa** analytics, pixel o cookie di profilazione, quindi non serve un banner cookie.
- Se aggiungi Google Analytics, Meta Pixel o simili, serve un banner di consenso **prima** di caricarli (Plausible senza cookie non lo richiede) e va aggiornata la Privacy Policy.
- Autorità di controllo competente: AEPD (Spagna).

## URL per l'app Meta (Impostazioni app → Di base)

- URL dell'informativa sulla privacy: `https://zeromessaggipersi.it/privacy.html`
- URL dei Termini di servizio: `https://zeromessaggipersi.it/termini.html`
- URL per l'eliminazione dei dati: `https://zeromessaggipersi.it/eliminazione-dati.html`

## Pubblicazione

Ogni push su `main` viene pubblicato da Vercel. Non c'è build: la cartella pubblicata è la radice del repository.
