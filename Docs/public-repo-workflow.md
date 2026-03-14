# Public Repo Workflow

The public mirror replaces the real purchase and clipboard-capture boundaries before publishing.
That lets you keep the StoreKit implementation and real pasteboard monitoring on the private branch while the public branch swaps in the safe mirror files from `PublicMirror/Better/Services/`.

## One-time setup

Create a second remote for the public repo and keep your private App Store repo as the canonical remote:

```bash
git remote rename origin private
git remote add public git@github.com:YOURNAME/better-public.git
```

Create a local public-maintenance branch from your current private branch:

```bash
git checkout -b public-main
./Scripts/refresh-public-branch.sh
git add Better/Services/PurchaseManager.swift Better/Services/ClipboardWatcher.swift
git commit -m "Prepare public branch"
git push public public-main:main
git checkout main
```

## Day-to-day flow

Private shipping work stays on `main`.

When you want to update the public repo:

```bash
git checkout public-main
git merge main
./Scripts/refresh-public-branch.sh
git add Better/Services/PurchaseManager.swift Better/Services/ClipboardWatcher.swift
git commit -m "Sync public branch"
git push public public-main:main
git checkout main
git push private main
```

If you want a single command for the push step after both branches are ready:

```bash
./Scripts/push-remotes.sh
```

That pushes:

- `main` to the `private` remote
- `public-main` to the `public` remote as `main`

## What the public repo exposes

The public mirror still contains the full app code except for the premium unlock implementation.
In the public branch:

- `PurchaseManager.swift` is replaced with a free-tier stub.
- `ClipboardWatcher.swift` is replaced with a demo watcher that does not monitor the real macOS clipboard.
- Source builds stay limited to the free history and pin caps.
- The App Store purchase flow, entitlement checks, and real clipboard ingestion are not published.

## What not to put in the public repo

- StoreKit entitlement checks
- App Store purchase calls
- Real clipboard monitoring/capture code
- App-specific release automation or secrets
- Any future server-side licensing code, if you add it later
