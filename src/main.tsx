import React from "react";
import {createRoot} from "react-dom/client";
import App from "./App";
import {ErrorBoundary} from "./ErrorBoundary";
import {reportClientError} from "./lib/observability";
import "./styles.css";

window.addEventListener('error', event => {
  void reportClientError({source:'window_error', error:event.error ?? event.message});
});
window.addEventListener('unhandledrejection', event => {
  void reportClientError({source:'unhandled_rejection', error:event.reason});
});

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <ErrorBoundary>
      <App/>
    </ErrorBoundary>
  </React.StrictMode>
);
