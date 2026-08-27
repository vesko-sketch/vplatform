import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
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

export interface FirmMaster {
  baseCurrencyId: string;
  code: string;
  countryId: string;
  createdAt: string;
  defaultLanguageId: string | null;
  id: string;
  isActive: boolean;
  legalFormId: string | null;
  name: string;
  registrationNumber: string | null;
  rowVersion: string;
  shortName: string | null;
  timezone: string;
  updatedAt: string;
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
  abstract listAdminFirms(token: string): Promise<FirmMaster[]>;
  abstract getAdminFirm(token: string, firmId: string): Promise<FirmMaster>;
  abstract createFirm(token: string, body: unknown): Promise<FirmMaster>;
  abstract firmCommand(
    token: string,
    method: 'PATCH' | 'POST',
    path: string,
    body: unknown,
  ): Promise<FirmMaster>;
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

  async listAdminFirms(token: string): Promise<FirmMaster[]> {
    return this.request('/firms', token);
  }
  async getAdminFirm(token: string, firmId: string): Promise<FirmMaster> {
    return this.request(`/firms/${encodeURIComponent(firmId)}`, token);
  }
  async createFirm(token: string, body: unknown): Promise<FirmMaster> {
    return this.request('/firms', token, 'POST', body);
  }
  async firmCommand(
    token: string,
    method: 'PATCH' | 'POST',
    path: string,
    body: unknown,
  ): Promise<FirmMaster> {
    return this.request(`/firms/${path}`, token, method, body);
  }

  private async requireOfficeAccess(token: string, firmId: string): Promise<void> {
    const applications = await this.listFirmApplications(token, firmId);
    if (!applications.some((application) => application.code === 'OFFICE')) {
      throw new ForbiddenException('Office access is denied');
    }
  }

  private async get<T>(path: string, token: string): Promise<T> {
    return this.request(path, token);
  }

  private async request<T>(
    path: string,
    token: string,
    method: 'GET' | 'PATCH' | 'POST' = 'GET',
    body?: unknown,
  ): Promise<T> {
    let response: Response;
    try {
      response = await fetch(`${this.baseUrl}${path}`, {
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        headers: {
          authorization: `Bearer ${token}`,
          ...(body === undefined ? {} : { 'content-type': 'application/json' }),
        },
        method,
        signal: AbortSignal.timeout(5000),
      });
    } catch {
      throw new ServiceUnavailableException('Shared Core authorization is unavailable');
    }
    if (response.status === 401) throw new UnauthorizedException('Authentication was rejected');
    if (response.status === 403) throw new ForbiddenException('Office authorization is denied');
    if (response.status === 404) throw new NotFoundException('Firm not found');
    if (response.status === 400) throw new BadRequestException('Firm command is invalid');
    if (response.status === 409) {
      let code = 'FIRM_COMMAND_CONFLICT';
      try {
        const problem = (await response.json()) as { code?: unknown };
        if (problem.code === 'ROW_VERSION_CONFLICT' || problem.code === 'FIRM_CODE_CONFLICT') {
          code = problem.code;
        }
      } catch {
        // The public fallback remains intentionally generic.
      }
      throw new ConflictException({
        code,
        message: 'Firm command conflicts with current state',
        statusCode: 409,
      });
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
