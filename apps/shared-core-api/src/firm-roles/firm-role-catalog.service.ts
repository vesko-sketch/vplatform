import { ForbiddenException, Injectable, ServiceUnavailableException } from '@nestjs/common';

import { AuthorizationService } from '../authorization/authorization.service.js';
import {
  FirmRoleCatalogRepository,
  type FirmRoleCatalogItem,
} from './firm-role-catalog.repository.js';

@Injectable()
export class FirmRoleCatalogService {
  constructor(
    private readonly authorization: AuthorizationService,
    private readonly roles: FirmRoleCatalogRepository,
  ) {}

  async list(actorUserId: string, evaluatedAt: Date): Promise<FirmRoleCatalogItem[]> {
    try {
      const decision = await this.authorization.canAtApplicationScope({
        applicationCode: 'OFFICE',
        evaluatedAt,
        permissionCode: 'firms.roles.view',
        platformUserId: actorUserId,
      });
      if (!decision.basePermissionGranted)
        throw new ForbiddenException('Firm role catalog access is denied');
    } catch (error) {
      if (error instanceof ForbiddenException) throw error;
      throw new ServiceUnavailableException('Authorization is unavailable');
    }
    return this.roles.listActive();
  }
}
