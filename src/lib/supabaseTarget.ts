// Pure configuration selection: preview and local builds must never silently
// reuse the production Supabase project.
export type SupabaseClientTargetOptions = {
  isProductionBuild: boolean;
  deploymentEnvironment?: string;
  hostname?: string;
  configuredUrl?: string;
  configuredKey?: string;
  productionUrl: string;
  productionPublishableKey: string;
};

type PublicClientConfig = { url: string | undefined; key: string | undefined };

const productionHosts = new Set([
  'talentos-industrial.vercel.app',
  'talentos-industrial-airbnbdeluxo-2819.vercel.app',
  'talentos-industrial-git-main-airbnbdeluxo-2819.vercel.app',
]);

const emptyConfig: PublicClientConfig = { url: undefined, key: undefined };

export function resolveSupabaseClientTarget(options: SupabaseClientTargetOptions): PublicClientConfig {
  const deployment = (options.deploymentEnvironment ?? '').trim().toLowerCase();
  const hostname = (options.hostname ?? '').trim().toLowerCase();
  const knownProductionDomain = productionHosts.has(hostname);
  const realProductionDeployment =
    options.isProductionBuild &&
    (deployment === 'production' || (!deployment && knownProductionDomain));

  if (realProductionDeployment) {
    // Preserve the already-published production configuration.
    return { url: options.productionUrl, key: options.productionPublishableKey };
  }

  const url = options.configuredUrl?.trim().replace(/\/+$/, '');
  const key = options.configuredKey?.trim();
  if (!url || !key) return emptyConfig;

  try {
    const candidateHost = new URL(url).hostname.toLowerCase();
    const productionHost = new URL(options.productionUrl).hostname.toLowerCase();

    // Non-production runtimes must not reuse the production backend.
    if (candidateHost === productionHost) {
      return emptyConfig;
    }
  } catch {
    return emptyConfig;
  }

  return { url, key };
}
