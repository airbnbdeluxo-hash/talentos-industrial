import workerUrl from 'pdfjs-dist/build/pdf.worker.min.mjs?url';

export type ResumeDraft = {
  name: string;
  role: string;
  city: string;
  years: number;
  salary: number;
  preferredShifts: string[];
  skills: string[];
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
  if (!role) {
    role =
      lines.find((line) => {
        const n = normalize(line);
        return (
          line.length >= 5 &&
          line.length <= 80 &&
          !n.includes('@') &&
          !/curriculo|linkedin|telefone|celular|contato|email|endereco|cidade|experiencia|formacao|habilidades|competencias|resumo|perfil/.test(n)
        );
      }) ?? '';
  }

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

  const skills = Array.from(
    new Set(
      catalog
        .map((skill) => ({ skill, normalized: normalize(skill) }))
        .filter((entry) => entry.normalized && normalize(clean).includes(entry.normalized))
        .map((entry) => entry.skill)
    )
  );

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
    bio: summary,
    email,
    phone,
  };
}

export async function extractResumeText(file: File): Promise<string> {
  const lowerName = file.name.toLowerCase();
  if (file.size > 10 * 1024 * 1024) throw new Error('O currículo deve ter no máximo 10 MB.');

  if (lowerName.endsWith('.pdf') || file.type === 'application/pdf') {
    const pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
    const data = new Uint8Array(await file.arrayBuffer());
    pdfjs.GlobalWorkerOptions.workerSrc = workerUrl;
    const loadingTask = pdfjs.getDocument({ data });
    const pdf = await loadingTask.promise;
    const pages: string[] = [];
    for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber += 1) {
      const page = await pdf.getPage(pageNumber);
      const content = await page.getTextContent();
      const pageText = content.items
        .map((item: any) => ('str' in item ? item.str : ''))
        .join(' ');
      pages.push(pageText);
    }
    const output = cleanText(pages.join('\n'));
    if (!output) throw new Error('Esse PDF parece ser uma imagem digitalizada. Envie um PDF com texto selecionável ou um arquivo .docx.');
    return output;
  }

  if (lowerName.endsWith('.docx') || file.type === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
    const mammoth = await import('mammoth');
    const result = await mammoth.extractRawText({ arrayBuffer: await file.arrayBuffer() });
    const output = cleanText(result.value ?? '');
    if (!output) throw new Error('Não encontrei texto suficiente nesse arquivo Word.');
    return output;
  }

  throw new Error('Formato não suportado. Envie PDF ou Word (.docx).');
}

export async function parseResumeFile(file: File, catalog: string[] = []): Promise<ResumeDraft> {
  const text = await extractResumeText(file);
  return { ...parseResumeText(text, catalog), sourceFileName: file.name };
}

export function matchSkillToCatalog(value: string, catalog: string[]) {
  return canonicalSkill(value, catalog);
}
