import type { ReactNode } from 'react';
import { FirmDetail } from './firm-detail';
export default async function Page({
  params,
}: {
  params: Promise<{ firmId: string }>;
}): Promise<ReactNode> {
  return <FirmDetail firmId={(await params).firmId} />;
}
