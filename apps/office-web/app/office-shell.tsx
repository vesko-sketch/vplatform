'use client';

import { useEffect, useState, type ReactNode } from 'react';

interface Firm {
  code: string;
  id: string;
  name: string;
  shortName: string | null;
}

interface Bootstrap {
  firms: Firm[];
  identity: { platformUserId: string; preferredUsername?: string };
}

interface FirmContext {
  authorizationLevel: 'base';
  firm: Firm;
  permissions: string[];
}

export function OfficeShell(): ReactNode {
  const [bootstrap, setBootstrap] = useState<Bootstrap | null>(null);
  const [context, setContext] = useState<FirmContext | null>(null);
  const [selectedFirmId, setSelectedFirmId] = useState('');
  const [status, setStatus] = useState<
    'loading' | 'authenticated' | 'unauthenticated' | 'unavailable'
  >('loading');

  useEffect(() => {
    void fetch('/api/office/bootstrap', { cache: 'no-store' }).then(async (response) => {
      if (response.status === 401) return setStatus('unauthenticated');
      if (!response.ok) return setStatus('unavailable');
      const value = (await response.json()) as Bootstrap;
      setBootstrap(value);
      setSelectedFirmId(value.firms.length === 1 ? (value.firms[0]?.id ?? '') : '');
      setStatus('authenticated');
    });
  }, []);

  useEffect(() => {
    if (selectedFirmId === '') return setContext(null);
    void fetch(`/api/office/firms/${encodeURIComponent(selectedFirmId)}/context`, {
      cache: 'no-store',
    }).then(async (response) =>
      setContext(response.ok ? ((await response.json()) as FirmContext) : null),
    );
  }, [selectedFirmId]);

  if (status === 'loading')
    return (
      <main>
        <h1>V Office</h1>
        <p>Loading authenticated session…</p>
      </main>
    );
  if (status === 'unauthenticated')
    return (
      <main>
        <h1>V Office</h1>
        <p>Sign in to access your firms.</p>
        <a className="button" href="/auth/login">
          Sign in with V Platform
        </a>
      </main>
    );
  if (status === 'unavailable' || bootstrap === null)
    return (
      <main>
        <h1>V Office</h1>
        <p>Authorization services are unavailable. Access remains denied.</p>
        <a href="/auth/login">Try signing in again</a>
      </main>
    );

  const permissions = new Set(context?.permissions ?? []);
  const navigation = [
    ['Firms', 'firms.view'],
    ['Tasks', 'tasks.view'],
    ['Documents', 'documents.view'],
    ['Review', 'review.view'],
    ['Archive', 'archive.view'],
    ['Administration', 'users.view'],
  ].filter(([, permission]) => permission !== undefined && permissions.has(permission));

  return (
    <main>
      <header>
        <div>
          <p className="eyebrow">Authenticated V Platform session</p>
          <h1>V Office</h1>
          <p>{bootstrap.identity.preferredUsername ?? bootstrap.identity.platformUserId}</p>
        </div>
        <form action="/auth/logout" method="post">
          <button type="submit">Sign out</button>
        </form>
      </header>
      <section>
        <label htmlFor="firm">Current firm</label>
        <select
          id="firm"
          value={selectedFirmId}
          onChange={(event) => setSelectedFirmId(event.target.value)}
        >
          <option value="">Select a firm</option>
          {bootstrap.firms.map((firm) => (
            <option key={firm.id} value={firm.id}>
              {firm.code} — {firm.name}
            </option>
          ))}
        </select>
        <p>Firm selection is a convenience; Office API revalidates every request.</p>
      </section>
      {context === null ? null : (
        <>
          <nav aria-label="Office modules">
            {navigation.map(([label]) => (
              <span key={label}>{label}</span>
            ))}
          </nav>
          <section>
            <h2>{context.firm.name}</h2>
            <p>{context.permissions.length} base OFFICE permissions</p>
            <p>Resource and lifecycle policy is still required for final operations.</p>
          </section>
        </>
      )}
    </main>
  );
}
