import React from 'react';
import {reportClientError} from './lib/observability';

type State = { hasError: boolean; reference: string };

function makeReference() {
  return 'TAL-' + Date.now().toString(36).toUpperCase();
}

export class ErrorBoundary extends React.Component<React.PropsWithChildren, State> {
  state: State = { hasError: false, reference: '' };

  static getDerivedStateFromError(): State {
    return { hasError: true, reference: makeReference() };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.error('[TalentOS] Falha de interface', {
      reference: this.state.reference,
      message: error.message,
      componentStack: info.componentStack,
    });
    void reportClientError({
      source: 'react_error_boundary',
      error,
      reference: this.state.reference,
    });
  }

  private reload = () => {
    window.location.reload();
  };

  render() {
    if (!this.state.hasError) return this.props.children;

    return (
      <main className="fatal-error-shell">
        <section className="card fatal-error-card" role="alert">
          <div className="eyebrow">TALENTOS INDUSTRIAL</div>
          <h1>Não foi possível carregar esta tela</h1>
          <p>Ocorreu uma falha inesperada na interface. Seus dados não foram apagados.</p>
          <div className="fatal-error-reference">
            <span>Referência</span>
            <b>{this.state.reference}</b>
          </div>
          <button className="primary" onClick={this.reload}>Recarregar o TalentOS</button>
        </section>
      </main>
    );
  }
}
