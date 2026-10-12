import test from 'node:test';
import assert from 'node:assert/strict';
import { parseResumeText, resumePdfPageText, parseResumeFile } from '../src/lib/resumeParser.ts';

test('missing role stays blank instead of copying the candidate name', () => {
  const draft = parseResumeText('Maria da Silva\nHabilidades\nMetrologia', ['Metrologia']);
  assert.equal(draft.name, 'Maria da Silva');
  assert.equal(draft.role, '');
});

test('negative and aspirational mentions are not presented as skills', () => {
  const draft = parseResumeText('Maria da Silva\nNão tenho experiência em CNC, mas domino Metrologia\nQuero aprender Soldagem TIG', ['CNC', 'Metrologia', 'Soldagem TIG']);
  assert.deepEqual(draft.skills, ['Metrologia']);
});

test('a later positive mention is retained after an earlier negative mention', () => {
  const draft = parseResumeText('Maria Silva\nAntes não conhecia CNC\nHabilidades atuais\nCNC', ['CNC']);
  assert.deepEqual(draft.skills, ['CNC']);
  assert.equal(draft.skillMentions[0].excerpt, 'CNC');
});

test('cancelled import does not begin reading a file', async () => {
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(parseResumeFile(new File(['synthetic'], 'resume.pdf'), [], controller.signal), {name:'AbortError'});
});

test('PDF line endings retain the candidate identity and labelled fields', () => {
  const text = resumePdfPageText([
    {str:'Maria da Silva',hasEOL:true},
    {str:'Cargo: Operador CNC',hasEOL:true},
    {str:'Cidade: Caxias do Sul',hasEOL:true},
    {str:'5 anos de experiência',hasEOL:true},
    {str:'HABILIDADES',hasEOL:true},
    {str:'Metrologia',hasEOL:true},
    {str:'CNC',hasEOL:true},
  ]);
  const draft = parseResumeText(text, ['Metrologia','CNC','Soldagem']);
  assert.equal(draft.name,'Maria da Silva');
  assert.equal(draft.role,'Operador CNC');
  assert.equal(draft.city,'Caxias do Sul');
  assert.equal(draft.years,5);
  assert.deepEqual(draft.skills,['Metrologia','CNC']);
  assert.ok(draft.skillMentions.every(mention=>!mention.excerpt.includes('\n')));
});

test('Word text remains editable and unknown skills are not invented', () => {
  const draft = parseResumeText('João de Souza\nObjetivo: Soldador\nCidade: Porto Alegre\nHabilidades\nSoldagem TIG', ['CNC','Metrologia']);
  assert.equal(draft.name,'João de Souza');
  assert.equal(draft.role,'Soldador');
  assert.equal(draft.city,'Porto Alegre');
  assert.deepEqual(draft.skills,[]);
});

test('does not infer a short skill from inside a longer word', () => {
  const draft = parseResumeText('Maria Silva\nExperiência: planejamento técnico e mecânica\nHabilidades: Metrologia', ['CNC','Metrologia','Técnica']);
  assert.deepEqual(draft.skills,['Metrologia']);
});

test('preserves independent source-line evidence for an extracted skill', () => {
  const draft = parseResumeText('Maria Silva\nHabilidades\nMetrologia e Soldagem TIG', ['Metrologia','Soldagem TIG']);
  assert.deepEqual(draft.skills,['Metrologia','Soldagem TIG']);
  assert.ok(draft.skillMentions.every(item=>item.excerpt==='Metrologia e Soldagem TIG'));
});

test('empty files are rejected before a document parser loads', async () => {
  await assert.rejects(parseResumeFile(new File([], 'curriculo.pdf')), /vazio/);
  await assert.rejects(parseResumeFile(new File([], 'curriculo.docx')), /vazio/);
});

test('a renamed executable or plain text is never parsed as a PDF or Word', async () => {
  await assert.rejects(parseResumeFile(new File(['not really PDF'], 'curriculo.pdf', {type:'application/pdf'})), /não corresponde/);
  await assert.rejects(parseResumeFile(new File(['not really DOCX'], 'curriculo.docx', {type:'application/vnd.openxmlformats-officedocument.wordprocessingml.document'})), /não corresponde/);
  await assert.rejects(parseResumeFile(new File(['%PDF-1.7'], 'curriculo.exe', {type:'application/pdf'})), /Formato não suportado/);
});

test('file names alone do not bypass validation', async () => {
  await assert.rejects(parseResumeFile(new File(['PK fake zip'], 'curriculo.docx')), /não corresponde/);
});
