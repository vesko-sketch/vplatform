export type ExternalIdentityStatus = 'active' | 'disabled' | 'unlinked';

export interface ExternalIdentityResolution {
  identityLinkId: string;
  identityStatus: ExternalIdentityStatus;
  platformUserId: string;
  userIsActive: boolean;
}

export interface ExternalIdentityRepository {
  findByIssuerAndSubject(
    issuer: string,
    subject: string,
  ): Promise<ExternalIdentityResolution | null>;
}
