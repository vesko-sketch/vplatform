'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState, type FormEvent, type ReactNode } from 'react';
import { adminFetch, invitationLabel, json } from '../admin-client';
import type { PermissionContext, User } from '../admin-types';

export function UsersPage(): ReactNode {
  const [users, setUsers] = useState<User[]>([]);
  const [permissions, setPermissions] = useState<string[]>([]);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState('all');
  const [invite, setInvite] = useState(false);
  const [secret, setSecret] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  async function load(): Promise<void> {
    try {
      const [items, context] = await Promise.all([
        adminFetch<User[]>('/api/office/admin/users'),
        adminFetch<PermissionContext>('/api/office/application-permissions'),
      ]);
      setUsers(items);
      setPermissions(context.permissions);
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Потребителите не са достъпни');
    } finally {
      setLoading(false);
    }
  }
  useEffect(() => {
    void load();
  }, []);
  const visible = useMemo(
    () =>
      users.filter(
        (user) =>
          `${user.displayName ?? ''} ${user.email}`.toLowerCase().includes(query.toLowerCase()) &&
          (filter === 'all' || user.lifecycleStatus === filter),
      ),
    [users, query, filter],
  );
  async function create(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    try {
      const result = await adminFetch<{ invitationUrl?: string }>(
        '/api/office/admin/users/invitations',
        json('POST', { displayName: data.get('displayName'), email: data.get('email') }),
      );
      setInvite(false);
      setSecret(result.invitationUrl ?? null);
      await load();
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Поканата не беше създадена');
    }
  }
  return (
    <>
      <div className="page-header">
        <div>
          <p className="eyebrow">Администрация</p>
          <h1>Потребители</h1>
          <p>Идентичност, покани и отделно предоставен достъп.</p>
        </div>
        {permissions.includes('users.invite') ? (
          <button onClick={() => setInvite(true)}>Покани потребител</button>
        ) : null}
      </div>
      {error ? (
        <div className="alert error" role="alert">
          {error}
        </div>
      ) : null}
      <div className="toolbar">
        <label>
          Търсене
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Име или email"
          />
        </label>
        <label>
          Жизнен цикъл
          <select value={filter} onChange={(event) => setFilter(event.target.value)}>
            <option value="all">Всички</option>
            <option value="ACTIVE">Активни</option>
            <option value="INVITED">Поканени</option>
            <option value="DISABLED">Деактивирани</option>
          </select>
        </label>
      </div>
      {loading ? (
        <p className="empty">Зареждане…</p>
      ) : visible.length === 0 ? (
        <p className="empty">Няма потребители.</p>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Потребител</th>
                <th>Email</th>
                <th>Жизнен цикъл</th>
                <th>Идентичност</th>
                <th>Покана</th>
                <th>Създаден</th>
                <th>
                  <span className="sr-only">Действие</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {visible.map((user) => (
                <tr key={user.id}>
                  <td>
                    <strong>{user.displayName ?? 'Без име'}</strong>
                  </td>
                  <td>{user.email}</td>
                  <td>
                    <Lifecycle value={user.lifecycleStatus} />
                  </td>
                  <td>{user.identityLinked ? 'Свързана' : 'Няма'}</td>
                  <td>
                    {invitationLabel(user.currentInvitationState, user.currentInvitationExpiresAt)}
                  </td>
                  <td>{formatDate(user.createdAt)}</td>
                  <td>
                    <Link href={`/administration/users/${user.id}`}>Отвори</Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {invite ? (
        <div className="dialog-backdrop">
          <div className="dialog" role="dialog" aria-modal="true" aria-labelledby="invite-title">
            <div className="dialog-header">
              <h2 id="invite-title">Покани потребител</h2>
              <button className="icon-button" aria-label="Затвори" onClick={() => setInvite(false)}>
                ×
              </button>
            </div>
            <form onSubmit={(event) => void create(event)}>
              <label>
                Име
                <input name="displayName" required />
              </label>
              <label>
                Email
                <input name="email" type="email" required />
              </label>
              <p className="hint">Достъпът до фирми и ролите не се предоставят автоматично.</p>
              <div className="dialog-actions">
                <button type="button" className="secondary" onClick={() => setInvite(false)}>
                  Отказ
                </button>
                <button type="submit">Създай покана</button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
      {secret ? (
        <div className="dialog-backdrop">
          <div className="dialog" role="dialog" aria-modal="true" aria-labelledby="secret-title">
            <h2 id="secret-title">Връзка за разработка</h2>
            <p className="alert warning">
              Покажете и копирайте сега. Връзката не се пази в браузъра и автоматично изпращане още
              няма.
            </p>
            <textarea readOnly value={secret} aria-label="Еднократна връзка за покана" />
            <div className="dialog-actions">
              <button
                className="secondary"
                onClick={() => void navigator.clipboard.writeText(secret)}
              >
                Копирай
              </button>
              <button onClick={() => setSecret(null)}>Затвори и изчисти</button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
export function Lifecycle({ value }: { value: User['lifecycleStatus'] }): ReactNode {
  return (
    <span
      className={`status ${value === 'ACTIVE' ? 'success' : value === 'DISABLED' ? 'danger' : 'warning'}`}
    >
      {value === 'ACTIVE' ? 'Активен' : value === 'DISABLED' ? 'Деактивиран' : 'Поканен'}
    </span>
  );
}
function formatDate(value: string): string {
  return new Intl.DateTimeFormat('bg-BG', { dateStyle: 'medium' }).format(new Date(value));
}
