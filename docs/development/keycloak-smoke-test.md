# Development Keycloak smoke test

This procedure verifies Keycloak discovery, the imported realm, browser login, the `shared-core-api` audience, JWKS signature validation, and the authenticated Shared Core endpoint. It does not use PostgreSQL or establish V Platform authorization.

## 1. Start and inspect Keycloak

```bash
pnpm infra:up
docker compose -f infrastructure/compose/development.yml ps keycloak
curl --fail http://localhost:8080/realms/vplatform/.well-known/openid-configuration
curl --fail http://localhost:8080/realms/vplatform/protocol/openid-connect/certs
```

The container must report healthy. The discovery document's `issuer` must be exactly `http://localhost:8080/realms/vplatform`, and `jwks_uri` must point to that realm's certificate endpoint.

The development import is applied when a new Keycloak container is created. After editing the realm JSON, recreate Keycloak with:

```bash
docker compose -f infrastructure/compose/development.yml up -d --force-recreate keycloak
```

## 2. Create a disposable development identity

Open `http://localhost:8080/admin/`, authenticate with the administrator values from the local `.env`, select the `vplatform` realm, and create a disposable user. Set a non-temporary password that satisfies the development realm policy.

Do not add real users or encode firms, application access, business roles, or permissions in Keycloak. This identity proves authentication only.

## 3. Obtain an authorization-code token with PKCE

Generate a verifier and S256 challenge:

```bash
VERIFIER=$(openssl rand -base64 64 | tr -d '=+/' | cut -c1-64)
CHALLENGE=$(printf %s "$VERIFIER" | openssl dgst -binary -sha256 | openssl base64 -A | tr '+/' '-_' | tr -d '=')
printf 'Verifier: %s\nChallenge: %s\n' "$VERIFIER" "$CHALLENGE"
```

Open this URL after substituting the generated challenge:

```text
http://localhost:8080/realms/vplatform/protocol/openid-connect/auth?client_id=office-web&response_type=code&scope=openid&redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fauth%2Fcallback&code_challenge=CHALLENGE&code_challenge_method=S256&state=manual-smoke-test
```

After login, copy the `code` query parameter from the browser address bar. The callback page does not need to exist for this manual test.

Exchange the code immediately, using the same verifier:

```bash
TOKEN_RESPONSE=$(curl --fail --request POST \
  --url http://localhost:8080/realms/vplatform/protocol/openid-connect/token \
  --header 'content-type: application/x-www-form-urlencoded' \
  --data-urlencode grant_type=authorization_code \
  --data-urlencode client_id=office-web \
  --data-urlencode redirect_uri=http://localhost:3000/auth/callback \
  --data-urlencode code=PASTE_CODE_HERE \
  --data-urlencode code_verifier="$VERIFIER")
ACCESS_TOKEN=$(printf %s "$TOKEN_RESPONSE" | jq --raw-output .access_token)
```

The development `office-web` access token intentionally carries `office-web`, `office-api`, and `shared-core-api` audiences. These audiences permit cryptographic token validation only; they grant no firm, application, role, permission, or resource access.

## 4. Start Shared Core API and call the protected endpoint

```bash
OIDC_ISSUER_URL=http://localhost:8080/realms/vplatform \
OIDC_SHARED_CORE_API_CLIENT_ID=shared-core-api \
OIDC_SHARED_CORE_API_AUDIENCE=shared-core-api \
OIDC_SHARED_CORE_API_SIGNING_ALGORITHM=RS256 \
OIDC_CLOCK_TOLERANCE_SECONDS=5 \
pnpm --filter @vplatform/shared-core-api dev
```

In another shell:

```bash
curl --fail \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  http://localhost:3001/auth/me
```

The response contains only issuer, subject, audience, and optional preferred username. Email, realm/client roles, firm access, and V Platform permissions are not returned or interpreted.

Also verify rejection:

```bash
curl --include http://localhost:3001/auth/me
curl --include --header 'Authorization: Bearer malformed' http://localhost:3001/auth/me
```

Both requests must return HTTP 401.
