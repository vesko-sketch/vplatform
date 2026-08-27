import type { ReactNode } from 'react';
import { UserDetail } from './user-detail';
export default async function Page({
  params,
}: {
  params: Promise<{ userId: string }>;
}): Promise<ReactNode> {
  return <UserDetail userId={(await params).userId} />;
}
