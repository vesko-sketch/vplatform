import type { ReactNode } from 'react';
import { AdminShell } from './admin-shell';

export default function AdministrationLayout({ children }: { children: ReactNode }): ReactNode {
  return <AdminShell>{children}</AdminShell>;
}
