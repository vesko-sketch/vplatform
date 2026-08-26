import 'reflect-metadata';

import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

import { AppModule } from './app.module.js';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  const openApiConfig = new DocumentBuilder()
    .setTitle('V Accounting API')
    .setDescription('Private Accounting domain API. This API must not be publicly exposed.')
    .setVersion('0.1.0')
    .build();

  SwaggerModule.setup('openapi', app, SwaggerModule.createDocument(app, openApiConfig));
  await app.listen(Number(process.env.ACCOUNTING_API_PORT ?? 3102));
}

void bootstrap();
