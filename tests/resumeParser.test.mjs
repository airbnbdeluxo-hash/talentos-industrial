import test from 'node:test';
import assert from 'node:assert/strict';
import { parseResumeText, resumePdfPageText } from '../src/lib/resumeParser.ts';

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
