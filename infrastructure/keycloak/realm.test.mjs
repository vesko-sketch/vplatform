import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const realmPath = new URL('./realm-vplatform.json', import.meta.url);
const realm = JSON.parse(await readFile(realmPath, 'utf8'));
const clients = new Map(realm.clients.map((client) => [client.clientId, client]));

test('development realm defines exactly the five approved clients', () => {
  assert.deepEqual([...clients.keys()].sort(), [
    'accounting-api',
    'accounting-web',
    'office-api',
    'office-web',
    'shared-core-api',
  ]);
});

test('web clients require authorization code with PKCE and reject unsafe flows', () => {
  for (const clientId of ['office-web', 'accounting-web']) {
    const client = clients.get(clientId);
    assert.equal(client.publicClient, true);
    assert.equal(client.standardFlowEnabled, true);
    assert.equal(client.implicitFlowEnabled, false);
    assert.equal(client.directAccessGrantsEnabled, false);
    assert.equal(client.serviceAccountsEnabled, false);
    assert.equal(client.attributes['pkce.code.challenge.method'], 'S256');
  }
});

test('API clients are bearer-only audiences and cannot initiate login', () => {
  for (const clientId of ['shared-core-api', 'office-api', 'accounting-api']) {
    const client = clients.get(clientId);
    assert.equal(client.bearerOnly, true);
    assert.equal(client.standardFlowEnabled, false);
    assert.equal(client.directAccessGrantsEnabled, false);
    assert.equal(client.serviceAccountsEnabled, false);
  }
});

test('web access tokens contain only their intended audiences', () => {
  const audiences = (clientId) =>
    clients
      .get(clientId)
      .protocolMappers.map((mapper) => mapper.config['included.client.audience'])
      .sort();

  assert.deepEqual(audiences('office-web'), ['office-api', 'office-web', 'shared-core-api']);
  assert.deepEqual(audiences('accounting-web'), ['accounting-api', 'accounting-web']);
});

test('development redirect origins are explicit and do not overlap zones', () => {
  assert.deepEqual(clients.get('office-web').webOrigins, ['http://localhost:3000']);
  assert.deepEqual(clients.get('accounting-web').webOrigins, ['http://localhost:3100']);
});
