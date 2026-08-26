import { ForbiddenException, Injectable } from '@nestjs/common';

import type { AuthenticationClaims } from '../auth/auth.types.js';
import { PrismaExternalIdentityRepository } from './prisma-external-identity.repository.js';

export type IdentityResolutionErrorCode =
  'IDENTITY_LINK_DISABLED' | 'IDENTITY_NOT_LINKED' | 'IDENTITY_UNLINKED' | 'PLATFORM_USER_DISABLED';

export interface AuthenticatedPlatformUser extends AuthenticationClaims {
  identityLinkId: string;
  platformUserId: string;
}

function deny(code: IdentityResolutionErrorCode, message: string): never {
  throw new ForbiddenException({ code, message, statusCode: 403 });
}

@Injectable()
export class IdentityResolutionService {
  constructor(private readonly identities: PrismaExternalIdentityRepository) {}

  async resolve(claims: AuthenticationClaims): Promise<AuthenticatedPlatformUser> {
    const identity = await this.identities.findByIssuerAndSubject(claims.issuer, claims.subject);

    if (identity === null) {
      return deny('IDENTITY_NOT_LINKED', 'The authenticated identity is not linked');
    }
    if (identity.identityStatus === 'disabled') {
      return deny('IDENTITY_LINK_DISABLED', 'The external identity link is disabled');
    }
    if (identity.identityStatus === 'unlinked') {
      return deny('IDENTITY_UNLINKED', 'The external identity has been unlinked');
    }
    if (!identity.userIsActive) {
      return deny('PLATFORM_USER_DISABLED', 'The platform user is disabled');
    }

    return {
      ...claims,
      identityLinkId: identity.identityLinkId,
      platformUserId: identity.platformUserId,
    };
  }
}
