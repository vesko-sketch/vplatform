import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';

export interface HealthResponse {
  service: 'accounting-api';
  status: 'ok';
  zone: 'private';
}

@ApiTags('health')
@Controller('health')
export class HealthController {
  @Get()
  @ApiOperation({ summary: 'Report service health' })
  @ApiOkResponse({ description: 'The private service process is healthy.' })
  getHealth(): HealthResponse {
    return { service: 'accounting-api', status: 'ok', zone: 'private' };
  }
}
