# GWatcho Shop — Demo Checklist

Use this checklist for a repeatable end-to-end walkthrough. Run it against the current deployed/local environment and record the actual result; this document is a checklist, not a claim that every environment is currently healthy.

## 1. Environment readiness

- [ ] Confirm Docker Desktop and Docker Compose v2 are running.
- [ ] Review local `.env`; do not display credentials during the demo.
- [ ] Run `docker compose config`.
- [ ] Run `docker compose ps` and check service health/status.
- [ ] Check logs for the gateway and any unhealthy backend service.

## 2. Customer experience

- [ ] Open the Angular frontend.
- [ ] Browse the product catalog and open a product.
- [ ] Sign in using a configured Keycloak development test account.
- [ ] Verify the frontend can load the authenticated customer profile if that feature is enabled.

## 3. Checkout and order lifecycle

- [ ] Add a product to the cart and review quantities/pricing.
- [ ] Complete checkout using the demo's configured payment flow.
- [ ] Verify the order appears in the UI and has an expected status.
- [ ] Verify payment status in the UI/API/logs where exposed.
- [ ] Verify delivery state/event handling where exposed.
- [ ] Inspect service logs/Kafka UI to demonstrate asynchronous processing, using the actual configured topic names.

## 4. Persistence and resilience

- [ ] Record an order or other test record.
- [ ] Restart the relevant container without deleting volumes.
- [ ] Verify the record remains available.
- [ ] Do not use `docker compose down --volumes` for a persistence demo.

## 5. CI/CD walkthrough

- [ ] Open the relevant GitHub Actions run for the service being demonstrated.
- [ ] Show test/build status and image publication.
- [ ] Show deployment status from the Windows self-hosted runner, if that workflow is enabled for the branch.
- [ ] Confirm the deployed service/image tag matches the intended commit or branch.

## 6. Close-out

- [ ] Mention that this is a development/demo environment, not a production security baseline.
- [ ] Avoid showing secrets, access tokens, passwords, or personal data.
- [ ] Capture any failed checks as follow-up work rather than implying success.
