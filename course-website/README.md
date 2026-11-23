# Meesho Reselling Course — Malayalam Sales Website

A single-page, mobile-first website for selling the Malayalam Reselling Course (28 modules). No build step: open `index.html` or host the folder anywhere static (GitHub Pages, Netlify, Cloudflare Pages).

## Before going live — edit `CONFIG` at the bottom of `index.html`

```js
const CONFIG = {
  brand: "Reseller Academy",   // footer brand text (header logo text is in the <header> markup)
  price: 999,                  // course price ₹
  mrp: 2999,                   // strike-through price ₹
  whatsapp: "919999999999",    // country code + number, no "+"
  paymentLink: ""              // Razorpay / Instamojo / Cashfree link; empty = enroll via WhatsApp
};
```

Also review the pricing-card bullet list (what's included) so it matches what you actually deliver.

## Sections
Hero with ₹300 → ₹499 example · What is reselling (workflow image) · 6-step workflow · Why Meesho (no inventory, research, COD, delivery) · What you'll learn · 28-module curriculum (expandable) · Live profit calculator · Final project · Who it's for · Pricing · FAQ · Disclaimer (not affiliated with Meesho/Meta; no income guarantee) · Floating WhatsApp button and sticky mobile buy bar.
