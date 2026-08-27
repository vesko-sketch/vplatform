'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState, type FormEvent, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';

import { adminFetch, json } from '../admin-client';
import type { Firm, PermissionContext, ReferenceItem } from '../admin-types';

function label(item: ReferenceItem): string {
  return (
    item.nameBg ??
    item.name ??
    item.shortName ??
    item.nameEn ??
    item.code ??
    item.iso2Code ??
    item.id
  );
}

export function FirmsPage(): ReactNode {
  const router = useRouter();
  const [firms, setFirms] = useState<Firm[]>([]);
  const [permissions, setPermissions] = useState<string[]>([]);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState('all');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);
  const [references, setReferences] = useState<Record<string, ReferenceItem[]>>({});

  useEffect(() => {
    void Promise.all([
      adminFetch<Firm[]>('/api/office/admin/firms'),
      adminFetch<PermissionContext>('/api/office/application-permissions'),
      adminFetch<ReferenceItem[]>('/api/office/reference-data/countries'),
      adminFetch<ReferenceItem[]>('/api/office/reference-data/currencies'),
    ])
      .then(([items, context, countries, currencies]) => {
        setFirms(items);
        setPermissions(context.permissions);
        setReferences({ countries, currencies });
        setLoading(false);
      })
      .catch((value: unknown) => {
        setError(value instanceof Error ? value.message : 'Грешка');
        setLoading(false);
      });
  }, []);

  async function openCreate(): Promise<void> {
    setCreating(true);
    if (references.languages && references.legalForms) return;
    try {
      const [countries, currencies, languages, legalForms] = await Promise.all([
        adminFetch<ReferenceItem[]>('/api/office/reference-data/countries'),
        adminFetch<ReferenceItem[]>('/api/office/reference-data/currencies'),
        adminFetch<ReferenceItem[]>('/api/office/reference-data/languages'),
        adminFetch<ReferenceItem[]>('/api/office/reference-data/legal-forms'),
      ]);
      setReferences((current) => ({ ...current, countries, currencies, languages, legalForms }));
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Каталозите не са достъпни');
    }
  }

  const visible = useMemo(
    () =>
      firms.filter((firm) => {
        const matchesText = `${firm.code} ${firm.name} ${firm.shortName ?? ''}`
          .toLowerCase()
          .includes(query.toLowerCase());
        return matchesText && (filter === 'all' || (filter === 'active') === firm.isActive);
      }),
    [firms, query, filter],
  );

  async function create(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    setError('');
    const form = new FormData(event.currentTarget);
    const value = (key: string): string => {
      const entry = form.get(key);
      return typeof entry === 'string' ? entry : '';
    };
    try {
      const firm = await adminFetch<Firm>(
        '/api/office/admin/firms',
        json('POST', {
          base_currency_id: value('base_currency_id'),
          code: value('code'),
          country_id: value('country_id'),
          default_language_id: value('default_language_id') || null,
          legal_form_id: value('legal_form_id') || null,
          name: value('name'),
          registration_number: value('registration_number') || null,
          short_name: value('short_name') || null,
          timezone: value('timezone'),
        }),
      );
      setCreating(false);
      router.push(`/administration/firms/${firm.id}`);
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Фирмата не беше създадена');
    }
  }

  return (
    <>
      <div className="page-header">
        <div>
          <p className="eyebrow">Администрация</p>
          <h1>Фирми</h1>
          <p>Основни данни и достъп до V Office.</p>
        </div>
        {permissions.includes('firms.create') ? (
          <button onClick={() => void openCreate()}>Нова фирма</button>
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
            aria-label="Търсене по код или име"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Код или име"
          />
        </label>
        <label>
          Статус
          <select value={filter} onChange={(event) => setFilter(event.target.value)}>
            <option value="all">Всички</option>
            <option value="active">Активни</option>
            <option value="inactive">Неактивни</option>
          </select>
        </label>
      </div>
      {loading ? (
        <p className="empty">Зареждане на фирмите…</p>
      ) : visible.length === 0 ? (
        <p className="empty">Няма фирми, отговарящи на филтъра.</p>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Код</th>
                <th>Фирма</th>
                <th>Кратко име</th>
                <th>Регистрация</th>
                <th>Държава</th>
                <th>Валута</th>
                <th>Статус</th>
                <th>
                  <span className="sr-only">Действие</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {visible.map((firm) => (
                <tr key={firm.id}>
                  <td>
                    <strong>{firm.code}</strong>
                  </td>
                  <td>{firm.name}</td>
                  <td>{firm.shortName ?? '—'}</td>
                  <td>{firm.registrationNumber ?? '—'}</td>
                  <td>
                    {label(
                      references.countries?.find((item) => item.id === firm.countryId) ?? {
                        id: firm.countryId,
                      },
                    )}
                  </td>
                  <td>
                    {label(
                      references.currencies?.find((item) => item.id === firm.baseCurrencyId) ?? {
                        id: firm.baseCurrencyId,
                      },
                    )}
                  </td>
                  <td>
                    <Status active={firm.isActive} />
                  </td>
                  <td>
                    <Link href={`/administration/firms/${firm.id}`}>Отвори</Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {creating ? (
        <div className="dialog-backdrop">
          <div
            className="dialog wide"
            role="dialog"
            aria-modal="true"
            aria-labelledby="create-firm-title"
          >
            <div className="dialog-header">
              <h2 id="create-firm-title">Нова фирма</h2>
              <button
                className="icon-button"
                aria-label="Затвори"
                onClick={() => setCreating(false)}
              >
                ×
              </button>
            </div>
            <form onSubmit={(event) => void create(event)}>
              <div className="form-grid">
                <Field name="code" label="Код" required />
                <Field name="name" label="Име" required />
                <Field name="short_name" label="Кратко име" />
                <Field name="registration_number" label="Регистрационен номер" />
                <Select
                  name="legal_form_id"
                  label="Правна форма"
                  items={references.legalForms ?? []}
                  optional
                />
                <Select
                  name="country_id"
                  label="Държава"
                  items={references.countries ?? []}
                  required
                />
                <Select
                  name="default_language_id"
                  label="Език"
                  items={references.languages ?? []}
                  optional
                />
                <Select
                  name="base_currency_id"
                  label="Основна валута"
                  items={references.currencies ?? []}
                  required
                />
                <Field name="timezone" label="Часова зона" defaultValue="Europe/Sofia" required />
              </div>
              <p className="hint">
                След създаване OFFICE, потребителският достъп и ролите се настройват отделно.
              </p>
              <div className="dialog-actions">
                <button type="button" className="secondary" onClick={() => setCreating(false)}>
                  Отказ
                </button>
                <button type="submit">Създай</button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </>
  );
}

export function Status({ active }: { active: boolean }): ReactNode {
  return (
    <span className={`status ${active ? 'success' : 'neutral'}`}>
      {active ? 'Активна' : 'Неактивна'}
    </span>
  );
}
function Field({
  defaultValue,
  label,
  name,
  required = false,
}: {
  defaultValue?: string;
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
function Select({
  items,
  label: fieldLabel,
  name,
  optional = false,
  required = false,
}: {
  items: ReferenceItem[];
  label: string;
  name: string;
  optional?: boolean;
  required?: boolean;
}): ReactNode {
  return (
    <label>
      {fieldLabel}
      <select name={name} required={required}>
        <option value="">{optional ? 'Без стойност' : 'Изберете'}</option>
        {items.map((item) => (
          <option key={item.id} value={item.id}>
            {label(item)}
          </option>
        ))}
      </select>
    </label>
  );
}
