'use client';

import Link from 'next/link';
import { useEffect, useState, type ReactNode } from 'react';
import { adminFetch, invitationLabel, json } from '../../admin-client';
import type { Invitation, PermissionContext, User, UserAccess } from '../../admin-types';
import { Lifecycle } from '../users-page';

export function UserDetail({ userId }: { userId: string }): ReactNode {
  const [user, setUser] = useState<User | null>(null);
  const [access, setAccess] = useState<UserAccess | null>(null);
  const [invitations, setInvitations] = useState<Invitation[]>([]);
  const [permissions, setPermissions] = useState<string[]>([]);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [secret, setSecret] = useState<string | null>(null);
  async function load(): Promise<void> {
    setError('');
    try {
      const [person, relationships, context] = await Promise.all([
        adminFetch<User>(`/api/office/admin/users/${userId}`),
        adminFetch<UserAccess>(`/api/office/admin/users/${userId}/access`),
        adminFetch<PermissionContext>('/api/office/application-permissions'),
      ]);
      setUser(person);
      setAccess(relationships);
      setPermissions(context.permissions);
      if (context.permissions.includes('users.invitations.view'))
        setInvitations(
          await adminFetch<Invitation[]>(`/api/office/admin/users/${userId}/invitations`),
        );
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Потребителят не е достъпен');
    }
  }
  useEffect(() => {
    void load();
  }, [userId]);
  async function action(path: string, body?: unknown): Promise<void> {
    try {
      const result = await adminFetch<{ invitationUrl?: string }>(
        `/api/office/admin/users/${userId}/${path}`,
        json('POST', body ?? {}),
      );
      if (result?.invitationUrl) setSecret(result.invitationUrl);
      setNotice('Операцията е изпълнена.');
      await load();
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Операцията е отказана');
    }
  }
  if (!user || !access)
    return (
      <div className="state-panel">
        <h1>{error ? 'Потребителят не е достъпен' : 'Зареждане…'}</h1>
        <p>{error || 'Зареждане на профила.'}</p>
      </div>
    );
  const noAuthorization = access.applicationRoles.length === 0 && access.firms.length === 0;
  return (
    <>
      <div className="breadcrumbs">
        <Link href="/administration/users">Потребители</Link>
        <span>/</span>
        <span>{user.displayName ?? user.email}</span>
      </div>
      <div className="page-header">
        <div>
          <p className="eyebrow">Потребител</p>
          <h1>{user.displayName ?? 'Без име'}</h1>
          <p>{user.email}</p>
        </div>
        <Lifecycle value={user.lifecycleStatus} />
      </div>
      {error ? (
        <div className="alert error" role="alert">
          {error}
          <button className="text-button" onClick={() => void load()}>
            Обнови
          </button>
        </div>
      ) : null}
      {notice ? (
        <div className="alert success" role="status">
          {notice}
        </div>
      ) : null}
      <nav className="tab-nav">
        <a href="#overview">Преглед</a>
        <a href="#invitation">Покани</a>
        <a href="#access">Достъп</a>
      </nav>
      <section id="overview" className="panel">
        <div className="section-heading">
          <div>
            <h2>Общ преглед</h2>
            <p>Активната идентичност не предоставя автоматично бизнес достъп.</p>
          </div>
          <div className="inline-actions">
            {user.lifecycleStatus === 'ACTIVE' && permissions.includes('users.platform.disable') ? (
              <ReasonButton
                label="Деактивирай"
                danger
                onConfirm={(reason) => {
                  void action('disable', { expectedRowVersion: user.rowVersion, reason });
                }}
              />
            ) : user.lifecycleStatus === 'DISABLED' &&
              permissions.includes('users.platform.reactivate') ? (
              <ReasonButton
                label="Реактивирай"
                onConfirm={(reason) => {
                  void action('reactivate', { expectedRowVersion: user.rowVersion, reason });
                }}
              />
            ) : null}
          </div>
        </div>
        <dl className="details-grid">
          <Detail label="Email" value={user.email} />
          <Detail label="Свързана идентичност" value={user.identityLinked ? 'Да' : 'Не'} />
          <Detail label="Създаден" value={date(user.createdAt)} />
          <Detail label="Обновен" value={date(user.updatedAt)} />
        </dl>
        {noAuthorization ? (
          <div className="alert neutral">
            <strong>Няма предоставена авторизация.</strong>
            <span>Потребителят няма application роли, фирмен достъп или фирмени роли.</span>
          </div>
        ) : null}
      </section>
      <section id="invitation" className="panel">
        <div className="section-heading">
          <div>
            <h2>Покани</h2>
            <p>История на първоначалното свързване на идентичност.</p>
          </div>
          {permissions.includes('users.invite') && user.lifecycleStatus === 'INVITED' ? (
            <button className="secondary" onClick={() => void action('invitations/reissue')}>
              Преиздай покана
            </button>
          ) : null}
        </div>
        {invitations.length === 0 ? (
          <p className="empty">Няма покани.</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Статус</th>
                  <th>Email</th>
                  <th>Изтича</th>
                  <th>Обновена</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {invitations.map((invitation) => (
                  <tr key={invitation.id}>
                    <td>{invitationLabel(invitation.status, invitation.expiresAt)}</td>
                    <td>{invitation.invitedEmail}</td>
                    <td>{date(invitation.expiresAt)}</td>
                    <td>{date(invitation.updatedAt)}</td>
                    <td>
                      {invitation.status === 'PENDING' &&
                      permissions.includes('users.invitations.cancel') ? (
                        <ReasonButton
                          compact
                          label="Откажи"
                          onConfirm={(reason) => {
                            void action(`invitations/${invitation.id}/cancel`, {
                              expectedRowVersion: invitation.rowVersion,
                              reason,
                            });
                          }}
                        />
                      ) : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
      <section id="access" className="panel">
        <div className="section-heading">
          <div>
            <h2>Авторизационни отношения</h2>
            <p>Нивата са независими и не се подразбират едно от друго.</p>
          </div>
          <Link className="button secondary" href="/administration/firms">
            Предостави фирмен достъп
          </Link>
        </div>
        <div className="access-columns">
          <AccessGroup title="Application роли" empty="Няма application роли">
            {access.applicationRoles.map((role) => (
              <div className="relationship" key={`${role.applicationCode}-${role.roleCode}`}>
                <strong>{role.applicationCode}</strong>
                <span>{role.roleCode}</span>
              </div>
            ))}
          </AccessGroup>
          <AccessGroup title="Фирмен/application достъп" empty="Няма фирмен достъп">
            {access.firms.flatMap((firm) =>
              firm.applications.map((application) => (
                <div
                  className="relationship"
                  key={`${firm.firm.id}-${application.applicationCode}`}
                >
                  <strong>
                    {firm.firm.code} · {firm.firm.name}
                  </strong>
                  <span>{application.applicationCode}</span>
                </div>
              )),
            )}
          </AccessGroup>
          <AccessGroup title="Фирмени роли" empty="Няма фирмени роли">
            {access.firms.flatMap((firm) =>
              firm.roles.map((role) => (
                <div className="relationship" key={`${firm.firm.id}-${role.roleCode}`}>
                  <strong>{firm.firm.code}</strong>
                  <span>
                    {role.roleName} ({role.roleCode})
                  </span>
                </div>
              )),
            )}
          </AccessGroup>
        </div>
      </section>
      {secret ? (
        <div className="dialog-backdrop">
          <div className="dialog" role="dialog" aria-modal="true">
            <h2>Нова връзка за разработка</h2>
            <p className="alert warning">
              Предишната покана вече е невалидна. Копирайте тази връзка сега.
            </p>
            <textarea readOnly value={secret} />
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
function Detail({ label, value }: { label: string; value: string }): ReactNode {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  );
}
function AccessGroup({
  children,
  empty,
  title,
}: {
  children: ReactNode[];
  empty: string;
  title: string;
}): ReactNode {
  return (
    <div className="access-group">
      <h3>{title}</h3>
      {children.length ? children : <p className="empty compact">{empty}</p>}
    </div>
  );
}
function ReasonButton({
  compact = false,
  danger = false,
  label,
  onConfirm,
}: {
  compact?: boolean;
  danger?: boolean;
  label: string;
  onConfirm: (reason: string) => void;
}): ReactNode {
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState('');
  return (
    <>
      {
        <button
          className={`${danger ? 'danger' : 'secondary'} ${compact ? 'compact' : ''}`}
          onClick={() => setOpen(true)}
        >
          {label}
        </button>
      }
      {open ? (
        <div className="dialog-backdrop">
          <div className="dialog" role="dialog" aria-modal="true">
            <h3>{label}</h3>
            <label>
              Причина
              <textarea value={reason} onChange={(event) => setReason(event.target.value)} />
            </label>
            {danger ? (
              <p className="hint">Историята, идентичността и фирмените отношения се запазват.</p>
            ) : null}
            <div className="dialog-actions">
              <button className="secondary" onClick={() => setOpen(false)}>
                Отказ
              </button>
              <button
                className={danger ? 'danger' : ''}
                disabled={!reason.trim()}
                onClick={() => {
                  onConfirm(reason.trim());
                  setOpen(false);
                  setReason('');
                }}
              >
                Потвърди
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
function date(value: string): string {
  return new Intl.DateTimeFormat('bg-BG', { dateStyle: 'medium', timeStyle: 'short' }).format(
    new Date(value),
  );
}
