import test from 'node:test';
import assert from 'node:assert/strict';
import {matchesBrazilianCityFilter} from '../src/lib/industrialCatalog.ts';

test('city filtering respects state when both job and selected city include UF', () => {
  assert.equal(matchesBrazilianCityFilter('Santa Maria — RS', 'Santa Maria — RS'), true);
  assert.equal(matchesBrazilianCityFilter('Santa Maria — RS', 'Santa Maria — DF'), false);
  assert.equal(matchesBrazilianCityFilter('Santa Maria - RS', 'Santa Maria — DF'), false);
  assert.equal(matchesBrazilianCityFilter('Porto Alegre — RS', 'Porto Alegre — RS'), true);
});

test('legacy city records without UF retain exact city matching', () => {
  assert.equal(matchesBrazilianCityFilter('Caxias do Sul', 'Caxias do Sul — RS'), true);
  assert.equal(matchesBrazilianCityFilter('Caxias do Sul', 'Caxias — RS'), false);
  assert.equal(matchesBrazilianCityFilter('Nova Santa Maria', 'Santa Maria — RS'), false);
});

test('matching ignores accents, case and minor whitespace but not invalid city names', () => {
  assert.equal(matchesBrazilianCityFilter('  São José — SC  ', 'sao jose — SC'), true);
  assert.equal(matchesBrazilianCityFilter('', 'São José — SC'), false);
  assert.equal(matchesBrazilianCityFilter('São José — SC', ''), true);
});
