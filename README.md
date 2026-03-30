# Serverless Lab 4 — AWS Lambda + RDS + API Gateway

Безсерверний REST API для журналу оцінок студентів, розгорнутий на AWS за допомогою Terraform.

## Архітектура

- **AWS Lambda** (Python 3.12) — обробка API-запитів
- **Amazon RDS** (PostgreSQL 15.10) — зберігання оцінок
- **API Gateway HTTP API v2** — маршрутизація запитів
- **Amazon S3** — логування операцій

## API Endpoints

| Метод | Endpoint | Опис |
|-------|----------|------|
| POST | `/grades` | Додати оцінку студента |
| GET | `/grades/student/{id}` | Отримати оцінки студента із середнім балом https://mr960vvm63.execute-api.eu-central-1.amazonaws.com/grades/student/45 |

## Структура проєкту
```
serverless-lab4/
├── modules/
│   ├── rds/          # PostgreSQL RDS instance
│   ├── lambda/       # Lambda function + IAM + Layer
│   └── api_gateway/  # HTTP API Gateway v2
├── envs/dev/         # Terraform середовище
├── layers/psycopg2/  # Lambda Layer для psycopg2
└── src/app.py        # Код Lambda-функції
```

## Розгортання
```bash
cd envs/dev
terraform init
terraform apply -auto-approve
```

