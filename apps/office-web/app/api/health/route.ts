import { getHealth } from './health';

export function GET(): Response {
  return Response.json(getHealth());
}
