import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import type { AuthenticatedOfficeRequest } from '../auth/auth.types.js';
import { SharedCoreAuthorizationClient } from '../shared-core/shared-core.client.js';

const OFFICE_PERMISSION = 'office-permission';

export const RequireOfficePermission = (permission: string): MethodDecorator =>
  SetMetadata(OFFICE_PERMISSION, permission);

@Injectable()
export class OfficePermissionGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly sharedCore: SharedCoreAuthorizationClient,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const permission = this.reflector.get<string>(OFFICE_PERMISSION, context.getHandler());
    if (permission === undefined)
      throw new ForbiddenException('Office permission is not configured');
    const request = context
      .switchToHttp()
      .getRequest<AuthenticatedOfficeRequest & { params: { firmId?: string } }>();
    const firmId = request.params.firmId;
    if (request.bearerToken === undefined || firmId === undefined) {
      throw new ForbiddenException('Firm-scoped Office authorization is required');
    }
    const result = await this.sharedCore.canOfficePermission(
      request.bearerToken,
      firmId,
      permission,
    );
    if (!result.allowed) throw new ForbiddenException('Office permission is denied');
    return true;
  }
}
