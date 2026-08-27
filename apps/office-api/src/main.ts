import 'reflect-metadata';

import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

import { AppModule } from './app.module.js';
import { loadOfficeApiConfig } from './config/oidc.config.js';

async function bootstrap(): Promise<void> {
  const config = loadOfficeApiConfig();
  const app = await NestFactory.create(AppModule);
  app.enableCors({ credentials: false, origin: config.officeWebOrigin });
  const openApiConfig = new DocumentBuilder()
    .setTitle('V Office API')
    .setDescription('Public Office workflows and document intake API.')
    .setVersion('0.1.0')
    .addBearerAuth()
    .build();

  SwaggerModule.setup('openapi', app, SwaggerModule.createDocument(app, openApiConfig));
  await app.listen(Number(process.env.OFFICE_API_PORT ?? 3101));
}

void bootstrap();
