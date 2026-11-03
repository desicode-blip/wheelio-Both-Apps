// Preview policy drafts, or stage approved pages into the EXISTING website.
// Does not deploy. Never publish unapproved policy text automatically.
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const folder = dirname(fileURLToPath(import.meta.url));
const root = resolve(folder, '../..');
const mode = process.argv[2] ?? '--preview';
if (!['--preview', '--stage-approved'].includes(mode)) throw Error('Use --preview or --stage-approved.');
const config = JSON.parse(await readFile(resolve(folder, 'release.json'), 'utf8'));
const approved = mode === '--stage-approved';
if (approved && (!config.approvals.policyTextApproved || !config.approvals.supportMailboxAndPhoneVerified || !config.approvals.retentionAndPhotoProcessingReviewed))
  throw Error('Owner approval, working support contacts and retention/photo review must be recorded before staging public pages.');
const documents = {};
for (const name of ['privacy', 'terms', 'support', 'delete-account']) {
  documents[name] = await readFile(resolve(folder, 'policies', name + '.md'), 'utf8');
  if (approved && /draft|owner must|owner decisions still|still need|before publi|before submitt/i.test(documents[name]))
    throw Error(`${name}: unresolved draft text remains. Have the owner review and finalize the actual policy, not just change an approval flag.`);
}
const esc = s => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const content = md => md.trim().split(/\r?\n\r?\n/).map(block => {
  if (block.startsWith('# ')) return '<h1>' + esc(block.slice(2)) + '</h1>';
  if (block.startsWith('## ')) return '<h2>' + esc(block.slice(3)) + '</h2>';
  if (block.startsWith('- ')) return '<ul>' + block.split(/\r?\n/).map(l => '<li>' + esc(l.replace(/^- /, '')) + '</li>').join('') + '</ul>';
  return '<p>' + esc(block.replace(/\r?\n/g, ' ')) + '</p>';
}).join('\n');
const destination = resolve(root, approved ? 'apps/website/public' : 'build/store/policy-preview');
await mkdir(destination, {recursive: true});
for (const name of [...Object.keys(documents), 'policies']) {
  const body = name === 'policies'
    ? '<h1>WashKrew policies and support</h1><p>Choose a page below for the Customer and Captain apps.</p>'
    : content(documents[name]);
  const request = name === 'delete-account'
    ? '<p><a class="action" href="mailto:info@washkrew.com?subject=WashKrew%20account%20deletion&amp;body=Please%20delete%20my%20WashKrew%20Customer%20or%20Captain%20account.%0AApp%20role%3A%20%0ARegistered%20phone%3A%20">Request account deletion by email</a></p><p>This opens your email application. Send the email to submit the request; this page does not itself delete an account. Email manually if the button cannot open.</p>' : '';
  const links = Object.keys(documents).map(p => `<a href="${p}.html">${esc(p.replaceAll('-', ' '))}</a>`).join(' · ');
  await writeFile(resolve(destination, name + '.html'), `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>WashKrew — ${esc(name)}</title>${approved ? '' : '<meta name="robots" content="noindex,nofollow">'}
<style>body{margin:0;background:#f6f9fd;color:#22282d;font:17px/1.65 system-ui,sans-serif}main{max-width:850px;margin:32px auto;padding:32px;background:white;border-radius:20px}h1{font-size:30px;line-height:1.25}h2{font-size:22px;margin-top:32px}a{color:#0049ff}nav{padding:16px 0;border-top:1px solid #dce4f2}li{margin:12px 0}.draft{background:#fff0cc;padding:16px;border-radius:12px}.action{display:inline-block;padding:14px 20px;border-radius:12px;background:#0049ff;color:white;font-weight:600}@media(max-width:600px){main{margin:0;padding:24px;border-radius:0}h1{font-size:26px}}</style></head>
<body><main>${approved ? '' : '<p class="draft"><strong>REVIEW DRAFT — NOT PUBLISHED OR APPROVED FOR STORE SUBMISSION</strong></p>'}${body}${request}<nav aria-label="Policies">${links} · <a href="policies.html">All policies</a> · <a href="https://washkrew.com">WashKrew website</a></nav><p>Contact <a href="mailto:info@washkrew.com">info@washkrew.com</a> · <a href="tel:+918088516875">+91 80885 16875</a></p></main></body></html>\n`);
}
console.log(`${approved ? 'Approved pages staged (not deployed)' : 'Draft preview only'}: ${destination}`);
