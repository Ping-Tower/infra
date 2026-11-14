# Стенд PingTower

Namespace: `pingtower`. CI-контекст: `pingtower/infra:pingtower`.
DNS в Cloudflare: `pingtower.tech`, `api.pingtower.tech`, `tg.pingtower.tech`
→ `45.92.217.22`, DNS only. TLS: `letsencrypt-prod`.

## Деплой

Из защищённой `main`: успешные тесты и сборка образа, затем manual job `deploy`.
Порядок первого запуска: infra → API (включая миграции) → workers → frontend.
`tg-bot` и `email-service` запускаются после заполнения их Variables.
Namespace, RBAC и GitLab Agent уже установлены администратором.

API использует две реплики и Redis backplane SignalR с префиксом
`PingTower:api:signalr`. Фронтенд подключается через WebSockets с
`skipNegotiation`; nginx проксирует `/api/` и `/hubs/` на внутренний Service API.
`VITE_API_URL` оставлять пустым.

## Что заполнить владельцу

GitLab → соответствующий проект → Settings → CI/CD → Variables.
Для секретов: Protected, Masked, environment scope `*`, Expand выключен.

| Проект | Variable | Значение |
|---|---|---|
| `pingtower/api` | `TELEGRAM_BOT_TOKEN` | Токен бота для проверки Telegram Login |
| `pingtower/tg-bot` | `TG_BOT_BOT_TOKEN` | Тот же токен бота |
| `pingtower/tg-bot` | `TG_BOT_WEBHOOK_SECRET` | Случайная строка из букв, цифр, `_`, `-` |
| `pingtower/frontend` | `VITE_TELEGRAM_BOT_USERNAME` | Username бота без `@`, публичный |
| `pingtower/frontend` | `VITE_TELEGRAM_BOT_ID` | Числовой ID того же бота, публичный; не токен |
| `pingtower/email-service` | `EMAIL_SERVICE_SMTP_HOST` | SMTP-сервер |
| `pingtower/email-service` | `EMAIL_SERVICE_SMTP_PORT` | SMTP-порт |
| `pingtower/email-service` | `EMAIL_SERVICE_SMTP_USERNAME` | SMTP-логин |
| `pingtower/email-service` | `EMAIL_SERVICE_SMTP_PASSWORD` | SMTP-пароль |
| `pingtower/email-service` | `EMAIL_SERVICE_SMTP_FROM_ADDRESS` | Адрес отправителя |
| `pingtower/email-service` | `EMAIL_SERVICE_SMTP_FROM_NAME` | Имя отправителя |
| `pingtower/email-service` | `EMAIL_SERVICE_SMTP_SECURITY` | `starttls`, `ssl` или `tls`, согласно настройкам SMTP |
| `pingtower/email-service` | `EMAIL_SERVICE_SMTP_TIMEOUT_SECONDS` | Таймаут SMTP в секундах, например `30` |

Короткие и публичные значения могут не подходить под ограничения Masked;
их можно оставить обычными Variables. В BotFather разрешить домен `pingtower.tech`.
До добавления токена API содержит пробел в `TELEGRAM_BOT_TOKEN`:
приложение считает его отсутствующей настройкой, ESO требует непустое значение.

ESO обновляет Secrets раз в минуту. После замены токена перезапустить API:

```sh
kubectl -n pingtower wait --for=condition=Ready externalsecret/api --timeout=120s
kubectl -n pingtower rollout restart deployment/api
kubectl -n pingtower rollout status deployment/api --timeout=600s
```

Для `tg-bot` и `email-service` запустить manual `deploy` в их успешных pipelines.
После изменения username или числового ID бота пересобрать и развернуть frontend: `VITE_*`
встраиваются в JavaScript при сборке.
До настройки SMTP регистрация с подтверждением почты и восстановление пароля
не завершатся; это не проверяется готовностью Pod API.

## Учётные данные и проверка

Пароли хранилищ, registry-доступ и JWT уже созданы в Variables проектов.
Не менять пароли БД только через Variables: существующие роли требуют ротации в БД.
ESO PAT ограничен чтением Variables проектов infra, API, tg-bot и email-service;
истекает `2027-02-10`. Registry Deploy Token — `2027-11-11`.

```sh
kubectl -n pingtower get deploy,statefulset,pods,pvc
kubectl -n pingtower get secretstores,externalsecrets,certificates
curl -fsS https://pingtower.tech/
curl -fsS https://api.pingtower.tech/health/ready
```
