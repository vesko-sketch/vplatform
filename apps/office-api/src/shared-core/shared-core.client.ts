import {
  ForbiddenException,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';

import { loadOfficeApiConfig } from '../config/oidc.config.js';

export interface PlatformIdentity {
  identityLinkId: string;
  platformUserId: string;
  preferredUsername?: string;
}

export interface AccessibleFirm {
  code: string;
  id: string;
  name: string;
  shortName: string | null;
}

export interface AccessibleApplication {
  code: string;
  name: string;
}

export interface BasePermissionContext {
  applicationCode: string;
  authorizationLevel: 'base';
  firmId: string;
  permissions: string[];
  requiresDomainPolicy: true;
}

interface BaseDecision {
  allowed: boolean;
  authorizationLevel: 'base';
  requiresDomainPolicy: true;
}

export abstract class SharedCoreAuthorizationClient {
  abstract resolveMe(token: string): Promise<PlatformIdentity>;
  abstract listFirms(token: string): Promise<AccessibleFirm[]>;
  abstract listFirmApplications(token: string, firmId: string): Promise<AccessibleApplication[]>;
  abstract getOfficePermissions(token: string, firmId: string): Promise<BasePermissionContext>;
  abstract canOfficePermission(
    token: string,
    firmId: string,
    permission: string,
  ): Promise<BaseDecision>;
}

@Injectable()
export class HttpSharedCoreAuthorizationClient extends SharedCoreAuthorizationClient {
  private readonly baseUrl = loadOfficeApiConfig().sharedCoreApiUrl;

  async resolveMe(token: string): Promise<PlatformIdentity> {
    return this.get('/auth/me', token);
  }

  async listFirms(token: string): Promise<AccessibleFirm[]> {
    return this.get('/me/firms', token);
  }

  async listFirmApplications(token: string, firmId: string): Promise<AccessibleApplication[]> {
    return this.get(`/me/firms/${encodeURIComponent(firmId)}/applications`, token);
  }

  async getOfficePermissions(token: string, firmId: string): Promise<BasePermissionContext> {
    await this.requireOfficeAccess(token, firmId);
    return this.get(
      `/me/firms/${encodeURIComponent(firmId)}/applications/OFFICE/permissions`,
      token,
    );
  }

  async canOfficePermission(
    token: string,
    firmId: string,
    permission: string,
  ): Promise<BaseDecision> {
    await this.requireOfficeAccess(token, firmId);
    return this.get(
      `/me/firms/${encodeURIComponent(firmId)}/applications/OFFICE/permissions/${encodeURIComponent(permission)}`,
      token,
    );
  }

  private async requireOfficeAccess(token: string, firmId: string): Promise<void> {
    const applications = await this.listFirmApplications(token, firmId);
    if (!applications.some((application) => application.code === 'OFFICE')) {
      throw new ForbiddenException('Office access is denied');
    }
  }

  private async get<T>(path: string, token: string): Promise<T> {
    let response: Response;
    try {
      response = await fetch(`${this.baseUrl}${path}`, {
        headers: { authorization: `Bearer ${token}` },
        signal: AbortSignal.timeout(5000),
      });
    } catch {
      throw new ServiceUnavailableException('Shared Core authorization is unavailable');
    }
    if (response.status === 401) throw new UnauthorizedException('Authentication was rejected');
    if (response.status === 403 || response.status === 404) {
      throw new ForbiddenException('Office authorization is denied');
    }
    if (!response.ok)
      throw new ServiceUnavailableException('Shared Core authorization is unavailable');
    try {
      return (await response.json()) as T;
    } catch {
      throw new ServiceUnavailableException(
        'Shared Core returned an invalid authorization response',
      );
    }
  }
}
