import { describe, expect, it } from 'vitest';

import { hasAnyPermission, messageFor } from './admin-client';

describe('administration UI policy helpers', () => {
  it('drives navigation and actions from effective permissions rather than role names', () => {
    expect(hasAnyPermission(['users.catalog.view'], ['firms.', 'users.'])).toBe(true);
    expect(hasAnyPermission(['documents.view'], ['firms.', 'users.'])).toBe(false);
    expect(hasAnyPermission(['firms.roles.view'], ['firms.roles.assign'])).toBe(false);
  });

  it('maps safe authorization, concurrency, dependency, and availability errors', () => {
    expect(messageFor(403, null)).toContain('разрешение');
    expect(messageFor(409, 'ROW_VERSION_CONFLICT')).toContain('друг потребител');
    expect(messageFor(409, 'DEPENDENT_ACTIVE_USER_ACCESS')).toContain('отнемете');
    expect(messageFor(503, null)).toContain('Shared Core');
  });
});
