import 'reflect-metadata';

import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

import { AppModule } from './app.module.js';
import { loadSharedCoreOidcConfig } from './config/oidc.config.js';

async function bootstrap(): Promise<void> {
  loadSharedCoreOidcConfig();
  const app = await NestFactory.create(AppModule);
  const openApiConfig = new DocumentBuilder()
    .setTitle('V Platform Shared Core API')
    .setDescription('Shared identity metadata and platform authorization API.')
    .setVersion('0.1.0')
    .build();

  SwaggerModule.setup('openapi', app, SwaggerModule.createDocument(app, openApiConfig));
  await app.listen(Number(process.env.SHARED_CORE_API_PORT ?? 3001));
}

void bootstrap();
