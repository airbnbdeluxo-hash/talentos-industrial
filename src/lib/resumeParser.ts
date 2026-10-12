export type ResumeDraft = {
  name: string;
  role: string;
  city: string;
  years: number;
  salary: number;
  preferredShifts: string[];
  skills: string[];
  skillMentions: Array<{ skill: string; excerpt: string; confidence: number }>;
  bio: string;
  email?: string;
  phone?: string;
  sourceFileName?: string;
};

const normalize = (value: string) =>
  value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();

const cleanText = (value: string) =>
  value
    .replace(/\u00a0/g, ' ')
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .split('\n')
    .map((line) => line.replace(/[ \t]+/g, ' ').trim())
    .filter(Boolean)
    .join('\n')
    .trim();

const parseMoney = (value: string) => {
  const raw = value
    .replace(/R\$|BRL/gi, '')
    .replace(/\s/g, '')
    .replace(/\.(?=\d{3}(?:,|$))/g, '')
    .replace(',', '.')
    .replace(/[^\d.]/g, '');
  const amount = Number(raw);
  return Number.isFinite(amount) ? amount : 0;
};

const canonicalSkill = (candidate: string, catalog: string[]) => {
  const normalized = normalize(candidate);
  return catalog.find((name) => normalize(name) === normalized) ?? null;
};

const extractSection = (lines: string[], headings: string[]) => {
  const normalizedHeadings = headings.map(normalize);
  const start = lines.findIndex((line) => normalizedHeadings.some((heading) => normalize(line).startsWith(heading)));
  if (start < 0) return '';
  const result: string[] = [];
  for (let i = start + 1; i < lines.length; i += 1) {
    const line = lines[i];
    const n = normalize(line);
    if (
      n.length <= 55 &&
      /^[A-Z0-9À-Ú][A-Z0-9À-Ú .&/\-]+$/.test(line.replace(/[À-ÿ]/g, (char) => char.toUpperCase())) &&
      result.length > 0
    ) {
      break;
    }
    result.push(line);
  }
  return result.join(' ').slice(0, 1400);
};

export function parseResumeText(text: string, catalog: string[] = []): ResumeDraft {
  const clean = cleanText(text);
  const lines = clean.split('\n');
  const email = clean.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)?.[0] ?? '';
  const phone = clean.match(/(?:\+55\s?)?(?:\(?\d{2}\)?\s?)?(?:9\s?\d{4}|\d{4})[-\s]?\d{4}/)?.[0] ?? '';

  const name =
    lines.find((line) => {
      const n = normalize(line);
      return (
        line.length >= 5 &&
        line.length <= 70 &&
        !n.includes('@') &&
        !/curriculo|resume|linkedin|telefone|celular|contato|email|endereco|cidade/.test(n) &&
        line.split(' ').length >= 2 &&
        line.split(' ').length <= 5 &&
        /^[A-Za-zÀ-ÿ'\- ]+$/.test(line)
      );
    }) ?? '';

  const roleLabels = ['cargo', 'funcao', 'profissao', 'objetivo profissional', 'objetivo'];
  let role = '';
  for (let i = 0; i < lines.length; i += 1) {
    const n = normalize(lines[i]);
    const label = roleLabels.find((item) => n.startsWith(item));
    if (label) {
      const sameLine = lines[i].slice(label.length).replace(/^[:\-–—\s]+/, '').trim();
      role = sameLine || lines[i + 1] || '';
      if (role) break;
    }
  }
  // A name or arbitrary first line is not evidence of a professional role.
  // Leave unlabelled roles blank for the candidate to confirm.

  const cityMatch =
    clean.match(/(?:cidade|localizacao|residencia|endereco)\s*[:\-]?\s*([^\n,;]+?)(?:\s*[-,]\s*[A-Z]{2})?(?:\n|$)/i) ??
    clean.match(/([A-Za-zÀ-ÿ' .-]{3,50})\s*[-,]\s*(?:RS|SC|PR|SP|MG|RJ|ES|BA|PE|CE|GO|DF)\b/i);
  const city = cityMatch?.[1]?.trim() ?? '';

  const yearsMatches = [...clean.matchAll(/(\d{1,2}(?:[,.]\d)?)\s*(?:anos?|year[s]?)\s+(?:de\s+)?experi/gi)];
  const years = yearsMatches.length
    ? Math.max(...yearsMatches.map((match) => Number(match[1].replace(',', '.'))))
    : (() => {
        const exp = clean.match(/experi(?:e|ê)ncia[^\d]{0,30}(\d{1,2})(?:\s*anos?)/i);
        return exp ? Number(exp[1]) : 0;
      })();

  const salaryMatch = clean.match(/(?:pretens[aã]o|sal[aá]rio|remunera[cç][aã]o)[^\d]{0,30}(R\$\s?[\d.]+(?:,\d{2})?)/i);
  const salary = salaryMatch ? parseMoney(salaryMatch[1]) : 0;

  const shifts = Array.from(
    new Set(
      [...clean.matchAll(/([123](?:º|ª|°)?\s*turno|noturno|comercial)/gi)].map((m) =>
        m[1].replace(/\s+/g, ' ').trim()
      )
    )
  ).slice(0, 4);

  // Only match catalogued skills as complete terms. Substring matching turns
  // short skills (e.g. "CNC") into misleading results inside longer words.
  const normalizedLines = lines.map(line => normalize(line));
  const skillMentions = Array.from(
    new Map(
      catalog
        .map(skill => ({ skill, normalized: normalize(skill) }))
        .filter(entry => entry.normalized.length > 0)
        .flatMap(entry => {
          const escaped = entry.normalized.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
          const boundary = new RegExp('(^|[^a-z0-9])' + escaped + '(?=$|[^a-z0-9])', 'i');
          const lineIndex = normalizedLines.findIndex(line =>
            line.split(/[,;.]|\bmas\b|\bporem\b/).some(clause =>
              boundary.test(clause) &&
              !/\b(nao|sem|nenhum|nenhuma)\b|\b(quero|desejo|pretendo|busco)\s+(aprender|estudar)|interesse em aprender/.test(clause)
            )
          );
          if (lineIndex < 0) return [];
          const line = lines[lineIndex];
          const preceding = normalizedLines.slice(Math.max(0,lineIndex-3),lineIndex).join(' ');
          const confidence = /habilidades|competencias|conhecimentos|skills/.test(preceding) ? 0.8 : 0.6;
          return [[entry.skill, { skill:entry.skill, excerpt:line.slice(0,240), confidence }]] as const;
        })
    ).values()
  );
  const skills = skillMentions.map((mention) => mention.skill);

  const summary =
    extractSection(lines, ['resumo profissional', 'resumo', 'perfil profissional', 'perfil', 'sobre mim']) ||
    extractSection(lines, ['objetivo profissional', 'objetivo']);

  return {
    name,
    role,
    city,
    years: Number.isFinite(years) ? years : 0,
    salary,
    preferredShifts: shifts,
    skills,
    skillMentions,
    bio: summary,
    email,
    phone,
  };
}

// Shared check for both extraction and Storage upload. MIME and filenames
// supplied by browsers are untrusted; always identify the format from bytes.
// This lightweight check does not replace a malware scanner or ZIP bomb limits.
export async function validateResumeFileSignature(
  file: File,
  signal?: AbortSignal,
): Promise<'application/pdf' | 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'> {
  signal?.throwIfAborted();
  const lowerName = file.name.toLowerCase();
  const isPdf = lowerName.endsWith('.pdf');
  const isDocx = lowerName.endsWith('.docx');
  if (!isPdf && !isDocx) throw new Error('Formato não suportado. Envie PDF ou Word (.docx).');
  if (file.size === 0) throw new Error('O arquivo do currículo está vazio.');
  if (file.size > 10 * 1024 * 1024) throw new Error('O currículo deve ter no máximo 10 MB.');

  const header = new Uint8Array(await file.slice(0, 1024).arrayBuffer());
  signal?.throwIfAborted();
  const validPdf = isPdf && header.some((byte, index) =>
    byte === 0x25 && header[index + 1] === 0x50 && header[index + 2] === 0x44 &&
    header[index + 3] === 0x46 && header[index + 4] === 0x2d
  );
  const validDocx = isDocx && header[0] === 0x50 && header[1] === 0x4b &&
    header[2] === 0x03 && header[3] === 0x04;
  if (!validPdf && !validDocx) throw new Error('O arquivo não corresponde a um PDF ou Word (.docx) válido.');

  return validPdf
    ? 'application/pdf'
    : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
}

export async function extractResumeText(file: File, signal?: AbortSignal): Promise<string> {
  const contentType = await validateResumeFileSignature(file, signal);
  const isPdf = contentType === 'application/pdf';
  const isDocx = contentType === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  if (isPdf) {
    const pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
    const { default: workerUrl } = await import('pdfjs-dist/build/pdf.worker.min.mjs?url');
    const data = new Uint8Array(await file.arrayBuffer());
    signal?.throwIfAborted();
    pdfjs.GlobalWorkerOptions.workerSrc = workerUrl;
    const loadingTask = pdfjs.getDocument({ data });
    const cancel = () => { void loadingTask.destroy().catch(() => {}); };
    signal?.addEventListener('abort', cancel, { once: true });
    try {
    const pdf = await loadingTask.promise;
    signal?.throwIfAborted();
    const pages: string[] = [];
    for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber += 1) {
      signal?.throwIfAborted();
      const page = await pdf.getPage(pageNumber);
      const content = await page.getTextContent();
      const pageText = resumePdfPageText(content.items);
      pages.push(pageText);
    }
    signal?.throwIfAborted();
    const output = cleanText(pages.join('\n'));
    if (!output) throw new Error('Esse PDF parece ser uma imagem digitalizada. Envie um PDF com texto selecionável ou um arquivo .docx.');
    return output;
    } finally {
      signal?.removeEventListener('abort', cancel);
      await loadingTask.destroy();
    }
  }

  if (isDocx) {
    const mammoth = await import('mammoth');
    signal?.throwIfAborted();
    const arrayBuffer = await file.arrayBuffer();
    signal?.throwIfAborted();
    const result = await mammoth.extractRawText({ arrayBuffer });
    signal?.throwIfAborted();
    const output = cleanText(result.value ?? '');
    if (!output) throw new Error('Não encontrei texto suficiente nesse arquivo Word.');
    return output;
  }

  throw new Error('Formato não suportado. Envie PDF ou Word (.docx).');
}

// PDF line boundaries separate names, labels and section headings.
// Flattening a page into one line makes those fields indistinguishable.
export function resumePdfPageText(items: unknown[]): string {
  return items.map(item => {
    if (!item || typeof item !== 'object' || !('str' in item) || typeof item.str !== 'string') return '';
    return item.str + ('hasEOL' in item && item.hasEOL ? '\n' : ' ');
  }).join('');
}

export async function parseResumeFile(file: File, catalog: string[] = [], signal?: AbortSignal): Promise<ResumeDraft> {
  const text = await extractResumeText(file, signal);
  signal?.throwIfAborted();
  return { ...parseResumeText(text, catalog), sourceFileName: file.name };
}

export function matchSkillToCatalog(value: string, catalog: string[]) {
  return canonicalSkill(value, catalog);
}
