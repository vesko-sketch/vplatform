import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';

export interface HealthResponse {
  service: 'shared-core-api';
  status: 'ok';
}

@ApiTags('health')
@Controller('health')
export class HealthController {
  @Get()
  @ApiOperation({ summary: 'Report service health' })
  @ApiOkResponse({ description: 'The service process is healthy.' })
  getHealth(): HealthResponse {
    return { service: 'shared-core-api', status: 'ok' };
  }
}
