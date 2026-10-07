import { useMemo, useState } from 'react';
import { normalizeSelection, uniqueCatalogOptions } from '../lib/industrialCatalog';

type CatalogMultiSelectProps = {
  label: string;
  options: readonly string[];
  selected: readonly string[];
  onChange: (value: string[]) => void;
  hint?: string;
  maxItems?: number;
};

export function CatalogMultiSelect({ label, options, selected, onChange, hint, maxItems = 100 }: CatalogMultiSelectProps) {
  const [query, setQuery] = useState('');
  const catalog = useMemo(() => uniqueCatalogOptions(options), [options]);
  const display = useMemo(() => catalog.filter(item => normalizeSelection(item).includes(normalizeSelection(query))).slice(0, 120), [catalog, query]);
  const selectedCanonical = useMemo(() => new Set(selected.map(normalizeSelection)), [selected]);
  const toggle = (option: string) => {
    const enabled = selectedCanonical.has(normalizeSelection(option));
    if (enabled) onChange(selected.filter(x => normalizeSelection(x) !== normalizeSelection(option)));
    else if (selected.length < maxItems) onChange([...selected, option]);
  };

  return <fieldset className="catalog-picker">
    <legend>{label}</legend>
    <div className="catalog-selected">
      {selected.length ? selected.map(item => <button key={item} type="button" className="catalog-pill"
        aria-label={'Remover ' + item} onClick={() => toggle(item)}>{item} <span aria-hidden="true">×</span></button>)
        : <span className="catalog-empty">Nenhuma opção selecionada</span>}
    </div>
    <details className="catalog-expand">
      <summary>Escolher na lista ({selected.length} selecionada{selected.length === 1 ? '' : 's'})</summary>
      <label className="catalog-search-label">Buscar uma opção na lista
        <input type="search" value={query} onChange={event => setQuery(event.target.value)}
          placeholder="Buscar sem digitar um novo valor" autoComplete="off"/>
      </label>
      <div className="catalog-option-list" role="group" aria-label={label}>
        {display.length ? display.map(option => <label className="catalog-option" key={option}>
          <input type="checkbox" checked={selectedCanonical.has(normalizeSelection(option))} onChange={() => toggle(option)} />
          <span>{option}</span>
        </label>) : <p className="catalog-empty">Nenhuma opção do catálogo corresponde à busca.</p>}
      </div>
    </details>
    {hint && <small className="field-hint">{hint}</small>}
  </fieldset>;
}


type CatalogSingleSelectProps = {
  label: string;
  options: readonly string[];
  value: string;
  onChange: (value: string) => void;
  hint?: string;
  emptyLabel?: string;
};

export function CatalogSingleSelect({ label, options, value, onChange, hint, emptyLabel = 'Nenhuma opção' }: CatalogSingleSelectProps) {
  const [query,setQuery]=useState('');
  const catalog=useMemo(()=>uniqueCatalogOptions(options),[options]);
  const visible=useMemo(()=>catalog.filter(item=>normalizeSelection(item).includes(normalizeSelection(query))).slice(0,120),[catalog,query]);
  return <fieldset className="catalog-picker catalog-single">
    <legend>{label}</legend>
    <div className="catalog-selected">{value
      ? <button type="button" className="catalog-pill" onClick={()=>onChange('')} aria-label={'Limpar '+label}>{value} <span aria-hidden="true">×</span></button>
      : <span className="catalog-empty">{emptyLabel}</span>}
    </div>
    <details className="catalog-expand">
      <summary>{value?'Trocar opção':'Escolher na lista'}</summary>
      <label className="catalog-search-label">Buscar na lista
        <input type="search" value={query} onChange={event=>setQuery(event.target.value)} placeholder="Digite apenas para localizar" autoComplete="off"/>
      </label>
      <div className="catalog-option-list" role="radiogroup" aria-label={label}>
        {visible.map(option=><label className="catalog-option" key={option}>
          <input type="radio" name={'catalog-'+label.replace(/\s+/g,'-').toLowerCase()} checked={value===option}
            onChange={()=>{onChange(option);setQuery('')}}/>
          <span>{option}</span>
        </label>)}
      </div>
    </details>
    {hint&&<small className="field-hint">{hint}</small>}
  </fieldset>;
}
