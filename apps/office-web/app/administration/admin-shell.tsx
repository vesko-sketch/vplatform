'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';

import { AdminApiError, adminFetch, hasAnyPermission } from './admin-client';
import type { PermissionContext } from './admin-types';

export function AdminShell({ children }: { children: ReactNode }): ReactNode {
  const pathname = usePathname();
  const [context, setContext] = useState<PermissionContext | null>(null);
  const [error, setError] = useState('');
  useEffect(() => {
    void adminFetch<PermissionContext>('/api/office/application-permissions')
      .then(setContext)
      .catch((value: unknown) => {
        if (value instanceof AdminApiError && value.status === 401) {
          window.location.assign('/auth/login');
          return;
        }
        setError(value instanceof Error ? value.message : 'Грешка');
      });
  }, []);
  if (error) return <StatePage title="Администрацията не е достъпна" detail={error} />;
  if (!context) return <StatePage title="Зареждане" detail="Проверка на разрешенията…" />;
  const canFirms = hasAnyPermission(context.permissions, ['firms.']);
  const canUsers = hasAnyPermission(context.permissions, ['users.']);
  if (!canFirms && !canUsers)
    return (
      <StatePage title="Няма достъп" detail="Нямате административни разрешения за V Office." />
    );
  return (
    <div className="app-shell">
      <aside className="sidebar">
        <Link className="brand" href="/">
          V Office
        </Link>
        <p className="nav-heading">Администрация</p>
        <nav aria-label="Администрация" className="side-nav">
          {canFirms ? (
            <Link
              className={pathname.startsWith('/administration/firms') ? 'active' : ''}
              href="/administration/firms"
            >
              Фирми
            </Link>
          ) : null}
          {canUsers ? (
            <Link
              className={pathname.startsWith('/administration/users') ? 'active' : ''}
              href="/administration/users"
            >
              Потребители
            </Link>
          ) : null}
        </nav>
        <div className="sidebar-footer">
          <a href="/">Работно пространство</a>
          <form action="/auth/logout" method="post">
            <button className="text-button" type="submit">
              Изход
            </button>
          </form>
        </div>
      </aside>
      <div className="content-shell">
        <header className="topbar">
          <div>
            <span className="eyebrow">V Platform</span>
            <strong>Управление на V Office</strong>
          </div>
          <span className="scope-label">APPLICATION</span>
        </header>
        <main className="admin-main">{children}</main>
      </div>
    </div>
  );
}

export function StatePage({ title, detail }: { detail: string; title: string }): ReactNode {
  return (
    <main className="state-page">
      <div className="state-panel">
        <h1>{title}</h1>
        <p>{detail}</p>
      </div>
    </main>
  );
}
