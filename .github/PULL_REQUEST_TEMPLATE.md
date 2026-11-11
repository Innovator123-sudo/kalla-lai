## Summary

What does this change do, and why? Link the related issue if there is one.

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Refactor / internal cleanup
- [ ] Documentation
- [ ] Website / deployment (`.github/workflows/deploy-pages.yml`)
- [ ] Infrastructure / deployment

## How I verified it

Be specific — commands run, screens checked, devices/browsers used:

```
flutter analyze
flutter test
cd server && npm run build && npm test
flutter build web --release --base-href /kalla-lai/
```

- [ ] Desktop browser
- [ ] Mobile width (390 px)
- [ ] API endpoints exercised

## Trust & safety

If this touches verification, payments, shifts, reputation or disputes:

- [ ] The UI still never claims "verified", "paid" or "published" without an authoritative confirmation
- [ ] A test covers the invariant
- [ ] No new personal data is logged or stored
- [ ] No document images, face templates or OCR payloads are stored

## Checklist

- [ ] Focused change, one concern per PR
- [ ] Tests added or updated
- [ ] Docs / startup kit updated where behaviour changed
- [ ] No `.env`, service-account JSON, private keys, passwords or real user data committed
- [ ] `site/privacy.html` and `site/terms.html` are hand-edited — they have no generator any more
- [ ] I read [CONTRIBUTING.md](../CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md)
