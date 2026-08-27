#!/usr/bin/env node

import { randomBytes } from 'node:crypto';
import { chmodSync, readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const repositoryRoot = resolve(import.meta.dirname, '../..');
const secretFile = resolve(repositoryRoot, '.env.shared-core.local');
const variableName = 'SHARED_CORE_USER_WRITER_DATABASE_URL';
const password = randomBytes(36).toString('base64url');

const alter = spawnSync(
  'docker',
  [
    'exec',
    '-i',
    'accounting-postgres',
    'psql',
    '-U',
    'accounting_user',
    '-d',
    'shared_core',
    '-X',
    '-v',
    'ON_ERROR_STOP=1',
    '-v',
    `writer_password=${password}`,
  ],
  {
    input: "ALTER ROLE shared_core_user_writer PASSWORD :'writer_password';\n",
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
  },
);

if (alter.status !== 0) {
  process.stderr.write('Failed to set the Shared Core user-writer password.\n');
  process.exit(alter.status ?? 1);
}

let lines = [];
try {
  lines = readFileSync(secretFile, 'utf8').split(/\r?\n/).filter(Boolean);
} catch (error) {
  if (error?.code !== 'ENOENT') throw error;
}

const value = `postgresql://shared_core_user_writer:${encodeURIComponent(password)}@127.0.0.1:5433/shared_core`;
const replacement = `${variableName}=${value}`;
const existingIndex = lines.findIndex((line) => line.startsWith(`${variableName}=`));
if (existingIndex >= 0) lines[existingIndex] = replacement;
else lines.push(replacement);

writeFileSync(secretFile, `${lines.join('\n')}\n`, { mode: 0o600 });
chmodSync(secretFile, 0o600);

const verify = spawnSync(
  'docker',
  [
    'exec',
    '-e',
    `PGPASSWORD=${password}`,
    'accounting-postgres',
    'psql',
    '-h',
    '127.0.0.1',
    '-U',
    'shared_core_user_writer',
    '-d',
    'shared_core',
    '-X',
    '-A',
    '-t',
    '-c',
    'SELECT current_user;',
  ],
  { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] },
);

if (verify.status !== 0 || verify.stdout.trim() !== 'shared_core_user_writer') {
  process.stderr.write('User-writer TCP authentication verification failed.\n');
  process.exit(verify.status ?? 1);
}

process.stdout.write(
  `Provisioned ${variableName} in a mode-0600 Git-ignored local file; TCP authentication passed.\n`,
);
