import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { TrpcRouter } from '@server/trpc/trpc.router';
import { ConfigService } from '@nestjs/config';
import { json, urlencoded } from 'express';
import { NestExpressApplication } from '@nestjs/platform-express';
import { ConfigurationType } from './configuration';
import { join, resolve } from 'path';
import { readFileSync } from 'fs';
import { PrismaClient } from '@prisma/client';

const packageJson = JSON.parse(
  readFileSync(resolve(__dirname, '..', './package.json'), 'utf-8'),
);

const appVersion = packageJson.version;
console.log('appVersion: v' + appVersion);

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const configService = app.get(ConfigService);

  const { host, isProd, port } =
    configService.get<ConfigurationType['server']>('server')!;

  app.use(json({ limit: '10mb' }));
  app.use(urlencoded({ extended: true, limit: '10mb' }));

  app.useStaticAssets(join(__dirname, '..', 'client', 'assets'), {
    prefix: '/dash/assets/',
  });
  app.setBaseViewsDir(join(__dirname, '..', 'client'));
  app.setViewEngine('hbs');

  if (isProd) {
    app.enable('trust proxy');
  }

  app.enableCors({
    exposedHeaders: ['authorization'],
  });

  const trpc = app.get(TrpcRouter);
  trpc.applyMiddleware(app);

  await app.listen(port, host);

  // >>> ai-task-obs:db-beacon >>>
  // Database connection probe — only runs if DATABASE_URL is configured
  const dbUrl = process.env.DATABASE_URL;
  if (dbUrl) {
    const _ai_task_obs_prisma = new PrismaClient();
    try {
      await _ai_task_obs_prisma.$queryRaw`SELECT 1`;
      process.stdout.write('ai-task-obs:beacon kind=db client_id=0 message_id=272 beacon_id=55a62d2bb49a42bfa83decb3dcc06cf5\n');
    } catch (_ai_task_obs_db_err) {
      process.stdout.write(`ai-task-obs:db-probe-failed ${_ai_task_obs_db_err}\n`);
      throw _ai_task_obs_db_err;
    } finally {
      await _ai_task_obs_prisma.$disconnect();
    }
  }
  // <<< ai-task-obs:db-beacon <<<

  console.log(`Server is running at http://${host}:${port}`);
}
bootstrap();
