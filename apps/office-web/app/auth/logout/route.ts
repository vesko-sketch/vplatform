import { redirect } from 'next/navigation';

import { loadOfficeWebConfig } from '../../../lib/oidc.config';
import { getOidcConfiguration, oidc } from '../../../lib/oidc';
import { getOfficeSession } from '../../../lib/session';

export async function POST(): Promise<never> {
  const config = loadOfficeWebConfig();
  (await getOfficeSession()).destroy();
  redirect(
    oidc
      .buildEndSessionUrl(await getOidcConfiguration(), {
        client_id: config.clientId,
        post_logout_redirect_uri: config.baseUrl,
      })
      .toString(),
  );
}
