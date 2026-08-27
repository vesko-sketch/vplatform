'use client';

export class AdminApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string | null,
  ) {
    super(messageFor(status, code));
  }
}

export function messageFor(status: number, code: string | null): string {
  if (status === 401) return 'Сесията е изтекла. Влезте отново.';
  if (status === 403) return 'Нямате необходимото разрешение.';
  if (status === 404) return 'Записът не е намерен или вече не е достъпен.';
  if (code === 'ROW_VERSION_CONFLICT')
    return 'Записът е променен от друг потребител. Заредете актуалните данни.';
  if (code === 'DEPENDENT_ACTIVE_USER_ACCESS')
    return 'Първо отнемете активния достъп на потребителите до OFFICE.';
  if (status === 409) return 'Състоянието е променено. Обновете данните и опитайте отново.';
  if (status === 503) return 'Shared Core временно не е достъпен.';
  return 'Операцията не можа да бъде изпълнена.';
}

export async function adminFetch<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(path, { cache: 'no-store', ...init });
  if (!response.ok) {
    let code: string | null = null;
    try {
      const problem = (await response.json()) as { code?: unknown };
      code = typeof problem.code === 'string' ? problem.code : null;
    } catch {
      // Public response intentionally remains generic.
    }
    throw new AdminApiError(response.status, code);
  }
  return (await response.json()) as T;
}

export function json(method: 'PATCH' | 'POST', body: unknown): RequestInit {
  return { body: JSON.stringify(body), headers: { 'content-type': 'application/json' }, method };
}

export function hasAnyPermission(permissions: string[], prefixes: string[]): boolean {
  return permissions.some((permission) => prefixes.some((prefix) => permission.startsWith(prefix)));
}

export function invitationLabel(state: string | null, expires: string | null): string {
  if (state === 'PENDING' && expires && new Date(expires) < new Date()) return 'Изтекла';
  if (state === 'PENDING') return 'Чакаща';
  if (state === 'CONSUMED') return 'Използвана';
  if (state === 'CANCELLED') return 'Отказана';
  return '—';
}
