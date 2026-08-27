'use client';

import Link from 'next/link';
import { useEffect, useState, type ReactNode } from 'react';
import { adminFetch, json } from '../../admin-client';
import type {
  Firm,
  PermissionContext,
  ReferenceItem,
  Relationship,
  Role,
  User,
} from '../../admin-types';
import { Status } from '../firms-page';

const refLabel = (item: ReferenceItem): string =>
  item.nameBg ?? item.name ?? item.shortName ?? item.code ?? item.iso2Code ?? item.id;

export function FirmDetail({ firmId }: { firmId: string }): ReactNode {
  const [firm, setFirm] = useState<Firm | null>(null);
  const [appPermissions, setAppPermissions] = useState<string[]>([]);
  const [firmPermissions, setFirmPermissions] = useState<string[]>([]);
  const [applications, setApplications] = useState<Relationship[]>([]);
  const [access, setAccess] = useState<Relationship[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [selectedUser, setSelectedUser] = useState('');
  const [userRoles, setUserRoles] = useState<Relationship[]>([]);
  const [refs, setRefs] = useState<Record<string, ReferenceItem[]>>({});
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  async function load(): Promise<void> {
    setError('');
    try {
      const [master, permissions] = await Promise.all([
        adminFetch<Firm>(`/api/office/admin/firms/${firmId}`),
        adminFetch<PermissionContext>('/api/office/application-permissions'),
      ]);
      setFirm(master);
      setAppPermissions(permissions.permissions);
      const optional = async <T,>(path: string, fallback: T): Promise<T> =>
        adminFetch<T>(path).catch(() => fallback);
      const [firmContext, apps, people, roleCatalog, countries, currencies, languages, legalForms] =
        await Promise.all([
          optional<{ permissions: string[] }>(`/api/office/firms/${firmId}/context`, {
            permissions: [],
          }),
          optional<Relationship[]>(`/api/office/admin/firms/${firmId}/applications`, []),
          optional<User[]>('/api/office/admin/users', []),
          optional<Role[]>('/api/office/admin/roles', []),
          optional<ReferenceItem[]>('/api/office/reference-data/countries', []),
          optional<ReferenceItem[]>('/api/office/reference-data/currencies', []),
          optional<ReferenceItem[]>('/api/office/reference-data/languages', []),
          optional<ReferenceItem[]>('/api/office/reference-data/legal-forms', []),
        ]);
      setFirmPermissions(firmContext.permissions);
      setApplications(apps);
      setUsers(people);
      setRoles(roleCatalog);
      setRefs({ countries, currencies, languages, legalForms });
      if (permissions.permissions.includes('firms.access.view'))
        setAccess(
          await optional<Relationship[]>(
            `/api/office/admin/firms/${firmId}/applications/OFFICE/users`,
            [],
          ),
        );
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Фирмата не е достъпна');
    }
  }
  useEffect(() => {
    void load();
  }, [firmId]);
  useEffect(() => {
    if (!selectedUser) return setUserRoles([]);
    void adminFetch<Relationship[]>(`/api/office/admin/firms/${firmId}/users/${selectedUser}/roles`)
      .then(setUserRoles)
      .catch(() => setUserRoles([]));
  }, [firmId, selectedUser]);

  async function command(
    path: string,
    body: unknown,
    method: 'PATCH' | 'POST' = 'POST',
  ): Promise<void> {
    try {
      await adminFetch(`/api/office/admin/firms/${firmId}/${path}`, json(method, body));
      setNotice('Промяната е записана.');
      await load();
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Операцията е отказана');
    }
  }
  if (!firm)
    return (
      <div className="state-panel">
        <h1>{error ? 'Фирмата не е достъпна' : 'Зареждане…'}</h1>
        <p>{error || 'Зареждане на фирмените данни.'}</p>
      </div>
    );
  const office = applications.find((item) => item.applicationCode === 'OFFICE' && item.isActive);
  const country = refs.countries?.find((item) => item.id === firm.countryId);
  const currency = refs.currencies?.find((item) => item.id === firm.baseCurrencyId);
  return (
    <>
      <div className="breadcrumbs">
        <Link href="/administration/firms">Фирми</Link>
        <span>/</span>
        <span>{firm.code}</span>
      </div>
      <div className="page-header">
        <div>
          <p className="eyebrow">Фирма</p>
          <h1>{firm.name}</h1>
          <p>
            {firm.code} · {firm.shortName ?? 'Без кратко име'}
          </p>
        </div>
        <Status active={firm.isActive} />
      </div>
      {error ? (
        <div className="alert error" role="alert">
          {error}
          <button className="text-button" onClick={() => void load()}>
            Зареди отново
          </button>
        </div>
      ) : null}
      {notice ? (
        <div className="alert success" role="status">
          {notice}
        </div>
      ) : null}
      <nav className="tab-nav" aria-label="Секции">
        <a href="#overview">Общ преглед</a>
        <a href="#profile">Профил</a>
        <a href="#identity">Идентичност</a>
        <a href="#settings">Настройки</a>
        <a href="#access">Достъп</a>
      </nav>
      <section id="overview" className="panel">
        <div className="section-heading">
          <div>
            <h2>Общ преглед</h2>
            <p>Основен запис в Shared Core.</p>
          </div>
          {firm.isActive && firmPermissions.includes('firms.disable') ? (
            <ReasonAction
              label="Деактивирай"
              danger
              onConfirm={(reason) => {
                void command('deactivate', { expectedRowVersion: firm.rowVersion, reason });
              }}
            />
          ) : !firm.isActive && appPermissions.includes('firms.activate') ? (
            <ReasonAction
              label="Активирай"
              onConfirm={(reason) => {
                void command('activate', { expectedRowVersion: firm.rowVersion, reason });
              }}
            />
          ) : null}
        </div>
        <dl className="details-grid">
          <Detail label="Държава" value={country ? refLabel(country) : firm.countryId} />
          <Detail label="Валута" value={currency ? refLabel(currency) : firm.baseCurrencyId} />
          <Detail label="Регистрация" value={firm.registrationNumber ?? '—'} />
          <Detail label="Часова зона" value={firm.timezone} />
          <Detail label="Последна промяна" value={formatDate(firm.updatedAt)} />
        </dl>
      </section>
      <section id="profile" className="panel">
        <h2>Профил</h2>
        {firmPermissions.includes('firms.edit') ? (
          <form
            className="form-grid"
            onSubmit={(event) => {
              event.preventDefault();
              const data = new FormData(event.currentTarget);
              void command(
                'profile',
                {
                  expectedRowVersion: firm.rowVersion,
                  name: data.get('name'),
                  short_name: data.get('short_name') || null,
                  default_language_id: data.get('default_language_id') || null,
                  timezone: data.get('timezone'),
                },
                'PATCH',
              );
            }}
          >
            <Input label="Име" name="name" defaultValue={firm.name} required />
            <Input label="Кратко име" name="short_name" defaultValue={firm.shortName ?? ''} />
            <RefSelect
              label="Език"
              name="default_language_id"
              value={firm.defaultLanguageId}
              items={refs.languages ?? []}
            />
            <Input label="Часова зона" name="timezone" defaultValue={firm.timezone} required />
            <FormSubmit />
          </form>
        ) : (
          <ReadOnlyNotice />
        )}
      </section>
      <section id="identity" className="panel">
        <h2>Идентичност</h2>
        {firmPermissions.includes('firms.identity.edit') ? (
          <form
            className="form-grid"
            onSubmit={(event) => {
              event.preventDefault();
              const data = new FormData(event.currentTarget);
              void command(
                'identity',
                {
                  expectedRowVersion: firm.rowVersion,
                  code: data.get('code'),
                  legal_form_id: data.get('legal_form_id') || null,
                  country_id: data.get('country_id'),
                  registration_number: data.get('registration_number') || null,
                },
                'PATCH',
              );
            }}
          >
            <Input label="Код" name="code" defaultValue={firm.code} required />
            <RefSelect
              label="Правна форма"
              name="legal_form_id"
              value={firm.legalFormId}
              items={refs.legalForms ?? []}
            />
            <RefSelect
              label="Държава"
              name="country_id"
              value={firm.countryId}
              items={refs.countries ?? []}
              required
            />
            <Input
              label="Регистрационен номер"
              name="registration_number"
              defaultValue={firm.registrationNumber ?? ''}
            />
            <FormSubmit />
          </form>
        ) : (
          <ReadOnlyNotice />
        )}
      </section>
      <section id="settings" className="panel">
        <h2>Настройки</h2>
        {firmPermissions.includes('firms.settings.edit') ? (
          <form
            className="inline-form"
            onSubmit={(event) => {
              event.preventDefault();
              void command(
                'settings',
                {
                  expectedRowVersion: firm.rowVersion,
                  base_currency_id: new FormData(event.currentTarget).get('base_currency_id'),
                },
                'PATCH',
              );
            }}
          >
            <RefSelect
              label="Основна валута"
              name="base_currency_id"
              value={firm.baseCurrencyId}
              items={refs.currencies ?? []}
              required
            />
            <FormSubmit />
          </form>
        ) : (
          <ReadOnlyNotice />
        )}
      </section>
      <section id="access" className="panel">
        <div className="section-heading">
          <div>
            <h2>Достъп до OFFICE</h2>
            <p>Трите слоя се управляват отделно.</p>
          </div>
          <span className="status neutral">Без Accounting</span>
        </div>
        <ol className="steps">
          <li>
            <strong>1. Приложение</strong>
            <span>{office ? 'OFFICE е включено' : 'OFFICE не е включено'}</span>
            {office ? (
              appPermissions.includes('firms.applications.disable') ? (
                <ReasonAction
                  label="Изключи"
                  onConfirm={(reason) => {
                    void command('applications/OFFICE/disable', {
                      expectedRowVersion: office.rowVersion,
                      reason,
                    });
                  }}
                />
              ) : null
            ) : appPermissions.includes('firms.applications.enable') ? (
              <button
                onClick={() =>
                  void command('applications/OFFICE/enable', { validFrom: null, validTo: null })
                }
              >
                Включи OFFICE
              </button>
            ) : null}
          </li>
          <li>
            <strong>2. Потребителски достъп</strong>
            <span>{access.length} активни потребители</span>
            {appPermissions.includes('firms.access.grant') && office ? (
              <div className="inline-actions">
                <select
                  aria-label="Потребител за достъп"
                  value={selectedUser}
                  onChange={(event) => setSelectedUser(event.target.value)}
                >
                  <option value="">Изберете потребител</option>
                  {users.map((user) => (
                    <option key={user.id} value={user.id}>
                      {user.displayName ?? user.email} — {user.email}
                    </option>
                  ))}
                </select>
                <button
                  disabled={!selectedUser}
                  onClick={() =>
                    void command(`applications/OFFICE/users/${selectedUser}/grant`, {
                      validFrom: null,
                      validTo: null,
                    })
                  }
                >
                  Дай достъп
                </button>
              </div>
            ) : null}
            <ul className="relationship-list">
              {access.map((item) => (
                <li key={item.id}>
                  <span>{item.userDisplayName ?? item.userEmail ?? item.userId}</span>
                  {appPermissions.includes('firms.access.revoke') ? (
                    <ReasonAction
                      compact
                      label="Отнеми"
                      onConfirm={(reason) => {
                        void command(`applications/OFFICE/users/${item.userId}/revoke`, {
                          expectedRowVersion: item.rowVersion,
                          reason,
                        });
                      }}
                    />
                  ) : null}
                </li>
              ))}
            </ul>
          </li>
          <li>
            <strong>3. Фирмени роли</strong>
            <span>Ролята сама по себе си не дава OFFICE достъп.</span>
            {appPermissions.includes('firms.roles.assign') ? (
              <div className="inline-actions">
                <select aria-label="Роля" id="role-choice">
                  <option value="">Изберете роля</option>
                  {roles.map((role) => (
                    <option key={role.id} value={role.code}>
                      {role.name} ({role.code})
                    </option>
                  ))}
                </select>
                <button
                  disabled={!selectedUser}
                  onClick={() => {
                    const element = document.querySelector<HTMLSelectElement>('#role-choice');
                    if (element?.value)
                      void command(`users/${selectedUser}/roles/${element.value}/assign`, {
                        validFrom: null,
                        validTo: null,
                      });
                  }}
                >
                  Задай роля
                </button>
              </div>
            ) : null}
            <ul className="relationship-list">
              {userRoles.map((item) => (
                <li key={item.id}>
                  <span>{item.roleName ?? item.roleCode}</span>
                  {appPermissions.includes('firms.roles.remove') ? (
                    <ReasonAction
                      compact
                      label="Премахни"
                      onConfirm={(reason) => {
                        void command(`users/${selectedUser}/roles/${item.roleCode}/remove`, {
                          expectedRowVersion: item.rowVersion,
                          reason,
                        });
                      }}
                    />
                  ) : null}
                </li>
              ))}
            </ul>
          </li>
        </ol>
      </section>
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
function Input({
  defaultValue,
  label,
  name,
  required = false,
}: {
  defaultValue: string;
  label: string;
  name: string;
  required?: boolean;
}): ReactNode {
  return (
    <label>
      {label}
      <input defaultValue={defaultValue} name={name} required={required} />
    </label>
  );
}
function RefSelect({
  items,
  label,
  name,
  required = false,
  value,
}: {
  items: ReferenceItem[];
  label: string;
  name: string;
  required?: boolean;
  value: string | null;
}): ReactNode {
  return (
    <label>
      {label}
      <select defaultValue={value ?? ''} name={name} required={required}>
        <option value="">Без стойност</option>
        {items.map((item) => (
          <option key={item.id} value={item.id}>
            {refLabel(item)}
          </option>
        ))}
      </select>
    </label>
  );
}
function FormSubmit(): ReactNode {
  return (
    <div className="form-action">
      <button type="submit">Запази</button>
    </div>
  );
}
function ReadOnlyNotice(): ReactNode {
  return <p className="hint">Нямате фирмено разрешение за редакция на тази секция.</p>;
}
function ReasonAction({
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
              <textarea id="reason-value" required />
            </label>
            <div className="dialog-actions">
              <button className="secondary" onClick={() => setOpen(false)}>
                Отказ
              </button>
              <button
                className={danger ? 'danger' : ''}
                onClick={() => {
                  const reason = document
                    .querySelector<HTMLTextAreaElement>('#reason-value')
                    ?.value.trim();
                  if (reason) {
                    onConfirm(reason);
                    setOpen(false);
                  }
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
function formatDate(value: string): string {
  return new Intl.DateTimeFormat('bg-BG', { dateStyle: 'medium', timeStyle: 'short' }).format(
    new Date(value),
  );
}
