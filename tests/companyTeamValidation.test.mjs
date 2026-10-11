import test from 'node:test';
import assert from 'node:assert/strict';
import { isValidInvitationEmail } from '../supabase/functions/company-team/validation.ts';

test('accepts ordinary business emails, including s and plus aliases', () => {
  for (const email of ['recrutador@empresa.com.br', 'selecao@industria.com', 'equipe+recrutador@empresa.com']) {
    assert.equal(isValidInvitationEmail(email), true, email);
  }
});

test('rejects missing domain separators, whitespace and malformed addresses', () => {
  for (const email of ['', 'pessoa@empresa', 'pessoa empresa@dominio.com', 'pessoa@empresa.com\n', 'pessoa@@empresa.com', 'pessoa@empresa\\xcom', 'a'.repeat(250)+'@b.com']) {
    assert.equal(isValidInvitationEmail(email), false, email);
  }
});
