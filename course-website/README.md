# Meesho Reselling Course — Malayalam Sales Website

A single-page, mobile-first website for selling the Malayalam Reselling Course (28 modules). No build step: open `index.html` or host the folder anywhere static (GitHub Pages, Netlify, Cloudflare Pages).

## Before going live — edit `CONFIG` near the bottom of `index.html`

- `brand`, `price`, `mrp`, `whatsapp` (country code + number, no "+")
- `paymentLink` — Razorpay / Instamojo / Cashfree link (empty = enroll via WhatsApp)
- `youtubeId` — intro video shown in the hero (empty = ₹300 → ₹499 example card)
- `founder` — name, role, photo path, bio paragraphs, mission line (`null` hides the section)
- `testimonials` — real student reviews only; the section stays hidden while empty
- `social`, `legal` — Instagram / YouTube / email and refund / terms / privacy page links

## Sections
Dark theme with gold accents. Hero with ₹300 → ₹499 example · What is reselling (workflow image) · 6-step workflow · Why Meesho, mentor section, student feedback (when added), what you need · What you'll learn · 28-module curriculum (expandable) · Live profit calculator · Final project · Who it's for · Pricing · FAQ · Disclaimer (not affiliated with Meesho/Meta; no income guarantee) · Floating WhatsApp button and sticky mobile buy bar.
