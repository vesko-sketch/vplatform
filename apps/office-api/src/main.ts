import 'reflect-metadata';

import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

import { AppModule } from './app.module.js';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  const openApiConfig = new DocumentBuilder()
    .setTitle('V Office API')
    .setDescription('Public Office workflows and document intake API.')
    .setVersion('0.1.0')
    .build();

  SwaggerModule.setup('openapi', app, SwaggerModule.createDocument(app, openApiConfig));
  await app.listen(Number(process.env.OFFICE_API_PORT ?? 3002));
}

void bootstrap();
