// Build the WashKrew policy pages (privacy, terms, support, delete-account, policies)
// in the website's own design, from the Markdown in release/store/policies/.
//
//   node release/store/prepare-website.mjs --preview         whole-site preview in build/store/policy-preview (not deployed)
//   node release/store/prepare-website.mjs --stage-approved  writes the pages into apps/website/public (still not deployed)
//
// Staging refuses to run until the owner approvals in release.json are recorded and no
// unresolved draft wording remains. Deploying is a separate step (see docs/STORE-RELEASE-2026-11-03.md).
import {readFile, writeFile, mkdir, cp, rm} from 'node:fs/promises';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const folder = dirname(fileURLToPath(import.meta.url));
const root = resolve(folder, '../..');
const site = resolve(root, 'apps/website/public');
const mode = process.argv[2] ?? '--preview';
if (!['--preview', '--stage-approved'].includes(mode)) throw Error('Use --preview or --stage-approved.');
const approved = mode === '--stage-approved';
const config = JSON.parse(await readFile(resolve(folder, 'release.json'), 'utf8'));
if (approved && (!config.approvals.policyTextApproved || !config.approvals.supportMailboxAndPhoneVerified || !config.approvals.retentionAndPhotoProcessingReviewed))
  throw Error('Owner approval, working support contacts and retention/photo review must be recorded before staging public pages.');

const {supportEmail: email, supportPhone: phone} = config.business;
const phoneShown = '+91 ' + phone.slice(3, 8) + ' ' + phone.slice(8);

// Account deletion requests are POSTed here as JSON (see docs/CHANGES-2026-11-03-POLICY-PAGES.md).
// Until the backend endpoint exists, the form still opens the pre-filled email.
const DELETION_ENDPOINT = '/api/account-deletion-request';

const pages = {
  privacy: {title: 'Privacy policy', description: 'How WashKrew collects, uses, shares and protects your personal data, how long we keep it, and your rights.', toc: true},
  terms: {title: 'Terms of use', description: 'The terms for using WashKrew and WashKrew Captain, including bookings, payments, cancellation and refunds.', toc: true},
  support: {title: 'Help and support', description: 'Contact WashKrew support 24/7 by phone, email or in the app. Grievance Officer and registered office details.'},
  'delete-account': {title: 'Delete your account', description: 'Delete your WashKrew or WashKrew Captain account in the app, or send us a request.'},
};
const documents = {};
for (const name of Object.keys(pages)) {
  documents[name] = await readFile(resolve(folder, 'policies', name + '.md'), 'utf8');
  if (approved && /draft|owner must|owner decisions still|still need|before publi|before submitt/i.test(documents[name]))
    throw Error(`${name}: unresolved draft text remains. Have the owner review and finalize the actual policy, not just change an approval flag.`);
}

// ---------- Markdown (the small subset the policies use) ----------
const esc = s => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const inline = s => esc(s)
  .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
  .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2">$1</a>');
const slug = s => s.replace(/^\d+\.\s*/, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
function list(lines, ordered) {
  const tag = ordered ? 'ol' : 'ul';
  let html = `<${tag}>`, open = false, sub = false;
  for (const line of lines) {
    const nested = /^\s{2,}[-*] /.test(line);
    const text = line.replace(/^\s*(?:[-*]|\d+\.) /, '');
    if (nested) { if (!sub) { html += '<ul>'; sub = true; } html += `<li>${inline(text)}</li>`; continue; }
    if (sub) { html += '</ul>'; sub = false; }
    if (open) html += '</li>';
    html += `<li>${inline(text)}`; open = true;
  }
  if (sub) html += '</ul>';
  return html + (open ? '</li>' : '') + `</${tag}>`;
}
function table(lines) {
  const cells = l => l.trim().replace(/^\||\|$/g, '').split('|').map(c => c.trim());
  const [head, , ...rows] = lines;
  return '<div class="policy-table"><table><thead><tr>' + cells(head).map(c => `<th scope="col">${inline(c)}</th>`).join('') + '</tr></thead><tbody>'
    + rows.map(r => '<tr>' + cells(r).map((c, i) => i ? `<td>${inline(c)}</td>` : `<th scope="row">${inline(c)}</th>`).join('') + '</tr>').join('') + '</tbody></table></div>';
}
function render(md) {
  const out = {title: '', updated: '', html: '', headings: []};
  for (const raw of md.trim().split(/\r?\n\s*\r?\n/)) {
    const block = raw.replace(/\s+$/, '');
    const lines = block.split(/\r?\n/);
    if (block.startsWith('# ')) { out.title = block.slice(2).trim(); continue; }
    if (block.startsWith('Last updated:')) { out.updated = block.trim(); continue; }
    if (block.startsWith('## ')) {
      const text = block.slice(3).trim(), id = slug(text);
      out.headings.push({id, text: text.replace(/^\d+\.\s*/, '')});
      out.html += `<h2 id="${id}">${inline(text)}</h2>\n`; continue;
    }
    if (block.startsWith('### ')) { out.html += `<h3>${inline(block.slice(4).trim())}</h3>\n`; continue; }
    if (block.trim() === '{{contact}}') { out.html += contactCards(); continue; }
    if (block.trim() === '{{deletion-form}}') { out.html += deletionForm(); continue; }
    if (lines.every(l => /^\s*[-*] /.test(l))) { out.html += list(lines, false) + '\n'; continue; }
    if (lines.every(l => /^\s*\d+\. /.test(l))) { out.html += list(lines, true) + '\n'; continue; }
    if (lines.every(l => l.trim().startsWith('|'))) { out.html += table(lines) + '\n'; continue; }
    out.html += `<p>${inline(lines.join(' '))}</p>\n`;
  }
  return out;
}

// ---------- Components ----------
function contactCards() {
  return `<div class="contact-cards">
  <a class="contact-card" href="tel:${phone}"><svg class="ico" aria-hidden="true"><use href="#i-call"/></svg><span class="contact-title">Call us</span><span class="contact-value">${phoneShown}</span><span class="contact-note">24 hours a day, every day</span></a>
  <a class="contact-card" href="mailto:${email}"><svg class="ico" aria-hidden="true"><use href="#i-mail"/></svg><span class="contact-title">Email us</span><span class="contact-value">${email}</span><span class="contact-note">We reply within 6 hours</span></a>
  <div class="contact-card"><svg class="ico" aria-hidden="true"><use href="#i-phone"/></svg><span class="contact-title">In the app</span><span class="contact-value">Help and support</span><span class="contact-note">Fastest for a booking or job</span></div>
</div>\n`;
}
function deletionForm() {
  return `<form class="delete-form" id="delete-form" novalidate>
  <fieldset class="field">
    <legend>Which account do you want to delete?</legend>
    <div class="choice-row">
      <label class="choice"><input type="radio" name="role" value="customer" required> <span><b>WashKrew</b> customer</span></label>
      <label class="choice"><input type="radio" name="role" value="captain"> <span><b>WashKrew Captain</b></span></label>
      <label class="choice"><input type="radio" name="role" value="both"> <span>Both</span></label>
    </div>
  </fieldset>
  <div class="field-row">
    <div class="field"><label for="del-name">Full name</label><input id="del-name" name="name" type="text" autocomplete="name" maxlength="120" required></div>
    <div class="field"><label for="del-phone">Registered mobile number</label><div class="phone-input"><span>+91</span><input id="del-phone" name="phone" type="tel" inputmode="numeric" autocomplete="tel-national" maxlength="10" placeholder="10-digit number" required></div></div>
  </div>
  <div class="field"><label for="del-email">Email for updates <span class="optional">(optional)</span></label><input id="del-email" name="email" type="email" autocomplete="email" maxlength="160"></div>
  <div class="field"><label for="del-reason">Anything you'd like to tell us? <span class="optional">(optional)</span></label><textarea id="del-reason" name="reason" rows="3" maxlength="1000"></textarea></div>
  <input class="hp" type="text" name="website" tabindex="-1" autocomplete="off" aria-hidden="true">
  <label class="check"><input id="del-confirm" type="checkbox" name="confirm" required> <span>I understand my account and personal data will be permanently deleted, apart from records the law requires WashKrew to keep.</span></label>
  <p class="form-error" id="del-error" role="alert" hidden></p>
  <button class="btn btn-danger" type="submit" id="del-submit">Request deletion</button>
</form>
<div class="delete-done" id="delete-done" hidden tabindex="-1">
  <h3 id="done-title">Request received</h3>
  <p id="done-text"></p>
  <p class="done-steps">We acknowledge requests within 48 hours, confirm it is your account on your registered number, and delete it within 90 days.</p>
  <p>If your email app did not open, email <a href="mailto:${email}">${email}</a> with the subject "Account deletion request", your full name, registered mobile number and which app.</p>
</div>\n`;
}

function hub() {
  const items = [
    ['/privacy', 'Privacy policy', 'What data we collect, how we use it, who we share it with and how long we keep it.'],
    ['/terms', 'Terms of use', 'The rules for using WashKrew and WashKrew Captain.'],
    ['/terms#cancellation-and-refunds', 'Cancellation and refunds', 'What you get back if you or we cancel, or if a wash goes wrong.'],
    ['/support', 'Help and support', 'Call us 24/7, email us, and our Grievance Officer.'],
    ['/delete-account', 'Delete your account', 'Delete in the app, or send us a request.'],
  ];
  return `<ul class="hub">${items.map(([href, t, d]) => `<li><a href="${href}"><span class="hub-title">${t}</span><span class="hub-text">${d}</span><svg class="ico" aria-hidden="true"><use href="#i-arrow"/></svg></a></li>`).join('')}</ul>`;
}

// ---------- Page shell (header, sprite and footer come from the homepage) ----------
const home = await readFile(resolve(site, 'index.html'), 'utf8');
const pick = re => { const m = home.match(re); if (!m) throw Error('Homepage part not found: ' + re); return m[0]; };
const toHome = s => s
  .replace(/href="#get-app" data-app="captain"/g, 'href="/#get-captain-app"')
  .replace(/href="#get-app" data-app="customer"/g, 'href="/#get-app"')
  .replace(/href="#([a-z-]+)"/g, 'href="/#$1"')
  .replace(/ data-footer-store="[a-z]+"/g, '');
const extraIcons = `<symbol id="i-call" viewBox="0 0 24 24"><path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2"/></symbol>
      <symbol id="i-mail" viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/></symbol>
      <symbol id="i-arrow" viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></symbol>
    </defs>`;
const sprite = pick(/<svg width="0" height="0"[\s\S]*?<\/svg>/).replace('</defs>', extraIcons);
const header = toHome(pick(/<header class="site-header">[\s\S]*?<\/header>/));
const footer = toHome(pick(/<footer class="site-footer"[\s\S]*?<\/footer>/));

function shell(name, {title, description}, body, updated, headings) {
  const toc = headings?.length ? `<nav class="policy-toc" aria-label="On this page"><p class="toc-label">On this page</p><ol>${headings.map(h => `<li><a href="#${h.id}">${esc(h.text)}</a></li>`).join('')}</ol></nav>` : '';
  const url = 'https://washkrew.com/' + name;
  return `<!doctype html>
<html lang="en-IN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${esc(title)} | WashKrew</title>
  <meta name="description" content="${esc(description)}">
  ${approved ? `<link rel="canonical" href="${url}">` : '<meta name="robots" content="noindex,nofollow">'}
  <meta name="theme-color" content="#FFFFFF">
  <link rel="icon" href="/favicon.ico" sizes="48x48">
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="apple-touch-icon" href="/apple-touch-icon.png">
  <link rel="preload" href="/fonts/Roboto-Bold.woff2" as="font" type="font/woff2" crossorigin>
  <link rel="preload" href="/fonts/Roboto-Regular.woff2" as="font" type="font/woff2" crossorigin>
  <link rel="stylesheet" href="/styles.css">
</head>
<body class="policy-page">
  <a class="skip" href="#main">Skip to content</a>
  ${sprite}
  ${approved ? '' : '<p class="preview-strip">Preview for review. Not published yet.</p>'}
  ${header}
  <main id="main">
    <section class="policy-hero"><div class="wrap"><p class="crumbs"><a href="/">Home</a> <span aria-hidden="true">/</span> <a href="/policies">Policies</a></p><h1>${esc(title)}</h1>${updated ? `<p class="policy-updated">${esc(updated)}</p>` : ''}</div></section>
    <div class="wrap policy-layout${toc ? '' : ' no-toc'}">${toc}<article class="prose">${body}</article></div>
  </main>
  ${footer}
  <script>
    document.getElementById('year').textContent = new Date().getFullYear();
    (function socials() {
      const tip = document.getElementById('social-tip'); let timer;
      document.querySelectorAll('[data-social]').forEach(btn => btn.addEventListener('click', () => {
        const r = btn.getBoundingClientRect(), box = btn.closest('.site-footer').getBoundingClientRect();
        tip.textContent = btn.dataset.social + ' page coming soon'; tip.hidden = false;
        const w = tip.offsetWidth;
        tip.style.left = Math.max(8, Math.min(r.left - box.left + r.width / 2 - w / 2, box.width - w - 8)) + 'px';
        tip.style.top = (r.top - box.top - tip.offsetHeight - 10) + 'px';
        clearTimeout(timer); timer = setTimeout(() => { tip.hidden = true; }, 2500);
      }));
    })();
  </script>
  ${name === 'delete-account' ? deletionScript() : ''}
</body>
</html>
`;
}

function deletionScript() {
  return `<script>
    (function deletionRequest() {
      const ENDPOINT = ${JSON.stringify(DELETION_ENDPOINT)};
      const EMAIL = ${JSON.stringify(email)};
      const form = document.getElementById('delete-form');
      const err = document.getElementById('del-error');
      const done = document.getElementById('delete-done');
      const roles = {customer: 'WashKrew (customer)', captain: 'WashKrew Captain', both: 'WashKrew and WashKrew Captain'};
      const fail = (msg, field) => { err.textContent = msg; err.hidden = false; if (field) field.focus(); return false; };
      form.addEventListener('submit', async e => {
        e.preventDefault(); err.hidden = true;
        const data = Object.fromEntries(new FormData(form));
        if (data.website) return;
        const phone = (data.phone || '').replace(/\\D/g, '').slice(-10);
        if (!data.role) return fail('Choose which account to delete.', form.querySelector('input[name=role]'));
        if (!data.name || data.name.trim().length < 2) return fail('Enter your full name.', form.elements.name);
        if (!/^[6-9]\\d{9}$/.test(phone)) return fail('Enter your 10-digit registered mobile number.', form.elements.phone);
        if (data.email && !/^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$/.test(data.email)) return fail('Check your email address, or leave it empty.', form.elements.email);
        if (!data.confirm) return fail('Tick the box to confirm you understand.', form.elements.confirm);
        const request = {role: data.role, name: data.name.trim(), phone: '+91' + phone, email: (data.email || '').trim(), reason: (data.reason || '').trim(), source: 'washkrew.com/delete-account'};
        const subject = 'Account deletion request: ' + roles[request.role] + ', ' + request.phone;
        const body = 'Please delete my account.\\n\\nApp: ' + roles[request.role] + '\\nFull name: ' + request.name + '\\nRegistered mobile: ' + request.phone + (request.email ? '\\nEmail: ' + request.email : '') + (request.reason ? '\\nReason: ' + request.reason : '') + '\\n\\nI understand my account and personal data will be permanently deleted, apart from records the law requires WashKrew to keep.';
        // Open the pre-filled email first, while the click still counts as the user's action.
        window.location.href = 'mailto:' + EMAIL + '?subject=' + encodeURIComponent(subject) + '&body=' + encodeURIComponent(body);
        const button = document.getElementById('del-submit'); button.disabled = true; button.textContent = 'Sending...';
        let reference = '';
        try {
          const ctrl = new AbortController(); const t = setTimeout(() => ctrl.abort(), 8000);
          const res = await fetch(ENDPOINT, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(request), signal: ctrl.signal, keepalive: true});
          clearTimeout(t);
          if (res.ok) { const json = await res.json().catch(() => ({})); reference = json.reference || 'received'; }
        } catch (_) { /* The email above is the fallback. */ }
        document.getElementById('done-text').textContent = reference
          ? 'Your request has reached our team' + (reference !== 'received' ? ' (reference ' + reference + ')' : '') + '. Your email app should also have opened with the details: press Send so we have a copy.'
          : 'Your email app has opened with your request filled in. Press Send to submit it to ' + EMAIL + '.';
        form.hidden = true; done.hidden = false; done.focus();
      });
    })();
  </script>`;
}

// ---------- Write ----------
const destination = approved ? site : resolve(root, 'build/store/policy-preview');
if (!approved) { await rm(destination, {recursive: true, force: true}); await cp(site, destination, {recursive: true}); }
await mkdir(destination, {recursive: true});
for (const [name, meta] of Object.entries(pages)) {
  const doc = render(documents[name]);
  await writeFile(resolve(destination, name + '.html'), shell(name, meta, doc.html, doc.updated, meta.toc ? doc.headings : null));
}
await writeFile(resolve(destination, 'policies.html'), shell('policies', {title: 'Policies and support', description: 'WashKrew privacy policy, terms of use, cancellation and refunds, support and account deletion.'},
  '<p>Everything about how WashKrew works for customers and captains, in one place.</p>' + hub(), '', null));
console.log(`${approved ? 'Approved pages staged (not deployed)' : 'Preview only'}: ${destination}`);
