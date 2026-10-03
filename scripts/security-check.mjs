import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const tracked = execFileSync('git', ['ls-files', '-z'], { encoding: 'utf8' })
  .split('\0')
  .filter(Boolean);

const failures = [];

const forbiddenEnv = tracked.filter((file) =>
  /(^|\/)\.env(?:\.|$)/.test(file) &&
  !/(^|\/)\.env\.example$/.test(file)
);
if (forbiddenEnv.length) {
  failures.push('Arquivos de ambiente rastreados: ' + forbiddenEnv.join(', '));
}

const textFiles = tracked.filter((file) =>
  /\.(?:[cm]?[jt]sx?|json|ya?ml|toml|md|html|css|txt|sql)$/i.test(file) &&
  file !== 'package-lock.json'
);

const secretPatterns = [
  ['Supabase secret key', new RegExp('sb' + '_secret_[A-Za-z0-9_-]{20,}', 'g')],
  ['GitHub token', new RegExp('gh' + 'p_[A-Za-z0-9]{20,}', 'g')],
  ['GitHub fine-grained token', new RegExp('github' + '_pat_[A-Za-z0-9_]{20,}', 'g')],
  ['AWS access key', new RegExp('AKIA[0-9A-Z]{16}', 'g')],
  ['Stripe live secret', new RegExp('sk' + '_live_[A-Za-z0-9]{16,}', 'g')],
  ['Private key', /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g],
];

for (const file of textFiles) {
  let content;
  try {
    content = readFileSync(file, 'utf8');
  } catch {
    continue;
  }

  for (const [label, pattern] of secretPatterns) {
    pattern.lastIndex = 0;
    if (pattern.test(content)) failures.push(label + ' encontrado em ' + file);
  }

  if (file.startsWith('src/')) {
    if (/SUPABASE_SERVICE_ROLE_KEY/.test(content)) {
      failures.push('service role referenciado no frontend: ' + file);
    }
    if (/VITE_[A-Z0-9_]*(?:SECRET|SERVICE_ROLE|PRIVATE|TOKEN)/.test(content)) {
      failures.push('variável sensível exposta via VITE_*: ' + file);
    }
    if (/dangerouslySetInnerHTML/.test(content)) failures.push('dangerouslySetInnerHTML em ' + file);
    if (/\beval\s*\(/.test(content)) failures.push('eval() em ' + file);
    if (/\bnew\s+Function\s*\(/.test(content)) failures.push('new Function() em ' + file);
  }
}

if (failures.length) {
  console.error('\nSecurity scan FAILED');
  for (const failure of [...new Set(failures)]) console.error(' - ' + failure);
  process.exit(1);
}

console.log('Security scan OK: nenhum segredo evidente ou API perigosa encontrada no frontend.');
