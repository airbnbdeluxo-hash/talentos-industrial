// Catálogo inicial curado para ocupações e habilidades industriais brasileiras.
// Não pretende substituir a classificação CBO oficial; a base é extensível.
export const INDUSTRIAL_OCCUPATIONS = [
  "Almoxarife",
  "Analista de Controle de Qualidade",
  "Analista de Logística",
  "Analista de PCP",
  "Analista de Processos",
  "Aprendiz Industrial",
  "Auxiliar de Manutenção",
  "Auxiliar de Produção",
  "Caldeireiro",
  "Coordenador Industrial",
  "Desenhista Técnico Mecânico",
  "Eletricista Industrial",
  "Encarregado de Produção",
  "Engenheiro de Processos",
  "Engenheiro de Produção",
  "Engenheiro Eletricista",
  "Engenheiro Mecânico",
  "Estoquista",
  "Ferramenteiro",
  "Fresador Mecânico",
  "Gerente Industrial",
  "Inspetor de Qualidade",
  "Inspetor de Soldagem",
  "Instrumentista Industrial",
  "Líder de Produção",
  "Mecânico de Manutenção Industrial",
  "Mecânico Industrial",
  "Metrologista",
  "Montador Industrial",
  "Operador CNC",
  "Operador de Calandra",
  "Operador de Centro de Usinagem",
  "Operador de Empilhadeira",
  "Operador de Injetora",
  "Operador de Ponte Rolante",
  "Operador de Prensa",
  "Operador de Produção",
  "Operador de Torno Convencional",
  "Pintor Industrial",
  "Planejador de Manutenção",
  "Programador CNC",
  "Programador de CLP",
  "Projetista Mecânico",
  "Soldador",
  "Soldador MIG/MAG",
  "Soldador TIG",
  "Supervisor de Manutenção",
  "Supervisor de Produção",
  "Técnico de Automação Industrial",
  "Técnico de Manutenção",
  "Técnico de Qualidade",
  "Técnico de Segurança do Trabalho",
  "Técnico em Eletrotécnica",
  "Técnico em Mecânica",
  "Técnico em Mecatrônica",
  "Torneiro Mecânico"
] as const;

export const INDUSTRIAL_SKILLS = [
  "5S",
  "Análise de Falhas",
  "Automação Industrial",
  "Caldeiraria",
  "CLP",
  "CNC",
  "Comandos Elétricos",
  "Controle de Qualidade",
  "Controle Dimensional",
  "Corte e Dobra",
  "Desenho Técnico",
  "Elétrica",
  "Eletricidade Industrial",
  "Eletropneumática",
  "Equipamentos de Medição",
  "FMEA",
  "Fresamento",
  "Gestão de Estoques",
  "Hidráulica",
  "Inspeção de Qualidade",
  "Instrumentação Industrial",
  "Interpretação de Desenho Técnico",
  "ISO 9001",
  "Lean Manufacturing",
  "Leitura de Instrumentos",
  "Liderança de Equipes",
  "Manutenção Corretiva",
  "Manutenção Preditiva",
  "Manutenção Preventiva",
  "Mecânica",
  "Mecânica Industrial",
  "Metrologia",
  "MIG/MAG",
  "Montagem Industrial",
  "NR-10",
  "NR-12",
  "NR-33",
  "NR-35",
  "Operação de Empilhadeira",
  "Operação de Máquinas",
  "PCP",
  "Pneumática",
  "Programação CNC",
  "Programação de CLP",
  "Projetos Mecânicos",
  "Qualidade Industrial",
  "Segurança do Trabalho",
  "Setup de Máquinas",
  "Soldagem Industrial",
  "SolidWorks",
  "TIG",
  "Torno CNC",
  "Torno Convencional",
  "Usinagem",
  "WCM"
] as const;

export const SHIFT_OPTIONS = [
  "1º turno",
  "2º turno",
  "3º turno",
  "Turno administrativo",
  "Turno da manhã",
  "Turno da tarde",
  "Turno da noite",
  "Turno integral",
  "Escala 5x2",
  "Escala 6x1",
  "Escala 12x36",
  "Horário flexível",
  "Qualquer turno"
] as const;

export const normalizeSelection = (value: string) =>
  value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim().toLocaleLowerCase('pt-BR');

export function uniqueCatalogOptions(...lists: ReadonlyArray<readonly string[]>): string[] {
  const found = new Map<string, string>();
  for (const list of lists) {
    for (const item of list) {
      const label = item.trim();
      const key = normalizeSelection(label);
      if (key && !found.has(key)) found.set(key, label);
    }
  }
  return Array.from(found.values()).sort((a, b) => a.localeCompare(b, 'pt-BR'));
}

export function parseBrazilianMoney(input: string | number): number {
  if (typeof input === 'number') return Number.isFinite(input) ? Math.max(0, input) : 0;
  const value = input.replace(/[^\d.,-]/g, '').trim();
  if (!value) return 0;
  let normalized = value;
  if (value.includes(',')) normalized = value.replace(/\./g, '').replace(',', '.');
  else if (/^\d{1,3}(\.\d{3})+$/.test(value)) normalized = value.replace(/\./g, '');
  const amount = Number(normalized);
  return Number.isFinite(amount) ? Math.max(0, amount) : 0;
}

export function formatBrazilianMoney(input: string | number): string {
  if (typeof input === 'string' && !input.trim()) return '';
  return parseBrazilianMoney(input).toLocaleString('pt-BR', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}
