# Contributing

1. Keep service application code in its own `gwatcho-*` repository.
2. Keep cross-service local orchestration, environment templates, and shared development infrastructure here.
3. Never commit `.env`, credentials, tokens, or production secrets.
4. Validate Compose changes with `docker compose config` before opening a pull request.
5. Test changes with the relevant containers before merging.
