# Zero Messaggi Persi — Sito statico pronto per Netlify

Sito statico HTML/CSS esportato da Stitch e completato con pagine aggiuntive, form Netlify e configurazione di deploy.

---

## Struttura delle pagine

| File | Contenuto | Stato |
|---|---|---|
| `index.html` | Home — hero, pitch, dashboard mockup | Stitch |
| `come-funziona.html` | Come funziona il servizio, step by step | Stitch |
| `piattaforma.html` | Panoramica della piattaforma AI Concierge | Stitch |
| `servizi.html` | Elenco dei servizi offerti | Stitch |
| `integrazioni.html` | Integrazioni con canali e PMS | Stitch |
| `guest-content-kit.html` | Il Guest Content Kit | Stitch |
| `prezzi.html` | Piani e prezzi, tabella comparativa | Stitch |
| `prova-gratuita.html` | Form richiesta accesso gratuito 7 giorni | Completata |
| `contatti.html` | Form contatto, demo, Audit, WhatsApp | Completata |
| `privacy.html` | Privacy Policy — titolare: Irene De Santis | Completata |
| `grazie.html` | Pagina di conferma dopo invio form | Completata |

---

## Come pubblicare su Netlify

### Opzione A — Netlify Drop (più veloce)

1. Vai su [app.netlify.com/drop](https://app.netlify.com/drop)
2. Trascina l'intera cartella del progetto nella finestra del browser
3. Netlify pubblica il sito e restituisce un URL
4. Dal pannello puoi collegare un dominio personalizzato

### Opzione B — Da repository GitHub

1. Carica la cartella su un repository GitHub
2. Vai su [app.netlify.com](https://app.netlify.com) → **Add new site** → **Import an existing project**
3. Seleziona GitHub e scegli il repository
4. Impostazioni di build:
   - **Build command:** *(lascia vuoto)*
   - **Publish directory:** `.`
5. Clicca **Deploy site**

### Opzione C — Netlify CLI

```bash
npm install -g netlify-cli
netlify login
netlify deploy --dir . --prod
```

---

## Form Netlify

Le pagine `prova-gratuita.html` e `contatti.html` usano **Netlify Forms** (`netlify` + `data-netlify="true"` sul tag `<form>`). Dopo il submit, l'utente viene reindirizzato a `grazie.html`.

Netlify rileva i form automaticamente al primo deploy e li raccoglie nella sezione **Forms** del pannello.

> **Nota:** Netlify Forms è gratuito fino a 100 invii/mese. Per volumi maggiori valuta Netlify Forms Pro, Tally o Typeform.

---

## WhatsApp

Il pulsante WhatsApp in `contatti.html` punta a `+39 342 525 9174` e si apre in una nuova finestra (`target="_blank"`).

---

## Privacy Policy

Titolare: **Irene De Santis** — smmirenedesantis@gmail.com — Las Palmas.

---

## Prossimi step consigliati

- [ ] Collegare Cal.com nella sezione "Prenota una demo" di `contatti.html`
- [ ] Aggiungere cookie banner se si usano strumenti di tracking
- [ ] Dominio personalizzato — configurabile da Netlify > Domain management
- [ ] Analytics — aggiungere Plausible o Google Analytics nella sezione `<head>`
